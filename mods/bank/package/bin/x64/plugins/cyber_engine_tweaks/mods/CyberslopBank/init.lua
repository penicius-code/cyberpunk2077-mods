-- Cyberslop CET Style 1.0.0 (2026-11-22): this mod's windows use the gold palette (cyberslop_palette.lua, colours only).
do
  local ok, palette = pcall(require, "cyberslop_palette")
  if ok and type(palette) == "table" and type(registerForEvent) == "function" then
    local reg = registerForEvent
    registerForEvent = function(ev, fn)
      if ev == "onDraw" and type(fn) == "function" then fn = palette.wrap("gold", fn) end
      return reg(ev, fn)
    end
  end
end
-- Cyberslop Bank 1.0.1 (2026-11-23; 1.0.0 2026-11-22)
-- 1.0.1: no more free money from the bank itself:
--   * the payoff bonus to the credit score needs at least one scheduled payment (a loan paid off on the day it was
--     taken cost ~3 eb and gave +5..+25 points, so ~11 clicks reached score 850 and a 100M limit on day 0), and a
--     payoff bonus alone no longer starts the score (README: 7 days in good standing or a late mark);
--   * interest is paid only on the part of the balance above what V owes the bank (and the tier follows that part),
--     so borrowed money parked in the account (Obsidian ~16.8 %/year net) no longer beats the loan's APR.
-- A lightweight, CET-only bank that replaces Marmur Bank Overhaul (30270) and ANODOS (dropped):
--   account with daily interest by balance tier, deposits and withdrawals anywhere,
--   personal loans with a credit score, late fees and default, a transaction history
--   with a balance chart.
-- Everything is in one CET window that shows with the CET overlay.
--
-- Lightweight by design: no Observe / Override hooks, no onUpdate, no timers, no files.
-- Interest and loan payments are settled from game time when the window opens or the
-- HUD hotkey is pressed. The account only changes through this mod, so settling late
-- gives the same result as settling every day.
-- State lives in the save as quest facts (csbank_*), so it loads and reloads with the save.
--
-- Numbers from Marmur Bank Overhaul: tiers 0 / 25k / 100k / 250k / 1M = 1..5 bp per game day,
-- 15 % tax on interest, loan APR 24 % .. 4.5 % by credit score, limit 5k .. 100M by score,
-- credit score 300..850 (starts at 600), a loan payment every 30 game days.

local Bank = {
  version = "1.0.1",
  overlay = false,
  hidden = false,
  dirty = true,
  nextCheck = 0,
  lastDay = -1,
  v = nil,          -- what the window shows (strings), rebuilt by refresh()
  pending = nil,    -- action queued by a button, run after ImGui.End()
  msg = nil,
  msgBad = false,
  noChart = false,
  cashflow = nil,   -- nil = untried, false = Cyberslop Cashflow tagging unavailable
  drawErr = false,
  ui = { amount = 1000, loanAmount = 5000, term = 2, fromWallet = false, confirm = nil, filter = 1 },
}

-- ---------------------------------------------------------------- numbers

local INT_MAX = 2147483647
local P = "csbank_"
local TIERS = {
  { name = "Standard",        min = 0,       bp = 1 },
  { name = "Preferred",       min = 25000,   bp = 2 },
  { name = "Premier",         min = 100000,  bp = 3 },
  { name = "Private Client",  min = 250000,  bp = 4 },
  { name = "Obsidian Client", min = 1000000, bp = 5 },
}
local TAX_PCT = 15                 -- tax on interest
local PERIOD = 30                  -- game days between loan payments
local TERMS = { 6, 12, 24, 36, 60 } -- number of payments
local LATE_FEE_PCT, LATE_FEE_MIN = 5, 100
local DEFAULT_AFTER = 3            -- missed payments in a row
local MISS_MILLI, DEFAULT_MILLI = 35000, 120000 -- credit score penalty (milli-points)
local DECAY_MILLI = 166            -- late marks fade by this per game day in good standing
local STARTER_LIMIT, MIN_LOAN = 5000, 1000
local SLOTS, HIST = 1, 60

local K = { OPEN = 1, DEPOSIT = 2, WITHDRAW = 3, INTEREST = 4, LOAN = 5, AUTOPAY = 6, PAY = 7, PAYWALLET = 8,
            MISSED = 9, DEFAULT = 10, COLLECT = 11, PAIDOFF = 12, CLEARED = 13,
            REVERSED = 14 }
local KNAME = {
  [1] = "Account opened", [2] = "Deposit", [3] = "Withdrawal", [4] = "Interest (after tax)",
  [5] = "Loan paid out", [6] = "Loan payment (auto)", [7] = "Loan payment", [8] = "Loan payment from wallet",
  [9] = "Missed payment + late fee", [10] = "Loan defaulted, all due now", [11] = "Overdue collected",
  [12] = "Loan paid off", [13] = "Defaulted loan settled",
  [14] = "Withdrawal failed, returned",
}
-- effect on the account: 1 in, -1 out, 0 = no account change (info row)
local KSIGN = { [1] = 0, [2] = 1, [3] = -1, [4] = 1, [5] = 1, [6] = -1, [7] = -1, [8] = 0, [9] = 0, [10] = 0,
                [11] = -1, [12] = 0, [13] = 0, [14] = 1 }
local KIND_NAME = { [1] = "Personal loan" }

-- fact names, built once
local ACC = { "v", "bal", "day", "od", "td", "tw", "ti", "tt", "tf", "tb", "tr", "hn", "cg", "cf", "cn", "cp", "cs" }
-- v account open (1) | bal balance | day last settled game day | od opened day | td/tw deposited/withdrawn
-- ti interest (net) | tt interest tax | tf late fees | tb borrowed | tr repaid | hn history rows written
-- cg credit good days | cf first credit day + 1
-- cn late marks (milli-points) | cp payoff bonus (milli-points) | cs score started
local LF = { "st", "kd", "pr", "rt", "tm", "pd", "inst", "du", "ar", "nx", "ms", "sd" }
-- st 0 free / 1 active / 2 defaulted | kd kind | pr principal | rt APR bp | tm payments | pd payments made
-- inst installment | du scheduled amount left | ar overdue (incl. fees) | nx next due day | ms missed in a row | sd start day
local FN, LN, HN = {}, {}, {}
for _, k in ipairs(ACC) do FN[k] = P .. k end
for s = 1, SLOTS do
  LN[s] = {}
  for _, f in ipairs(LF) do LN[s][f] = P .. "l" .. s .. f end
end
for i = 0, HIST - 1 do HN[i] = { P .. "h" .. i .. "k", P .. "h" .. i .. "a", P .. "h" .. i .. "t", P .. "h" .. i .. "b" } end

-- ---------------------------------------------------------------- helpers

local function int(v)
  v = tonumber(v) or 0
  if v ~= v then return 0 end
  v = math.floor(v)
  if v > INT_MAX then return INT_MAX end
  if v < -INT_MAX then return -INT_MAX end
  return v
end
local function pos(v) v = int(v) return v < 0 and 0 or v end
local function add(a, b) return pos((a or 0) + (b or 0)) end
local function clamp(x, a, b) if x < a then return a elseif x > b then return b end return x end

local function num(v)
  v = int(v)
  local neg = v < 0
  local s = tostring(neg and -v or v)
  s = s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
  return (neg and "-" or "") .. s
end

local function say(text, bad)
  Bank.msg = text
  Bank.msgBad = bad and true or false
end

-- ---------------------------------------------------------------- game access

local Q = nil
local MONEY = nil

local function inGame()
  local ok, p = pcall(function() return Game.GetPlayer() end)
  if not ok or not p then return false end
  local okPre, pre = pcall(function() return GetSingleton("inkMenuScenario"):GetSystemRequestsHandler():IsPreGame() end)
  if okPre and pre then return false end
  return true
end

local function rd(name) return int(Q:GetFactStr(name)) end
local function wr(name, value) Q:SetFactStr(name, int(value)) end

local function now() -- game minutes
  local ok, t = pcall(function() return Game.GetTimeSystem():GetGameTimeStamp() end)
  return math.floor((ok and tonumber(t) or 0) / 60)
end
local function dayOf(m) return math.floor(m / 1440) end
local function stamp(m)
  local d = dayOf(m)
  local r = m - d * 1440
  return string.format("day %d %02d:%02d", d, math.floor(r / 60), r % 60)
end

local function money()
  if not MONEY then MONEY = MarketSystem.Money() end
  return MONEY
end
local function wallet()
  local ok, n = pcall(function() return Game.GetTransactionSystem():GetItemQuantity(Game.GetPlayer(), money()) end)
  return ok and pos(n) or 0
end

-- Tell Cyberslop Cashflow what the next eddie change is (optional; untagged = "other").
local function cashTag(cat, detail)
  if Bank.cashflow == false then return end
  local ok = pcall(function() GetSingleton("CyberslopCashflow.CashflowBook"):TagNow(cat, detail, 3.0) end)
  if not ok then ok = pcall(function() GetSingleton("CyberslopCashflow.CashflowBook").TagNow(cat, detail, 3.0) end) end
  Bank.cashflow = ok
end

local function walletTake(amount, cat, detail)
  if amount <= 0 or wallet() < amount then return false end
  cashTag(cat, detail)
  local ok, res = pcall(function() return Game.GetTransactionSystem():RemoveItem(Game.GetPlayer(), money(), amount) end)
  return ok and res == true
end
local function walletGive(amount, cat, detail)
  if amount <= 0 then return false end
  cashTag(cat, detail)
  local ok, res = pcall(function() return Game.GetTransactionSystem():GiveItem(Game.GetPlayer(), money(), amount) end)
  return ok and res == true
end

-- ---------------------------------------------------------------- state (facts)

local S = nil

local function load()
  local ok, q = pcall(function() return Game.GetQuestsSystem() end)
  if not ok or not q then return false end
  Q = q
  local acc, oacc = {}, {}
  for _, k in ipairs(ACC) do
    local x = rd(FN[k])
    acc[k], oacc[k] = x, x
  end
  local loans, ol = {}, {}
  for s = 1, SLOTS do
    local L, O = {}, {}
    for _, f in ipairs(LF) do
      local x = rd(LN[s][f])
      L[f], O[f] = x, x
    end
    loans[s], ol[s] = L, O
  end
  S = { acc = acc, oacc = oacc, loans = loans, ol = ol }
  return true
end

local function save()
  for _, k in ipairs(ACC) do
    if S.acc[k] ~= S.oacc[k] then wr(FN[k], S.acc[k]); S.oacc[k] = S.acc[k] end
  end
  for s = 1, SLOTS do
    local L, O = S.loans[s], S.ol[s]
    for _, f in ipairs(LF) do
      if L[f] ~= O[f] then wr(LN[s][f], L[f]); O[f] = L[f] end
    end
  end
end

local function hist(kind, amount, minute, slot)
  local A = S.acc
  local n = HN[A.hn % HIST]
  wr(n[1], kind + 100 * (slot or 0))
  wr(n[2], pos(amount))
  wr(n[3], pos(minute))
  wr(n[4], A.bal)
  A.hn = A.hn + 1
end

-- ---------------------------------------------------------------- rules

local function tierIndex(bal)
  for i = #TIERS, 1, -1 do
    if bal >= TIERS[i].min then return i end
  end
  return 1
end

-- credit model after Marmur's CreditModel.lua
local function ceiling(sc)
  if sc < 500 then return STARTER_LIMIT end
  if sc >= 800 then return 100000000 end
  local ratio = (sc - 500) / 300
  return math.max(50000, math.floor((50000 + 99950000 * ratio ^ 2.35) / 1000) * 1000)
end
local function apr(sc) return math.floor(2400 - clamp((sc - 500) / 300, 0, 1) * 1950 + 0.5) end
local function band(sc)
  if sc <= 0 then return "no history" end
  if sc < 580 then return "poor" end
  if sc < 670 then return "fair" end
  if sc < 740 then return "good" end
  return "excellent"
end
local function payoffReward(amount)
  if amount <= 0 then return 0 end
  local pts = amount <= 5000 and amount / 1000 or math.min(25, 5 + 2 * math.log(amount / 5000) / math.log(2))
  return math.floor(pts * 1000 + 0.5)
end

local function score(today)
  local A = S.acc
  if A.cs ~= 1 then return 0 end
  local base = 600
  local histDays = A.cf > 0 and math.max(0, today - (A.cf - 1)) or 0
  local earned = math.max(0, 850 - base) * (0.75 * clamp(A.cg / 360, 0, 1) + 0.25 * clamp(histDays / 720, 0, 1))
  local positive = base + earned
  local payoff = math.min(A.cp / 1000, math.max(0, 850 - positive))
  return math.floor(clamp(positive + payoff - A.cn / 1000, 300, 850) + 0.5)
end

local function creditStart()
  local A = S.acc
  if A.cs ~= 1 and (A.cg >= 7 or A.cn > 0) then A.cs = 1 end -- 1.0.1: a payoff bonus alone no longer starts it
end

local function installment(principal, bp, n)
  local r = bp / 120000
  if r <= 0 then return math.ceil(principal / n) end
  return math.ceil(principal * r / (1 - (1 + r) ^ (-n)))
end

-- early payoff: what the remaining payments are worth today (future interest dropped)
local function payoffAmount(L)
  if L.du <= 0 then return 0 end
  local r = L.rt / 120000
  if r <= 0 or L.inst <= 0 then return L.du end
  local left, pv, k = L.du, 0, 0
  while left > 0 and k < 600 do
    k = k + 1
    local p = math.min(L.inst, left)
    pv = pv + p / (1 + r) ^ k
    left = left - p
  end
  return math.min(L.du, math.ceil(pv))
end

local function owed(L) return add(L.du, L.ar) end

local function closeIfDone(s, minute)
  local L, A = S.loans[s], S.acc
  if L.st == 0 or L.du > 0 or L.ar > 0 then return end
  if L.st == 1 then
    -- 1.0.1: the bonus needs at least one scheduled payment (no same-day take-and-repay farming)
    if L.pd >= 1 then A.cp = math.min(250000, A.cp + payoffReward(L.pr)) end
    hist(K.PAIDOFF, L.pr, minute, s)
  else
    hist(K.CLEARED, 0, minute, s)
  end
  for _, f in ipairs(LF) do L[f] = 0 end
end

-- overdue amounts are taken from the account as soon as there is money in it
local function collect(minute)
  local A = S.acc
  for s = 1, SLOTS do
    local L = S.loans[s]
    if L.ar > 0 and A.bal > 0 then
      local take = math.min(A.bal, L.ar)
      A.bal = A.bal - take
      L.ar = L.ar - take
      A.tr = add(A.tr, take)
      hist(K.COLLECT, take, minute, s)
      if L.ar == 0 then L.ms = 0 end
      closeIfDone(s, minute)
    end
  end
end

local function dueLoans(d)
  local A = S.acc
  local minute = d * 1440 + 540 -- 09:00 on the due day
  for s = 1, SLOTS do
    local L = S.loans[s]
    local guard = 0
    while L.st == 1 and L.du > 0 and L.nx > 0 and L.nx <= d and guard < 64 do
      guard = guard + 1
      local pay = L.inst > 0 and math.min(L.inst, L.du) or L.du
      if A.bal >= pay then
        A.bal = A.bal - pay
        L.du = L.du - pay
        L.pd = L.pd + 1
        if L.ar == 0 then L.ms = 0 end
        A.tr = add(A.tr, pay)
        hist(K.AUTOPAY, pay, minute, s)
      else
        local fee = math.max(LATE_FEE_MIN, math.floor(pay * LATE_FEE_PCT / 100 + 0.5))
        L.du = L.du - pay
        L.pd = L.pd + 1
        L.ar = add(L.ar, pay + fee)
        L.ms = L.ms + 1
        A.tf = add(A.tf, fee)
        A.cn = add(A.cn, MISS_MILLI)
        hist(K.MISSED, pay + fee, minute, s)
        if L.ms >= DEFAULT_AFTER then
          L.ar = add(L.ar, L.du)
          L.du = 0
          L.st = 2
          A.cn = add(A.cn, DEFAULT_MILLI)
          hist(K.DEFAULT, L.ar, minute, s)
        end
      end
      L.nx = L.nx + PERIOD
    end
    closeIfDone(s, minute)
  end
end

local function creditDay()
  local A = S.acc
  local open, overdue = false, false
  for s = 1, SLOTS do
    local L = S.loans[s]
    if L.st ~= 0 then open = true end
    if L.ar > 0 or L.st == 2 then overdue = true end
  end
  if not overdue then
    if open then A.cg = A.cg + 1 end
    if A.cn > 0 then A.cn = math.max(0, A.cn - DECAY_MILLI) end
  end
end

-- catch up every game day since the last visit: interest, overdue collection, loan payments
local function settle(today, nowMin)
  local A = S.acc
  if A.v ~= 1 then return end
  if today <= A.day then
    if today < A.day then A.day = today end
    return
  end
  local from = math.max(A.day + 1, today - 3650)
  local net, tax = 0, 0
  for d = from, today do
    -- 1.0.1: interest only on the balance above what is owed to the bank (borrowed money earns nothing)
    local debt = 0
    for s = 1, SLOTS do debt = add(debt, owed(S.loans[s])) end
    local earning = math.max(0, A.bal - debt)
    local gross = math.floor(earning * TIERS[tierIndex(earning)].bp / 10000 + 0.5)
    if gross > 0 then
      local t = math.floor(gross * TAX_PCT / 100 + 0.5)
      A.bal = add(A.bal, gross - t)
      net, tax = net + gross - t, tax + t
    end
    collect(d * 1440 + 540)
    dueLoans(d)
    creditDay()
  end
  if net > 0 then
    A.ti = add(A.ti, net)
    A.tt = add(A.tt, tax)
    hist(K.INTEREST, net, nowMin)
  end
  creditStart()
  A.day = today
end

local function freeSlot()
  for s = 1, SLOTS do if S.loans[s].st == 0 then return s end end
  return nil
end

local function totalOwed()
  local t = 0
  for s = 1, SLOTS do t = add(t, owed(S.loans[s])) end
  return t
end

-- why a new personal loan is not possible ("" = possible)
local function borrowBlock(today)
  local hasPersonal, bad = false, false
  for s = 1, SLOTS do
    local L = S.loans[s]
    if L.st ~= 0 then hasPersonal = true end
    if L.st == 2 or L.ar > 0 then bad = true end
  end
  if bad then return "Not while a payment is overdue or a loan is in default." end
  if hasPersonal then return "One loan at a time: pay off the current one first." end
  if not freeSlot() then return "No free loan slot." end
  local avail = ceiling(score(today)) - totalOwed()
  if avail < MIN_LOAN then return "Your credit limit is used up." end
  return ""
end
local function available(today) return math.max(0, ceiling(score(today)) - totalOwed()) end

-- ---------------------------------------------------------------- actions

local function begin()
  if not inGame() then return nil, "Load a save first." end
  if not load() then return nil, "The game is not ready yet." end
  local m = now()
  local today = dayOf(m)
  settle(today, m)
  return m, today
end
local function finish()
  creditStart()
  save()
end

local function openAccount(m, today)
  local A = S.acc
  A.v, A.od, A.day = 1, today, today
  hist(K.OPEN, 0, m)
end

local function actOpen()
  local m, today = begin()
  if not m then return say(today, true) end
  if S.acc.v == 1 then return say("The account is already open.") end
  openAccount(m, today)
  finish()
  say("Account opened.")
end

local function actDeposit(amount)
  local m, today = begin()
  if not m then return say(today, true) end
  local A = S.acc
  amount = math.min(pos(amount), INT_MAX - A.bal)
  if amount <= 0 then return say("Enter an amount.", true) end
  local w = wallet()
  if amount > w then return say("You only have " .. num(w) .. " eb on you.", true) end
  if not walletTake(amount, 11, "Cyberslop Bank deposit") then return say("The deposit did not go through.", true) end
  A.bal = add(A.bal, amount)
  A.td = add(A.td, amount)
  hist(K.DEPOSIT, amount, m)
  local before = A.bal
  collect(m)
  finish()
  if A.bal < before then
    say("Deposited " .. num(amount) .. " eb; " .. num(before - A.bal) .. " eb went to overdue loan payments.")
  else
    say("Deposited " .. num(amount) .. " eb.")
  end
end

local function actWithdraw(amount)
  local m, today = begin()
  if not m then return say(today, true) end
  local A = S.acc
  amount = pos(amount)
  if amount <= 0 then return say("Enter an amount.", true) end
  if amount > A.bal then return say("The account has " .. num(A.bal) .. " eb.", true) end
  A.bal = A.bal - amount
  A.tw = add(A.tw, amount)
  hist(K.WITHDRAW, amount, m)
  finish() -- booked before the eddies move
  if not walletGive(amount, 11, "Cyberslop Bank withdrawal") then
    A.bal = add(A.bal, amount)
    A.tw = pos(A.tw - amount)
    hist(K.REVERSED, amount, m)
    finish()
    return say("The withdrawal did not go through; the money stays in the account.", true)
  end
  say("Withdrew " .. num(amount) .. " eb.")
end

local function actTakeLoan(amount, termIdx)
  local m, today = begin()
  if not m then return say(today, true) end
  local A = S.acc
  if A.v ~= 1 then return say("Open an account first.", true) end
  local why = borrowBlock(today)
  if why ~= "" then return say(why, true) end
  amount = pos(amount)
  local avail = math.min(available(today), INT_MAX - A.bal)
  if amount < MIN_LOAN then return say("The smallest loan is " .. num(MIN_LOAN) .. " eb.", true) end
  if amount > avail then return say("Your limit is " .. num(avail) .. " eb.", true) end
  local n = TERMS[termIdx] or TERMS[2]
  local rt = apr(score(today))
  local ins = installment(amount, rt, n)
  local s = freeSlot()
  local L = S.loans[s]
  L.st, L.kd, L.pr, L.rt, L.tm, L.pd = 1, 1, amount, rt, n, 0
  L.inst, L.du, L.ar, L.nx, L.ms, L.sd = ins, pos(ins * n), 0, today + PERIOD, 0, today
  A.bal = add(A.bal, amount)
  A.tb = add(A.tb, amount)
  if A.cf == 0 then A.cf = today + 1 end
  hist(K.LOAN, amount, m, s)
  finish()
  say(string.format("Loan of %s eb paid into the account: %d payments of %s eb, first on day %d.",
    num(amount), n, num(ins), L.nx))
end

-- pay from the account or the wallet; returns true when `amount` was taken
local function takeFunds(amount, fromWallet, m, s)
  local A = S.acc
  if amount <= 0 then return false end
  if fromWallet then
    if not walletTake(amount, 7, "Cyberslop Bank loan payment") then return false end
    hist(K.PAYWALLET, amount, m, s)
  else
    if A.bal < amount then return false end
    A.bal = A.bal - amount
    hist(K.PAY, amount, m, s)
  end
  A.tr = add(A.tr, amount)
  return true
end

local function actPayOverdue(s, fromWallet)
  local m, today = begin()
  if not m then return say(today, true) end
  local L = S.loans[s]
  if not L or L.ar <= 0 then finish() return say("Nothing is overdue.") end
  local have = fromWallet and wallet() or S.acc.bal
  local amount = math.min(L.ar, have)
  if amount <= 0 or not takeFunds(amount, fromWallet, m, s) then
    finish()
    return say(fromWallet and "No eddies on you." or "The account is empty.", true)
  end
  L.ar = L.ar - amount
  if L.ar == 0 then L.ms = 0 end
  closeIfDone(s, m)
  finish()
  say("Paid " .. num(amount) .. " eb of the overdue amount.")
end

local function actPayNext(s, fromWallet)
  local m, today = begin()
  if not m then return say(today, true) end
  local L = S.loans[s]
  if not L or L.st ~= 1 or L.du <= 0 then finish() return say("No payment to make.", true) end
  if L.ar > 0 then finish() return say("Pay the overdue amount first.", true) end
  local pay = L.inst > 0 and math.min(L.inst, L.du) or L.du
  if not takeFunds(pay, fromWallet, m, s) then
    finish()
    return say("Not enough money " .. (fromWallet and "on you." or "in the account."), true)
  end
  L.du = L.du - pay
  L.pd = L.pd + 1
  L.nx = L.nx + PERIOD
  closeIfDone(s, m)
  finish()
  say("Paid " .. num(pay) .. " eb early.")
end

local function actPayOff(s, fromWallet)
  local m, today = begin()
  if not m then return say(today, true) end
  local L = S.loans[s]
  if not L or L.st == 0 then finish() return say("No such loan.", true) end
  local early = payoffAmount(L)
  local amount = add(early, L.ar)
  local saved = L.du - early
  if not takeFunds(amount, fromWallet, m, s) then
    finish()
    return say("Paying it off takes " .. num(amount) .. " eb " .. (fromWallet and "on you." or "in the account."), true)
  end
  L.du, L.ar = 0, 0
  closeIfDone(s, m)
  finish()
  say("Loan paid off with " .. num(amount) .. " eb" .. (saved > 0 and (" (" .. num(saved) .. " eb interest saved).") or "."))
end

-- ---------------------------------------------------------------- view (strings for the window)

local function loanView(s, L, today)
  local lv = { slot = s }
  lv.title = string.format("%s  (APR %.2f %%)", KIND_NAME[L.kd] or "Loan", L.rt / 100)
  local lines = {}
  if L.st == 2 then
    lv.status = "IN DEFAULT: " .. num(L.ar) .. " eb due now, taken from every deposit"
    lv.bad = true
  elseif L.ar > 0 then
    lv.status = string.format("OVERDUE %s eb (%d missed in a row, default after %d)", num(L.ar), L.ms, DEFAULT_AFTER)
    lv.bad = true
  end
  if L.st == 1 then
    table.insert(lines, string.format("Left to pay %s eb   payment %s eb every %d days", num(owed(L)), num(math.min(L.inst, math.max(L.du, 0))), PERIOD))
    if L.du > 0 then
      table.insert(lines, string.format("Next payment day %d (in %d days)   payments %d of %d", L.nx, math.max(0, L.nx - today), L.pd, math.max(L.tm, L.pd)))
    end
    table.insert(lines, string.format("Borrowed %s eb on day %d", num(L.pr), L.sd))
  end
  lv.lines = lines
  lv.payoff = add(payoffAmount(L), L.ar)
  lv.saved = math.max(0, L.du - payoffAmount(L))
  lv.canNext = L.st == 1 and L.ar == 0 and L.du > 0
  lv.lblOverdue = "Pay overdue " .. num(L.ar) .. " eb##csbo" .. s
  lv.lblNext = "Pay next " .. num(math.min(L.inst, math.max(L.du, 0))) .. " eb now##csbn" .. s
  lv.lblOff = "Pay off " .. num(lv.payoff) .. " eb" .. (lv.saved > 0 and (" (saves " .. num(lv.saved) .. ")") or "") .. "##csbp" .. s
  lv.overdue = L.ar > 0
  return lv
end

local function histView(A)
  local rows = { all = {}, acc = {}, loan = {} }
  local chart = {}
  local count = math.min(A.hn, HIST)
  for j = 1, count do -- newest first
    local idx = (A.hn - j) % HIST
    local n = HN[idx]
    local code = rd(n[1])
    local kind, slot = code % 100, math.floor(code / 100)
    local amount, minute, bal = rd(n[2]), rd(n[3]), rd(n[4])
    local sign = KSIGN[kind] or 0
    local amt
    if kind == K.OPEN or kind == K.CLEARED then amt = ""
    elseif sign > 0 then amt = "+" .. num(amount)
    elseif sign < 0 then amt = "-" .. num(amount)
    elseif kind == K.PAYWALLET then amt = num(amount) .. " (wallet)"
    else amt = num(amount) end
    local what = KNAME[kind] or ("?" .. kind)
    if slot > 0 and SLOTS > 1 then what = what .. " #" .. slot end
    local row = { stamp(minute), what, amt, num(bal), sign > 0 and 1 or (sign < 0 and -1 or 0),
                  bad = (kind == K.MISSED or kind == K.DEFAULT) }
    table.insert(rows.all, row)
    if kind >= K.LOAN and kind <= K.CLEARED then table.insert(rows.loan, row)
    else table.insert(rows.acc, row) end
    chart[count - j + 1] = bal
  end
  return rows, chart
end

local function refresh()
  local v = {}
  Bank.v = v
  if not inGame() then v.err = "Load a save first." return end
  if not load() then v.err = "The game is not ready yet." return end
  local m = now()
  local today = dayOf(m)
  settle(today, m)
  creditStart()
  save()
  Bank.lastDay = today
  local A = S.acc
  v.today = today
  v.clock = stamp(m)
  v.wallet = num(wallet())
  v.balRaw = A.bal
  v.bal = num(A.bal)
  v.open = A.v == 1

  -- account
  local debt = totalOwed()
  local earning = math.max(0, A.bal - debt)
  local ti = tierIndex(earning)
  local t = TIERS[ti]
  local netBp = t.bp * (100 - TAX_PCT) / 100
  v.tier = string.format("%s tier: %.2f %% interest per game day, %.4f %% after %d %% tax (%.1f %% a game year)",
    t.name, t.bp / 100, netBp / 100, TAX_PCT, ((1 + netBp / 10000) ^ 365 - 1) * 100)
  if debt > 0 then
    v.tier = v.tier .. string.format(", paid on %s eb: the balance minus the %s eb you owe", num(earning), num(debt))
  end
  local nt = TIERS[ti + 1]
  v.nextTier = nt and string.format("%s from %s eb (%s eb more)", nt.name, num(nt.min), num(nt.min - earning)) or "Top tier."
  v.totals = {
    string.format("Opened day %d", A.od),
    string.format("Deposited %s eb   withdrawn %s eb", num(A.td), num(A.tw)),
    string.format("Interest earned %s eb   tax on it %s eb", num(A.ti), num(A.tt)),
    string.format("Borrowed %s eb   repaid %s eb   late fees %s eb", num(A.tb), num(A.tr), num(A.tf)),
  }

  -- credit and loans
  local sc = score(today)
  v.score = sc
  v.credit = sc > 0 and string.format("Credit score %d (%s)", sc, band(sc)) or "Credit score: no history yet"
  local histDays = A.cf > 0 and math.max(0, today - (A.cf - 1)) or 0
  v.creditWhy = string.format("good standing %d / 360 days, credit age %d / 720 days, payoff bonus +%.1f, late marks -%.1f",
    A.cg, histDays, A.cp / 1000, A.cn / 1000)
  if sc <= 0 then
    v.creditWhy = "A score appears after 7 days with a loan in good standing (or the first late payment). " .. v.creditWhy
  end
  v.avail = available(today)
  v.limit = string.format("Limit %s eb, %s eb available   APR now %.2f %%", num(ceiling(sc)), num(v.avail), apr(sc) / 100)
  v.borrowWhy = borrowBlock(today)
  v.apr = apr(sc)
  v.loans = {}
  for s = 1, SLOTS do
    local L = S.loans[s]
    if L.st ~= 0 then table.insert(v.loans, loanView(s, L, today)) end
  end

  v.rows, v.chart = histView(A)
  v.chartLabel = #v.chart > 1 and ("balance after each entry (" .. #v.chart .. ")") or ""
  local lo, hi = math.huge, 0
  for _, b in ipairs(v.chart) do
    if b < lo then lo = b end
    if b > hi then hi = b end
  end
  if lo == math.huge then lo = 0 end
  if hi <= lo then hi = lo + 1 end
  v.chartMin, v.chartMax = lo, hi
  Bank.preview = nil
end

local function loanPreview()
  local ui, v = Bank.ui, Bank.v
  local key = ui.loanAmount .. ":" .. ui.term .. ":" .. (v.apr or 0)
  if Bank.preview and Bank.preview.key == key then return Bank.preview end
  local n = TERMS[ui.term] or TERMS[2]
  local amount = pos(ui.loanAmount)
  local ins = amount > 0 and installment(amount, v.apr or 2400, n) or 0
  Bank.preview = {
    key = key,
    text = string.format("%d payments of %s eb every %d days = %s eb (%s eb interest)", n, num(ins), PERIOD,
      num(ins * n), num(math.max(0, ins * n - amount))),
    confirm = "Confirm: borrow " .. num(amount) .. " eb##csbconfirm",
  }
  return Bank.preview
end

-- ---------------------------------------------------------------- window

local RED = { 1.0, 0.4, 0.35, 1.0 }
local GREEN = { 0.5, 0.95, 0.6, 1.0 }
local AMBER = { 1.0, 0.75, 0.3, 1.0 }
local GREY = { 0.65, 0.65, 0.65, 1.0 }
local function colored(c, text) ImGui.TextColored(c[1], c[2], c[3], c[4], text) end

local QUICK = { { 1000, "1k##csq1" }, { 10000, "10k##csq2" }, { 100000, "100k##csq3" } }
local LQUICK = { { 5000, "5k##cslq1" }, { 50000, "50k##cslq2" }, { 500000, "500k##cslq3" } }
local TERM_LBL = {}
for i, n in ipairs(TERMS) do TERM_LBL[i] = { tostring(n) .. "##cst" .. i, "[" .. n .. "]##cst" .. i } end
local FILTERS = { { "All##csf1", "[All]##csf1", "all" }, { "Account##csf2", "[Account]##csf2", "acc" }, { "Loans##csf3", "[Loans]##csf3", "loan" } }

local function drawAccount(v)
  local ui = Bank.ui
  ImGui.Text(v.tier)
  colored(GREY, v.nextTier)
  ImGui.Separator()
  ImGui.PushItemWidth(170)
  local a, changed = ImGui.InputInt("eddies##csbamt", ui.amount, 100, 1000)
  ImGui.PopItemWidth()
  if changed then ui.amount = clamp(int(a), 0, INT_MAX) end
  for _, q in ipairs(QUICK) do
    ImGui.SameLine()
    if ImGui.Button(q[2]) then ui.amount = q[1] end
  end
  if ImGui.Button("Deposit##csbdep") then local x = ui.amount; Bank.pending = function() actDeposit(x) end end
  ImGui.SameLine()
  if ImGui.Button("Withdraw##csbwd") then local x = ui.amount; Bank.pending = function() actWithdraw(x) end end
  ImGui.SameLine()
  if ImGui.Button("Deposit all##csbdepall") then Bank.pending = function() actDeposit(wallet()) end end
  ImGui.SameLine()
  if ImGui.Button("Withdraw all##csbwdall") then local x = v.balRaw; Bank.pending = function() actWithdraw(x) end end
  ImGui.Separator()
  for _, line in ipairs(v.totals) do colored(GREY, line) end
end

local function drawLoans(v)
  local ui = Bank.ui
  ImGui.Text(v.credit)
  colored(GREY, v.limit)
  ImGui.PushTextWrapPos(560)
  colored(GREY, v.creditWhy)
  ImGui.PopTextWrapPos()
  if ImGui.Button(ui.fromWallet and "Pay from: wallet (click for account)##csbsrc" or "Pay from: account (click for wallet)##csbsrc") then
    ui.fromWallet = not ui.fromWallet
  end
  for _, lv in ipairs(v.loans) do
    ImGui.Separator()
    ImGui.Text(lv.title)
    if lv.status then colored(lv.bad and RED or AMBER, lv.status) end
    for _, line in ipairs(lv.lines) do ImGui.Text(line) end
    local w = ui.fromWallet
    if lv.overdue then
      if ImGui.Button(lv.lblOverdue) then local s = lv.slot; Bank.pending = function() actPayOverdue(s, w) end end
      ImGui.SameLine()
    end
    if lv.canNext then
      if ImGui.Button(lv.lblNext) then local s = lv.slot; Bank.pending = function() actPayNext(s, w) end end
      ImGui.SameLine()
    end
    if ImGui.Button(lv.lblOff) then local s = lv.slot; Bank.pending = function() actPayOff(s, w) end end
  end
  ImGui.Separator()
  ImGui.Text("New personal loan (paid into the account)")
  if v.borrowWhy ~= "" then
    colored(GREY, v.borrowWhy)
    return
  end
  ImGui.PushItemWidth(170)
  local a, changed = ImGui.InputInt("eddies##csbloan", ui.loanAmount, 1000, 10000)
  ImGui.PopItemWidth()
  if changed then ui.loanAmount = clamp(int(a), 0, INT_MAX); ui.confirm = nil end
  for _, q in ipairs(LQUICK) do
    ImGui.SameLine()
    if ImGui.Button(q[2]) then ui.loanAmount = q[1]; ui.confirm = nil end
  end
  ImGui.SameLine()
  if ImGui.Button("max##cslqmax") then ui.loanAmount = v.avail; ui.confirm = nil end
  ImGui.Text("Payments:")
  for i = 1, #TERMS do
    ImGui.SameLine()
    if ImGui.Button(TERM_LBL[i][ui.term == i and 2 or 1]) then ui.term = i; ui.confirm = nil end
  end
  local pv = loanPreview()
  colored(GREY, pv.text)
  if ui.confirm == "loan" then
    if ImGui.Button(pv.confirm) then
      local x, t = ui.loanAmount, ui.term
      ui.confirm = nil
      Bank.pending = function() actTakeLoan(x, t) end
    end
    ImGui.SameLine()
    if ImGui.Button("Cancel##csbcancel") then ui.confirm = nil end
  else
    if ImGui.Button("Take loan##csbtake") then ui.confirm = "loan" end
  end
end

local function rowsLoop(list)
  for _, r in ipairs(list) do
    ImGui.TableNextRow()
    ImGui.TableNextColumn()
    ImGui.Text(r[1])
    ImGui.TableNextColumn()
    if r.bad then colored(RED, r[2]) else ImGui.Text(r[2]) end
    ImGui.TableNextColumn()
    if r[5] > 0 then colored(GREEN, r[3]) elseif r[5] < 0 then colored(AMBER, r[3]) else ImGui.Text(r[3]) end
    ImGui.TableNextColumn()
    ImGui.Text(r[4])
  end
end

local function drawRows(list)
  if ImGui.BeginTable("##csbhist", 4, ImGuiTableFlags.Borders + ImGuiTableFlags.RowBg) then
    ImGui.TableSetupColumn("When")
    ImGui.TableSetupColumn("What")
    ImGui.TableSetupColumn("Amount")
    ImGui.TableSetupColumn("Balance")
    ImGui.TableHeadersRow()
    local ok, err = pcall(rowsLoop, list)
    ImGui.EndTable() -- always closed, even after an error
    if not ok then error(err, 0) end
  end
end

local function drawChart(v)
  if Bank.noChart or #v.chart < 2 then return end
  local ok = pcall(function()
    ImGui.PlotLines("##csbchart", v.chart, #v.chart, 0, v.chartLabel, v.chartMin, v.chartMax, 560, 70)
  end)
  if not ok then ok = pcall(function() ImGui.PlotLines("##csbchart", v.chart, #v.chart) end) end
  if not ok then Bank.noChart = true end
end

local function drawHistory(v)
  local ui = Bank.ui
  for i, f in ipairs(FILTERS) do
    if i > 1 then ImGui.SameLine() end
    if ImGui.Button(f[ui.filter == i and 2 or 1]) then ui.filter = i end
  end
  drawChart(v)
  local list = v.rows[FILTERS[ui.filter][3]] or v.rows.all
  if #list == 0 then
    colored(GREY, "No entries yet.")
    return
  end
  ImGui.BeginChild("##csbhistchild", 580, 300, true)
  local ok, err = pcall(drawRows, list)
  ImGui.EndChild()
  if not ok then error(err, 0) end
end

local function safe(fn, v)
  local ok, err = pcall(fn, v)
  if not ok and not Bank.drawErr then
    Bank.drawErr = true
    print("[CyberslopBank] window error: " .. tostring(err))
  end
end

local function body(v)
  if not v or v.err then
    ImGui.Text(v and v.err or "...")
    return
  end
  ImGui.Text(string.format("%s    Wallet %s eb    Account %s eb", v.clock, v.wallet, v.bal))
  if Bank.msg then colored(Bank.msgBad and RED or GREEN, Bank.msg) end
  if not v.open then
    ImGui.Text("No Cyberslop Bank account in this save.")
    if ImGui.Button("Open an account##csbopen") then Bank.pending = actOpen end
    return
  end
  if ImGui.BeginTabBar("##csbtabs") then
    if ImGui.BeginTabItem("Account") then safe(drawAccount, v); ImGui.EndTabItem() end
    if ImGui.BeginTabItem("Loans") then safe(drawLoans, v); ImGui.EndTabItem() end
    if ImGui.BeginTabItem("History") then safe(drawHistory, v); ImGui.EndTabItem() end
    ImGui.EndTabBar()
  end
end

-- ---------------------------------------------------------------- HUD summary (hotkey)

local function hudLine()
  if not inGame() or not load() then return end
  local m = now()
  local today = dayOf(m)
  settle(today, m)
  creditStart()
  save()
  Bank.dirty = true
  local A = S.acc
  local text
  if A.v ~= 1 then
    text = "Cyberslop Bank: no account (CET window)"
  else
    local parts = { "account " .. num(A.bal) .. " eb" }
    for s = 1, SLOTS do
      local L = S.loans[s]
      if L.st == 2 then
        table.insert(parts, "LOAN IN DEFAULT, " .. num(L.ar) .. " eb due")
      elseif L.ar > 0 then
        table.insert(parts, "OVERDUE " .. num(L.ar) .. " eb")
      elseif L.st == 1 then
        table.insert(parts, string.format("loan %s eb left, next %s eb day %d (in %d d)", num(owed(L)),
          num(math.min(L.inst, L.du)), L.nx, math.max(0, L.nx - today)))
      end
    end
    text = "Cyberslop Bank: " .. table.concat(parts, " · ")
  end
  local msg = SimpleScreenMessage.new()
  msg.message = text
  msg.duration = 6.0
  msg.isShown = true
  local defs = Game.GetAllBlackboardDefs()
  Game.GetBlackboardSystem():Get(defs.UI_Notifications):SetVariant(defs.UI_Notifications.WarningMessage, ToVariant(msg), true)
end

-- ---------------------------------------------------------------- events

local function run(action)
  local ok, err = pcall(action)
  if not ok then
    say("Error: " .. tostring(err), true)
    print("[CyberslopBank] " .. tostring(err))
  end
  pcall(refresh)
end

registerForEvent("onInit", function()
  print("[CyberslopBank] " .. Bank.version .. " loaded")
end)
registerForEvent("onOverlayOpen", function()
  Bank.overlay = true
  Bank.dirty = true
  Bank.ui.confirm = nil
end)
registerForEvent("onOverlayClose", function()
  Bank.overlay = false
  Bank.msg = nil
end)
registerHotkey("CyberslopBankSummary", "Bank summary (HUD line)", function()
  local ok, err = pcall(hudLine)
  if not ok then print("[CyberslopBank] " .. tostring(err)) end
end)
registerHotkey("CyberslopBankWindow", "Show / hide the bank window", function()
  Bank.hidden = not Bank.hidden
end)

registerForEvent("onDraw", function()
  if not Bank.overlay or Bank.hidden then return end
  local t = os.clock()
  if Bank.dirty then
    Bank.dirty = false
    Bank.nextCheck = t + 5
    pcall(refresh)
  elseif t >= Bank.nextCheck then
    Bank.nextCheck = t + 5
    local ok, d = pcall(function() return dayOf(now()) end)
    if ok and d ~= Bank.lastDay then
      pcall(refresh)
    elseif Bank.v and Bank.v.wallet then
      Bank.v.wallet = num(wallet())
    end
  end
  local open, shown = ImGui.Begin("Cyberslop Bank", true, ImGuiWindowFlags.AlwaysAutoResize)
  if open == false then Bank.hidden = true end
  if shown then safe(body, Bank.v) end
  ImGui.End()
  if Bank.pending then
    local action = Bank.pending
    Bank.pending = nil
    run(action)
  end
end)

return Bank
