-- Cyberslop Pharm Courier 1.0.4 (2026-11-26)
-- 1.0.4: item names resolved here (the script returned "LocKey#..." for non-Merc-Stims items), also in order lists.
-- 1.0.2: Merc Stims 1.2.0 humanity items (Humanity group, Kill Switch on the grey-market desk).
-- 1.0.3: Cyberslop Clinic Meds (Clinic cures group); Legendary items are only sold here (drone-only); neuroblockers,
--        Dark Future meds and Injuries treatments too: the whole pharmacy in one window.
-- 1.0.1: hover an item name: brief + / - lines of what it does (green / red) and the game's own effect lines;
--        wider name column; Street Cred -1 % per 2 cred, -25 % at Cred 50 (needs the 1.0.1 redscript).
-- Afterhours Pharm's wholesale desk for the Cyberslop Merc Stims consumables: order any amount (1 is fine, 10 / 20 /
-- 30 / 50+ of one item get bulk rates), Street Cred lowers every price, drones bring it to the clinic lockers (pick up
-- at any medpoint or ripperdoc) or to your apartment (any of your places) in 2-3 game hours.
-- All prices, payment, orders and delivery live in the redscript (r6\scripts\zz_CyberslopPharmCourier), saved with
-- the game. This window only shows and asks.
--   With the CET overlay open: the window is there, with buttons (two clicks for anything that costs).
--   Hotkeys (CET > Bindings, unbound): show / hide the window, collect here.
--   A landed order where you stand shows a small hint without the overlay.

local PC = {
  version = "1.0.4",
  overlay = false,
  pinned = false,
  dest = 0,            -- 0 clinic locker, 1 apartment
  items = nil,
  d = nil,
  nextPoll = 0,
  nextFull = 0,
  msg = nil,
  msgUntil = 0,
  confirm = nil,
  confirmUntil = 0,
  hkUntil = 0,
}

local RED = { 1.0, 0.35, 0.3, 1.0 }
local AMBER = { 1.0, 0.75, 0.3, 1.0 }
local GREEN = { 0.5, 0.95, 0.6, 1.0 }
local GREY = { 0.65, 0.65, 0.65, 1.0 }
local CYAN = { 0.45, 0.85, 1.0, 1.0 }

local TIPS = {   -- TIPS BEGIN (brief effect lines per item id; "+" good, "-" cost or side effect)
  ["Vigil"] = { "+ Energy held up 12 h (cannot drop), +15 Energy at once", "+ faster reloads and aiming", "- when it ends 25 % of the held-back fatigue hits at once", "- each extra dose in a row works less, bigger bill" },
  ["HoldFast"] = { "+ Energy held up 6 h, +25 Energy at once", "+ stamina regen +15 %, +15 stamina, faster reloads", "- when it ends 50 % of the held-back fatigue hits at once", "  usable in combat" },
  ["Surge"] = { "+ Energy held up 4 h, +20 Energy at once", "+ a little stamina regen", "- recoil 8 % worse while it runs", "- when it ends ALL held-back fatigue hits at once" },
  ["Lull"] = { "+ sleep within 1 h: sleep restores 30 % more Energy, stim debt paid 1.5x faster", "- stay awake past the first hour: drowsy (slow aim, shaky hands) until 4 h" },
  ["Kagami"] = { "+ 1.5 h: recoil -25 %, reload +20 %, aiming +25 %, mitigation +10 %, stamina regen +10 %", "+ 20 temporary Energy", "- after: temporary Energy gone, Nerve -10, 1 h Neural Lag (slower, more recoil)", "- a second dose while it runs does nothing good", "  usable in combat" },
  ["Hardline"] = { "+ 10 min: cannot be knocked down or stunned, stamina regen +25 %", "- after: Nerve -15, 30 min exhaustion (less stamina)", "  usable in combat" },
  ["Boost"] = { "+ 2 h: RAM recovery +25 %, quickhack uploads +20 % faster", "- after: 1 h migraine (slower RAM, slower aiming)", "  usable in combat" },
  ["Antitox"] = { "+ 1 h: immune to poison, +50 chemical resistance", "- after: 30 min nausea, a little thirst", "  usable in combat" },
  ["Rapidetox"] = { "+ ends every alcohol and narcotic effect at once", "- the Energy they were lending goes too; Hydration -15, 30 min nausea", "  does nothing for an addiction" },
  ["Steady"] = { "+ 4 h: Nerve cannot fall below its level at the dose", "+ recoil -10 %, slightly faster aiming, harder to spot", "- stamina regen -10 %", "  usable in combat" },
  ["Serene"] = { "+ +30 Nerve over 1 h, slightly steadier hands", "  no high, no addiction" },
  ["ZeroPoint"] = { "+ +25 Nerve at once, steadier hands", "- 20 min: a little slower to aim and recover", "  usable in combat" },
  ["Emberline"] = { "+ 24 h: no nicotine withdrawal, no smoking debuff", "+ while a cigarette burns: recoil -20 %, aiming +20 %, reload +10 %, half of Nerve loss restored", "- the addiction itself stays; does nothing without a smoke" },
  ["Respirocyte"] = { "+ 6 h: oxygen reserve +30 %, oxygen recovery +30 %, +5 stamina", "  usable in combat" },
  ["Bronchodilator"] = { "+ 1 h: oxygen recovery +30 %", "- slightly shaky hands", "  usable in combat" },
  ["ProteoMax"] = { "+ full meal (Nutrition), no bio-corruption", "+ 6 h: +10 stamina, health regen +10 %" },
  ["Electra"] = { "+ large Hydration", "+ 3 h: stamina regen +10 %" },
  ["CorpoDaily"] = { "+ 24 h: Hydration and Nutrition drain 15 % slower, health regen +5 %" },
  ["Ketone"] = { "+ small Nutrition", "+ 2 h: stamina regen +15 %, +5 stamina, no sugar crash", "  usable in combat" },
  ["ColdBrew"] = { "+ caffeine (Energy) and a little Hydration", "+ 2 h: slightly faster aiming" },
  ["HydraSalt"] = { "+ medium Hydration", "  usable in combat" },
  ["NutriGel"] = { "+ medium Nutrition", "  usable in combat" },
  ["NeuroSync"] = { "+ 12 h: Sandevistan recharge and Kerenzikov cooldown -10 %, slightly faster aiming" },
  ["OsteoCal"] = { "+ 24 h: +25 carry capacity, +10 melee resistance" },
  ["BioCoolant"] = { "+ 6 h: RAM recovery +10 %, +20 thermal resistance" },
  ["Rejectol"] = { "+ 24 h: 15 % less Humanity damage (Wannabe Edgerunner)", "- health regen -5 %" },
  ["Ghostline"] = { "+ 12 h: nobody tracks you down while you sleep in a vehicle (no gang ambush)" },
  ["Crank"] = { "+ 3-4 Overdrive stacks: lots of temporary Energy and Nerve", "- Euphoria, strong addiction, overdose risk; the Energy goes when it wears off" },
  ["Synthcoke"] = { "+ 2-3 Overdrive stacks: temporary Energy and Nerve", "- Euphoria, addiction, overdose risk" },
  ["Anchor"] = { "+ restores 10 Humanity, then +1 every game hour", "+ 24 h: chrome and violence cost 40 % less Humanity", "- heavy calm: stamina regen -10 %" },
  ["Tether"] = { "+ restores 3 Humanity", "+ 8 h: 20 % less Humanity damage", "  no side effects" },
  ["Lumen"] = { "+ restores 15 Humanity over 2 h", "- while it works: aiming -20 %, recoil +15 %", "  not usable in combat; take it somewhere safe" },
  ["CircuitBreaker"] = { "+ EMERGENCY: stops an episode that is starting or running", "+ 15 min: no Humanity damage, no episode; +5 Humanity", "- after: Nerve -10, 1 h sedated (stamina regen -30 %, slower aim)", "  usable in combat" },
  ["KillSwitch"] = { "+ LAST RESORT: stops any episode at once", "+ 1 h: no Humanity damage, no episode; +20 Humanity", "- Energy -30, Nerve -20 at once; 1 h sedated, then 2 h straitjacket (stamina regen -40 %, -20 stamina, aim -25 %)", "  usable in combat" },
  ["CyberslopNeuroMend.Ampoule"] = { "+ cures a concussion (Injuries), ends Pain Blockers", "- 10 min: stamina comes back slower" },
  ["CyberslopMeds.HemoSeal"] = { "+ stops bleeding (Injuries), ends the MedKit buff", "- 5 min: -10 stamina" },
  ["CyberslopMeds.OsteoWeld"] = { "+ mends broken arms and legs (Injuries), no painkiller flare-up", "- 15 min: -10 stamina, slower stamina recovery" },
  ["CyberslopMeds.ReGen9"] = { "+ cures EVERY injury and Dark Future's Injury condition", "- 20 min: -15 stamina, slower stamina recovery" },
  ["CyberslopMeds.Quell"] = { "+ ends the current withdrawal (nicotine, alcohol, narcotic)", "- the addiction stays; cravings come back later", "- 10 min: slower stamina recovery" },
  ["CyberslopMeds.CleanSlate"] = { "+ cures EVERY Dark Future addiction", "- 30 min: -25 stamina, slower stamina recovery" },
  ["CyberslopMeds.ChelaTox"] = { "+ cures poison", "- 2 min: mild nausea" },
  ["Items.ripperdoc_med_common"] = { "+ neuroblocker: no Humanity damage and no episode for 8 min (real time)", "+ stops an episode that is starting" },
  ["Items.ripperdoc_med_uncommon"] = { "+ neuroblocker: no Humanity damage and no episode for 17 min (real time)", "+ stops an episode that is starting" },
  ["Items.ripperdoc_med"] = { "+ neuroblocker: no Humanity damage and no episode for 30 min (real time)", "+ stops an episode that is starting" },
  ["Items.ripperdoc_med_milspec"] = { "+ mil-spec neuroblocker: no Humanity damage and no episode for 45 min (real time)", "- then a 10 min crash" },
  ["DarkFutureItem.ImmunosuppressantDrug"] = { "+ holds episodes off (Wannabe Edgerunner), +3 Humanity once", "- Humanity damage still counts" },
  ["DarkFutureItem.EndotrisineDrug"] = { "+ 12 game h: Humanity recovery from rest and good deeds works (Cyberslop Edgerunner)" },
  ["DarkFutureItem.AddictionTreatmentDrug"] = { "+ 12 game h: addiction withdrawal suppressed", "- Energy -40, drowsy" },
  ["DarkFutureItem.NerveRestoreDrug"] = { "+ cures a narcotic overdose, restores Nerve" },
  ["DarkFutureItem.HangoverTreatmentDrug"] = { "+ cures a hangover" },
  ["Injuries.MedKit"] = { "+ treats bleeding and wounds (Injuries)" },
  ["Injuries.ConcussionPill"] = { "+ Pain Blockers: masks a concussion (Injuries)" },
  ["Injuries.Painkiller"] = { "+ masks broken arm and leg pain (Injuries)", "- the pain flares up when it wears off" },
}   -- TIPS END
local REC_PREFIX = "CyberslopStims."   -- item record = REC_PREFIX .. id

-- The game's own effect lines of an item (OnAttach / OnEquip UIData with the numbers filled in, as the inventory
-- tooltip shows them). Cached per id.
local fxCache = {}
local function fmtFloat(v)
  if type(v) ~= "number" then return tostring(v) end
  if math.abs(v - math.floor(v + 0.5)) < 0.001 then return tostring(math.floor(v + 0.5)) end
  return (string.format("%.2f", v):gsub("0+$", ""):gsub("%.$", ""))
end

local function gameLines(id)
  if fxCache[id] then return fxCache[id] end
  local out = {}
  pcall(function()
    local rec = TweakDBInterface.GetItemRecord(TweakDBID.new(id:find(".", 1, true) and id or (REC_PREFIX .. id)))
    if not rec then return end
    for _, getter in ipairs({ "OnAttach", "OnEquip" }) do
      pcall(function()
        for _, pkg in ipairs(rec[getter](rec) or {}) do
          pcall(function()
            local ui = pkg:UIData()
            if not ui then return end
            local text = Game.GetLocalizedTextByKey(ui:LocalizedDescription())
            if type(text) ~= "string" or text == "" or text == "None" then return end
            local ints, floats = {}, {}
            pcall(function() ints = ui:IntValues() or {} end)
            pcall(function() floats = ui:FloatValues() or {} end)
            text = text:gsub("{(%a+)_(%d+)[^}]*}", function(kind, n)
              local i = tonumber(n) + 1
              if kind == "int" and ints[i] ~= nil then return tostring(ints[i]) end
              if kind == "float" and floats[i] ~= nil then return fmtFloat(floats[i]) end
              return nil
            end):gsub("<[^>]*>", "")
            for line in (text .. "\n"):gmatch("([^\n]*)\n") do
              line = line:gsub("^%s+", ""):gsub("%s+$", "")
              if line ~= "" then out[#out + 1] = line end
            end
          end)
        end
      end)
    end
  end)
  fxCache[id] = out
  return out
end

local function drawItemTip(it, d)
  ImGui.BeginTooltip()
  ImGui.PushTextWrapPos(ImGui.GetFontSize() * 30)
  ImGui.Text(it.name)
  local tips = TIPS[it.id]
  if tips then
    for _, line in ipairs(tips) do
      local c = line:sub(1, 1)
      if c == "+" then
        ImGui.TextColored(0.5, 0.95, 0.6, 1.0, line)
      elseif c == "-" then
        ImGui.TextColored(1.0, 0.42, 0.36, 1.0, line)
      else
        ImGui.TextColored(0.65, 0.65, 0.65, 1.0, line)
      end
    end
  end
  local g = gameLines(it.id)
  if #g > 0 then
    ImGui.Separator()
    ImGui.TextColored(0.65, 0.65, 0.65, 1.0, "Game tooltip:")
    for _, line in ipairs(g) do
      if line:find("^%-%d") or line:find(" %-%d") then
        ImGui.TextColored(1.0, 0.42, 0.36, 1.0, line)
      else
        ImGui.TextColored(0.45, 0.85, 1.0, 1.0, line)
      end
    end
  end
  if not it.exists then
    ImGui.TextColored(1.0, 0.75, 0.3, 1.0, "Not in the game: the mod with this item is missing.")
  elseif it.grey and d and not d.greyOk then
    ImGui.TextColored(1.0, 0.75, 0.3, 1.0, "Grey-market desk: Street Cred " .. (d.greyCred or 0) .. "+ only.")
  end
  ImGui.PopTextWrapPos()
  ImGui.EndTooltip()
end

local DEST = { [0] = "Clinic locker", [1] = "Apartment drop" }

local function sys()
  local ok, s = pcall(function() return Game.GetScriptableSystemsContainer():Get("CyberslopPharmCourier.PharmCourier") end)
  if ok and s then return s end
  return nil
end

local function num(v)
  local s = tostring(math.floor((v or 0) + 0.5))
  local neg = s:sub(1, 1) == "-"
  if neg then s = s:sub(2) end
  local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
  return (neg and "-" or "") .. out
end

local function clock(min)
  min = math.ceil(min or 0)
  if min < 60 then return min .. " min" end
  return string.format("%dh %02dm", math.floor(min / 60), min % 60)
end

local function colored(c, text) ImGui.TextColored(c[1], c[2], c[3], c[4], text) end

local function say(text)
  PC.msg = text
  PC.msgUntil = os.clock() + 20
end

local function hud(text)
  pcall(function()
    local m = SimpleScreenMessage.new()
    m.message = text
    m.duration = 6.0
    m.isShown = true
    local defs = Game.GetAllBlackboardDefs()
    Game.GetBlackboardSystem():Get(defs.UI_Notifications):SetVariant(defs.UI_Notifications.WarningMessage, ToVariant(m), true)
  end)
end

------------------------------------------------------------------------ data

-- 1.0.4: a name the script could not translate ("LocKey#..." or empty) is looked up here, like the Backpack does.
local nameFix = {}
local function resolveName(name, id)
  if type(name) == "string" and name ~= "" and not name:find("^LocKey#") and name ~= id then return name end
  local out = name
  pcall(function()
    local full = id:find(".", 1, true) and id or (REC_PREFIX .. id)
    local rec = TweakDBInterface.GetItemRecord(TweakDBID.new(full))
    if not rec then return end
    local t = Game.GetLocalizedTextByKey(rec:DisplayName())
    if type(t) == "string" and t ~= "" and t ~= "None" then out = t end
  end)
  if type(name) == "string" and name ~= "" and out ~= name then nameFix[name] = out end
  return out
end

local function fixText(text)
  if type(text) ~= "string" then return text end
  return (text:gsub("LocKey#%d+", function(k) return nameFix[k] or k end))
end

local function loadCatalog(s)
  if PC.items then return end
  local items = {}
  local ok = pcall(function()
    local n = s:Size()
    for i = 0, n - 1 do
      local id = s:ItemId(i)
      items[#items + 1] = { i = i, id = id, name = resolveName(s:ItemName(i), id), group = s:ItemGroup(i),
                            price = s:ItemPrice(i), grey = s:ItemGrey(i), exists = s:ItemExists(i),
                            qty = 0, line = 0, carried = 0 }
    end
  end)
  if ok and #items > 0 then PC.items = items end
end

local function requote(s)
  local d = PC.d
  if not d then return end
  pcall(function()
    d.total = s:Quote(PC.dest)
    d.units, d.drones, d.list = s:QUnits(), s:QDrones(), s:QList()
    d.bulk, d.cred, d.goods, d.fee = s:QBulk(), s:QCred(), s:QGoods(), s:QFee()
    d.blocked = s:CartBlocked()
    d.feeEach = s:FeePerDrone(PC.dest)
    d.etaMin, d.etaMax = s:EtaMinMinutes(PC.dest), s:EtaMaxMinutes(PC.dest)
  end)
end

local function setQty(s, it, q)
  local ok, v = pcall(function() return s:CartSet(it.i, q) end)
  it.qty = (ok and v) or 0
  local okL, l = pcall(function() return s:LineTotal(it.i, it.qty) end)
  it.line = (okL and l) or 0
  local okB, b = pcall(function() return s:BulkPct(it.qty) end)
  it.bulkPct = (okB and b) or 0
  requote(s)
end

-- Light poll (every second, window or not): arrivals and their messages, where V stands.
local function pollLight()
  local s = sys()
  if not s or not Game.GetPlayer() then PC.at, PC.ready = -1, 0 return end
  pcall(function()
    PC.at = s:Poll()
    PC.atName = s:AtName()
    PC.ready = s:ReadyHere()
  end)
end

-- Full poll (only while the window shows).
local function pollFull()
  local s = sys()
  if not s or not Game.GetPlayer() then PC.d = nil return end
  loadCatalog(s)
  if not PC.items then PC.d = nil return end
  local d = PC.d or {}
  PC.d = d
  pcall(function()
    s:RefreshCarried()
    d.money = s:Money()
    d.credLevel = s:StreetCred()
    d.credPct = s:CredPct()
    d.greyOk = s:GreyOk()
    d.greyCred = s:GreyCred()
    d.perDrone = s:UnitsPerDrone()
    for _, it in ipairs(PC.items) do
      it.carried = s:Carried(it.i)
      it.qty = s:CartQty(it.i)          -- the cart lives in the script (empty again after a load)
      it.line = s:LineTotal(it.i, it.qty)
      it.bulkPct = s:BulkPct(it.qty)
    end
    d.orders = {}
    local n = s:OrderCount()
    for k = 0, n - 1 do
      d.orders[#d.orders + 1] = { id = s:OrderId(k), dest = s:OrderDest(k), units = s:OrderUnits(k), paid = s:OrderPaid(k),
                                  left = s:OrderMinutesLeft(k), landed = s:OrderArrived(k), what = fixText(s:OrderSummary(k)) }
    end
  end)
  requote(s)
end

------------------------------------------------------------------------ actions

local function costButton(key, label, confirmLabel, action)
  local armed = PC.confirm == key and os.clock() < PC.confirmUntil
  if armed then
    ImGui.PushStyleColor(ImGuiCol.Button, 0.7, 0.25, 0.15, 1.0)
    local hit = ImGui.Button(confirmLabel .. "##" .. key)
    ImGui.PopStyleColor(1)
    if hit then
      PC.confirm = nil
      action()
    end
  elseif ImGui.Button(label .. "##" .. key) then
    PC.confirm = key
    PC.confirmUntil = os.clock() + 4
  end
end

local function doOrder()
  local s = sys()
  if not s then return end
  local ok, res = pcall(function() return s:PlaceOrder(PC.dest) end)
  say(ok and fixText(res) or "Order failed (see CET log)")
  PC.nextFull = 0
end

local function doCollect()
  local s = sys()
  if not s then return end
  local ok, res = pcall(function() return s:Collect() end)
  say(ok and fixText(res) or "Pick-up failed (see CET log)")
  PC.nextFull = 0
  return ok and res or nil
end

local function doCancel(id)
  local s = sys()
  if not s then return end
  local ok, res = pcall(function() return s:Cancel(id) end)
  say(ok and res or "Recall failed (see CET log)")
  PC.nextFull = 0
end

local function clearCart()
  local s = sys()
  if not s then return end
  pcall(function() s:CartClear() end)
  for _, it in ipairs(PC.items or {}) do it.qty, it.line, it.bulkPct = 0, 0, 0 end
  requote(s)
end

registerHotkey("CyberslopPharmCourierToggle", "Pharm Courier: show / hide window", function()
  PC.pinned = not PC.pinned
  PC.nextFull = 0
end)

registerHotkey("CyberslopPharmCourierCollect", "Pharm Courier: collect landed orders here", function()
  pollLight()
  if (PC.at or -1) < 0 then
    hud("Afterhours Pharm: no drop point here (a medpoint or ripperdoc, or one of your places).")
    return
  end
  local res = doCollect()
  if res then hud(res) end
end)

registerForEvent("onInit", function()
  print("[CyberslopPharmCourier] " .. PC.version .. " loaded")
end)
registerForEvent("onOverlayOpen", function() PC.overlay = true; PC.nextFull = 0 end)
registerForEvent("onOverlayClose", function() PC.overlay = false end)

registerForEvent("onUpdate", function()
  local t = os.clock()
  if t >= PC.nextPoll then
    PC.nextPoll = t + 1.0
    pollLight()
  end
end)

------------------------------------------------------------------------ window

local COL_CARRIED, COL_PRICE, COL_QTY, COL_QUICK, COL_LINE = 300, 360, 430, 535, 650

local function drawRow(s, d, it)
  local locked = it.grey and not d.greyOk
  local missing = not it.exists
  colored((locked or missing) and GREY or (it.qty > 0 and CYAN or { 0.9, 0.9, 0.9, 1.0 }), it.name)
  if ImGui.IsItemHovered() then drawItemTip(it, d) end
  ImGui.SameLine(COL_CARRIED)
  colored(GREY, "x" .. it.carried)
  ImGui.SameLine(COL_PRICE)
  colored(GREY, num(it.price))
  ImGui.SameLine(COL_QTY)
  if locked or missing then
    colored(GREY, locked and ("Street Cred " .. d.greyCred) or "missing")
    return
  end
  ImGui.SetNextItemWidth(95)
  local v, changed = ImGui.InputInt("##q" .. it.i, it.qty, 1, 10)
  if changed and type(v) == "number" then setQty(s, it, v) end
  ImGui.SameLine(COL_QUICK)
  for _, q in ipairs({ 10, 20, 30 }) do
    if ImGui.SmallButton(q .. "##b" .. q .. "_" .. it.i) then setQty(s, it, q) end
    ImGui.SameLine()
  end
  ImGui.SameLine(COL_LINE)
  if it.qty > 0 then
    local disc = (it.bulkPct or 0) > 0 and string.format("  (bulk -%d%%)", it.bulkPct) or ""
    colored((it.bulkPct or 0) > 0 and GREEN or { 0.9, 0.9, 0.9, 1.0 }, num(it.line) .. disc)
  else
    ImGui.Text("")
  end
end

local function drawCatalog(s, d)
  colored(GREY, string.format("Bulk rate per item: 10+ -6%%  20+ -10%%  30+ -14%%  50+ -18%%.   Street Cred %d: -%d%% on everything.",
    d.credLevel or 0, d.credPct or 0))
  colored(GREY, "Item (hover for effects)")
  ImGui.SameLine(COL_CARRIED) colored(GREY, "carried")
  ImGui.SameLine(COL_PRICE) colored(GREY, "list")
  ImGui.SameLine(COL_QTY) colored(GREY, "order")
  ImGui.SameLine(COL_LINE) colored(GREY, "price")
  if ImGui.BeginChild("##pccat", 0, 430, true) then
    local group
    for idx, it in ipairs(PC.items) do
      if it.group ~= group then
        group = it.group
        if idx > 1 then ImGui.Spacing() end
        colored(AMBER, group .. (group == "Grey market" and ("  (Street Cred " .. d.greyCred .. "+)") or ""))
      end
      drawRow(s, d, it)
    end
  end
  ImGui.EndChild()
end

local function drawCheckout(s, d)
  ImGui.Text("Deliver to:")
  ImGui.SameLine()
  if ImGui.RadioButton("Clinic locker##pcd0", PC.dest == 0) then PC.dest = 0; requote(s) end
  if ImGui.IsItemHovered() then
    ImGui.SetTooltip("Afterhours keeps lockers at every medpoint and ripperdoc in the city.\nCollect at any of them. 250 per drone, lands in 2:00-2:30 game hours.")
  end
  ImGui.SameLine()
  if ImGui.RadioButton("Apartment drop##pcd1", PC.dest == 1) then PC.dest = 1; requote(s) end
  if ImGui.IsItemHovered() then
    ImGui.SetTooltip("Residential drop box: collect at any of your places (near your stash).\n600 per drone (residential airspace permit), lands in 2:30-3:00 game hours.")
  end
  if (d.units or 0) <= 0 then
    colored(GREY, "Cart empty. Set an amount on any line: one is fine, 10 / 20 / 30 or more of one item gets the bulk rate.")
    return
  end
  local line = string.format("%d units, %d %s.  Goods %s", d.units, d.drones, d.drones == 1 and "drone" or "drones", num(d.list))
  if (d.bulk or 0) > 0 then line = line .. "  bulk -" .. num(d.bulk) end
  if (d.cred or 0) > 0 then line = line .. "  cred -" .. num(d.cred) end
  line = line .. string.format("  drone fee %s (%d x %s)", num(d.fee), d.drones, num(d.feeEach))
  ImGui.Text(line)
  local afford = (d.money or 0) >= (d.total or 0)
  colored(afford and GREEN or RED, string.format("Total %s eddies (you have %s).  ETA %s - %s game time.",
    num(d.total), num(d.money), clock(d.etaMin), clock(d.etaMax)))
  if d.blocked and d.blocked ~= "" then
    colored(AMBER, d.blocked)
  elseif afford then
    costButton("order", "Place order", "Pay " .. num(d.total) .. " eddies", doOrder)
    ImGui.SameLine()
  end
  if ImGui.Button("Clear cart##pcclr") then clearCart() end
end

local function drawOrders(s, d)
  local orders = d.orders or {}
  ImGui.Separator()
  if PC.at == 0 then
    colored(GREEN, "Here: " .. (PC.atName or "clinic") .. ". Clinic-locker orders can be collected.")
  elseif PC.at == 1 then
    colored(GREEN, "Here: your place. Apartment orders can be collected.")
  else
    colored(GREY, "No drop point here: stand at a medpoint / ripperdoc (7 m) or in one of your places.")
  end
  if #orders == 0 then
    colored(GREY, "No drones in the air.")
    return
  end
  for _, o in ipairs(orders) do
    local where = DEST[o.dest] or "?"
    if o.landed then
      local here = PC.at == o.dest
      colored(here and GREEN or CYAN, string.format("#%d  %s  %d units  LANDED%s", o.id, where, o.units,
        here and ", collect it here" or (o.dest == 1 and ", waiting at your place" or ", waiting in the clinic lockers")))
    else
      ImGui.Text(string.format("#%d  %s  %d units  lands in %s", o.id, where, o.units, clock(o.left)))
    end
    if ImGui.IsItemHovered() then
      ImGui.SetTooltip(o.what .. "\nPaid " .. num(o.paid) .. " eddies.")
    end
    if not o.landed then
      ImGui.SameLine()
      costButton("cancel" .. o.id, "Recall", "Recall: goods refunded, fee kept", function() doCancel(o.id) end)
    end
  end
  if (PC.ready or 0) > 0 then
    if ImGui.Button(string.format("Collect %d %s here##pccol", PC.ready, PC.ready == 1 and "order" or "orders")) then doCollect() end
  end
end

registerForEvent("onDraw", function()
  local full = PC.overlay or PC.pinned
  if not full then
    -- a landed order where V stands: small hint
    if (PC.ready or 0) > 0 then
      if ImGui.Begin("Afterhours drop##pchint", ImGuiWindowFlags.AlwaysAutoResize + ImGuiWindowFlags.NoFocusOnAppearing + ImGuiWindowFlags.NoTitleBar) then
        colored(GREEN, string.format("Afterhours Pharm: %d %s ready here. Collect key or CET overlay.",
          PC.ready, PC.ready == 1 and "order" or "orders"))
      end
      ImGui.End()
    end
    return
  end
  local t = os.clock()
  if t >= PC.nextFull then
    PC.nextFull = t + 1.0
    pcall(pollFull)
  end
  local s = sys()
  local d = PC.d
  ImGui.SetNextWindowPos(60, 120, ImGuiCond.FirstUseEver)
  if not ImGui.Begin("Afterhours Pharm - drone courier", ImGuiWindowFlags.AlwaysAutoResize + ImGuiWindowFlags.NoFocusOnAppearing) then
    ImGui.End()
    return
  end
  if not s or not d or not PC.items then
    colored(AMBER, s and "Load a save first." or "Pharm Courier script not running (r6\\scripts\\zz_CyberslopPharmCourier).")
    ImGui.End()
    return
  end
  colored(CYAN, "Biotechnica-licensed grey stock, wholesale, dropped by drone. No questions.")
  ImGui.Text("Eddies: " .. num(d.money))
  drawCatalog(s, d)
  drawCheckout(s, d)
  drawOrders(s, d)
  if PC.msg and os.clock() < PC.msgUntil then
    ImGui.Separator()
    ImGui.PushTextWrapPos(720)
    colored(CYAN, PC.msg)
    ImGui.PopTextWrapPos()
  end
  ImGui.End()
end)

return PC
