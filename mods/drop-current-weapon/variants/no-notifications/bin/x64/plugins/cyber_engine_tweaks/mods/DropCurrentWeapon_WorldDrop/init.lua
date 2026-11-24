-- DropCurrentWeapon_WorldDrop 1.1.0, No Notifications file (CET) by penicius-code
-- Drops the currently equipped weapon into the world (you can pick it back up).
-- Fists and cyberware arms (Gorilla Arms, Mantis Blades, Monowire, Projectile Launcher) are never dropped.
--
-- How it works: the weapon is unequipped first (the game never drops an item that is still in
-- your hands), then dropped through the game's own Drop item action, the one the inventory uses.

-- ======================
-- Config
-- ======================
local cfg = {
  protectQuestItems = true, -- Never drop quest items or weapons the game locks in your hands.
  protectIconics = true,    -- Never drop iconic weapons (vanilla doesn't let you drop them either).
  notify = false,           -- Show a small on-screen notification (off in this file).
  debug = false,            -- Print extra debug info to the CET console.
  dropDelay = 0.15,         -- Seconds between the weapon leaving your hands and the drop.
  unequipTimeout = 2.0,     -- Give up if the weapon is still in your hands after this many seconds.
}

local MOD_NAME = "DropCurrentWeapon_WorldDrop"

local t = 0.0
local pendingDrop = nil -- { itemID, key, deadline, dropAt }

local function dbg(msg)
  if cfg.debug then
    print(("[%s] %s"):format(MOD_NAME, msg))
  end
end

local function notify(msg)
  if not cfg.notify then return end

  pcall(function()
    local warningMsg = SimpleScreenMessage.new()
    warningMsg.isShown = true
    warningMsg.duration = 2.0
    warningMsg.message = tostring(msg)
    warningMsg.isInstant = true
    local defs = Game.GetAllBlackboardDefs()
    Game.GetBlackboardSystem():Get(defs.UI_Notifications):SetVariant(defs.UI_Notifications.WarningMessage, ToVariant(warningMsg), true)
  end)
end

local function itemKey(itemID)
  return itemID and tostring(itemID) or nil
end

local function hasTag(itemData, tag)
  if not itemData then return false end
  local ok, res = pcall(function() return itemData:HasTag(tag) end)
  return ok and res == true
end

local function isIconic(itemData)
  if hasTag(itemData, "IconicWeapon") then return true end
  local ok, value = pcall(function() return itemData:GetStatValueByType(gamedataStatType.IsItemIconic) end)
  return ok and type(value) == "number" and value > 0
end

-- Returns why the weapon must stay in your hands, or nil if it can be dropped.
local function dropBlockReason(player, itemID)
  local okFists, fists = pcall(function() return WeaponObject.IsFists(itemID) end)
  if okFists and fists then return "Fists can't be dropped." end

  local okCw, cyberware = pcall(function() return WeaponObject.IsCyberwareWeapon(itemID) end)
  if okCw and cyberware then return "Cyberware can't be dropped." end

  local okData, itemData = pcall(function() return Game.GetTransactionSystem():GetItemData(player, itemID) end)
  if not okData then itemData = nil end
  if cfg.protectQuestItems and (hasTag(itemData, "Quest") or hasTag(itemData, "UnequipBlocked")) then
    return "Can't drop: quest item."
  end
  if cfg.protectIconics and itemData and isIconic(itemData) then
    return "Can't drop: iconic weapon."
  end
  -- The game's own rule (no Drop action on the item, a consumable in use, ...)
  if itemData then
    local okCan, can = pcall(function() return RPGManager.CanItemBeDropped(player, itemData) end)
    if okCan and can == false then
      return "Can't drop: the game doesn't allow dropping this item."
    end
  end
  return nil
end

-- Asks the equipment system to unequip (holster) the weapon. Returns true when the request went out.
local function requestUnequip(player, itemID)
  local ok, err = pcall(function()
    local slot = EquipmentSystem.GetData(player):GetSlotIndex(itemID)
    if slot < 0 then error("the weapon is not in a weapon slot") end
    local req = UnequipRequest.new()
    req.owner = player
    req.areaType = gamedataEquipmentArea.Weapon
    req.slotIndex = slot
    req.force = false
    Game.GetScriptableSystemsContainer():Get("EquipmentSystem"):QueueRequest(req)
    dbg("Unequip requested for weapon slot " .. tostring(slot))
  end)
  if not ok then
    print(("[%s] Unequip failed: %s"):format(MOD_NAME, tostring(err)))
  end
  return ok
end

-- Vanilla's Drop item action (what the inventory's "Drop" does).
local function dropToWorld(player, itemID)
  local ok, err = pcall(function()
    ItemActionsHelper.DropItem(player, itemID)
  end)
  if ok then
    notify("Dropped current weapon.")
    dbg("Dropped the weapon to the world.")
  else
    notify("Drop failed (see CET console).")
    print(("[%s] Drop failed: %s"):format(MOD_NAME, tostring(err)))
  end
end

local function activeWeaponID(player)
  local weapon = player:GetActiveWeapon()
  if not weapon then return nil end
  return weapon:GetItemID()
end

local function dropCurrentWeaponToWorld()
  local player = GetPlayer()
  if not player then
    dbg("No player.")
    return
  end

  if pendingDrop then
    dbg("A drop is already in progress.")
    return
  end

  local itemID = activeWeaponID(player)
  if not itemID then
    notify("No active weapon equipped.")
    dbg("No active weapon equipped.")
    return
  end

  local reason = dropBlockReason(player, itemID)
  if reason then
    notify(reason)
    dbg("Refusing: " .. reason)
    return
  end

  if not requestUnequip(player, itemID) then
    notify("Drop failed (see CET console).")
    return
  end
  pendingDrop = { itemID = itemID, key = itemKey(itemID), deadline = t + cfg.unequipTimeout, dropAt = nil }
end

registerForEvent("onUpdate", function(dt)
  t = t + (dt or 0)
  if not pendingDrop then return end

  local player = GetPlayer()
  if not player then return end

  local current = itemKey(activeWeaponID(player))
  if current == pendingDrop.key then
    -- still in the hands (holster animation running)
    if t > pendingDrop.deadline then
      notify("Drop failed: couldn't unequip the weapon.")
      dbg("Unequip timed out.")
      pendingDrop = nil
    end
    return
  end

  if not pendingDrop.dropAt then
    pendingDrop.dropAt = t + cfg.dropDelay
    return
  end
  if t < pendingDrop.dropAt then return end

  local okQty, qty = pcall(function() return Game.GetTransactionSystem():GetItemQuantity(player, pendingDrop.itemID) end)
  if okQty and (qty or 0) <= 0 then
    if t > pendingDrop.deadline then
      notify("Drop failed: the weapon left the inventory.")
      dbg("Weapon not in the inventory after the unequip.")
      pendingDrop = nil
    end
    return
  end

  local itemID = pendingDrop.itemID
  pendingDrop = nil
  dropToWorld(player, itemID)
end)

registerHotkey(
  "DropCurrentWeapon_WorldDrop",
  "Drop currently equipped weapon to the ground (world)",
  dropCurrentWeaponToWorld
)

dbg("Loaded. Bind the hotkey in CET -> Bindings -> Hotkeys.")
