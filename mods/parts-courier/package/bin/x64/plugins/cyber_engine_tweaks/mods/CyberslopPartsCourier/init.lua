-- Cyberslop Parts Courier 1.0.1 (2026-11-26). Generated from Cyberslop Parts Courier 1.0.4.
-- Scrapline Parts Exchange - drone freight: order crafting components (weapon / gear Common - Legendary, quickhack Uncommon - Legendary) in any amount (25+ -5 %, 50+ -10 %, 100+ -15 %, 250+ -20 % per component line),
-- Street Cred lowers every price, drones bring it to the dealer lockers (pick up next to any tech, junk, gun or armor dealer) or to your
-- apartment (near your stash) in 2h 00m - 3h 00m game time.
-- All prices, payment, orders and delivery live in the redscript (r6\scripts\zz_CyberslopPartsCourier), saved with the game.
--   With the CET overlay open: the window is there, with buttons (two clicks for anything that costs).
--   Hotkeys (CET > Bindings, unbound): show / hide the window, collect here.

local PC = {
  version = "1.0.1",
  overlay = false,
  pinned = false,
  dest = 0,            -- 0 vendor locker, 1 apartment
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
  ["Items.CommonMaterial1"] = { "+ crafts and upgrades tier 1 (Common) weapons, clothes and items" },
  ["Items.UncommonMaterial1"] = { "+ crafts and upgrades tier 2 (Uncommon) weapons, clothes and items" },
  ["Items.RareMaterial1"] = { "+ crafts and upgrades tier 3 (Rare) weapons, clothes and items" },
  ["Items.EpicMaterial1"] = { "+ crafts and upgrades tier 4 (Epic) weapons, clothes and items" },
  ["Items.LegendaryMaterial1"] = { "+ crafts and upgrades tier 5 (Legendary) weapons, clothes and items" },
  ["Items.QuickHackUncommonMaterial1"] = { "+ crafts tier 2 (Uncommon) quickhacks" },
  ["Items.QuickHackRareMaterial1"] = { "+ crafts tier 3 (Rare) quickhacks" },
  ["Items.QuickHackEpicMaterial1"] = { "+ crafts tier 4 (Epic) quickhacks" },
  ["Items.QuickHackLegendaryMaterial1"] = { "+ crafts tier 5 (Legendary) quickhacks" },
}   -- TIPS END
local REC_PREFIX = ""   -- item record = REC_PREFIX .. id

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
    ImGui.TextColored(1.0, 0.75, 0.3, 1.0, "Not in this game: the mod with this item is missing.")
  elseif it.grey and d and not d.greyOk then
    ImGui.TextColored(1.0, 0.75, 0.3, 1.0, "Grey-market desk: Street Cred " .. (d.greyCred or 0) .. "+ only.")
  end
  ImGui.PopTextWrapPos()
  ImGui.EndTooltip()
end

local DEST = { [0] = "Dealer locker", [1] = "Apartment drop" }

local function sys()
  local ok, s = pcall(function() return Game.GetScriptableSystemsContainer():Get("CyberslopPartsCourier.PartsCourier") end)
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

registerHotkey("CyberslopPartsCourierToggle", "Parts Courier: show / hide window", function()
  PC.pinned = not PC.pinned
  PC.nextFull = 0
end)

registerHotkey("CyberslopPartsCourierCollect", "Parts Courier: collect landed orders here", function()
  pollLight()
  if (PC.at or -1) < 0 then
    hud("Scrapline: no drop point here (a tech, junk, gun or armor dealer, or one of your places).")
    return
  end
  local res = doCollect()
  if res then hud(res) end
end)

registerForEvent("onInit", function()
  print("[CyberslopPartsCourier] " .. PC.version .. " loaded")
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
  local v, changed = ImGui.InputInt("##q" .. it.i, it.qty, 10, 100)
  if changed and type(v) == "number" then setQty(s, it, v) end
  ImGui.SameLine(COL_QUICK)
  for _, q in ipairs({ 50, 100, 250 }) do
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
  colored(GREY, string.format("Bulk rate per component: 25+ -5%%  50+ -10%%  100+ -15%%  250+ -20%%.   Street Cred %d: -%d%% on everything.",
    d.credLevel or 0, d.credPct or 0))
  colored(GREY, "Item (hover for effects)")
  ImGui.SameLine(COL_CARRIED) colored(GREY, "carried")
  ImGui.SameLine(COL_PRICE) colored(GREY, "list")
  ImGui.SameLine(COL_QTY) colored(GREY, "order")
  ImGui.SameLine(COL_LINE) colored(GREY, "price")
  if ImGui.BeginChild("##pccat", 0, 230, true) then
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
  if ImGui.RadioButton("Dealer locker##pcd0", PC.dest == 0) then PC.dest = 0; requote(s) end
  if ImGui.IsItemHovered() then
    ImGui.SetTooltip("Scrapline keeps lockers at tech, junk, gun and armor dealers all over the city.\nCollect at any of them. 150 per drone (200 units), lands in 2h 00m - 2h 30m game time.")
  end
  ImGui.SameLine()
  if ImGui.RadioButton("Apartment drop##pcd1", PC.dest == 1) then PC.dest = 1; requote(s) end
  if ImGui.IsItemHovered() then
    ImGui.SetTooltip("Residential drop box: collect at any of your places (near your stash).\n400 per drone (residential airspace permit), lands in 2h 30m - 3h 00m game time.")
  end
  if (d.units or 0) <= 0 then
    colored(GREY, "Cart empty. Set an amount on any line: one is fine, 50 / 100 / 250 or more of one component gets the bulk rate.")
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
    colored(GREEN, "Here: " .. (PC.atName or "dealer") .. ". Dealer locker orders can be collected.")
  elseif PC.at == 1 then
    colored(GREEN, "Here: your place. Apartment orders can be collected.")
  else
    colored(GREY, "No drop point here: stand at a tech, junk, gun or armor dealer (7 m) or in one of your places.")
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
        here and ", collect it here" or (o.dest == 1 and ", waiting at your place" or ", waiting in the dealer lockers")))
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
      if ImGui.Begin("Scrapline drop##partshint", ImGuiWindowFlags.AlwaysAutoResize + ImGuiWindowFlags.NoFocusOnAppearing + ImGuiWindowFlags.NoTitleBar) then
        colored(GREEN, string.format("Scrapline: %d %s ready here. Collect key or CET overlay.",
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
  if not ImGui.Begin("Scrapline Parts Exchange - drone freight", ImGuiWindowFlags.AlwaysAutoResize + ImGuiWindowFlags.NoFocusOnAppearing) then
    ImGui.End()
    return
  end
  if not s or not d or not PC.items then
    colored(AMBER, s and "Load a save first." or "Parts Courier script not running (r6\\scripts\\zz_CyberslopPartsCourier).")
    ImGui.End()
    return
  end
  colored(CYAN, "Salvage-grade to mil-spec components by the crate, dropped by drone.")
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
