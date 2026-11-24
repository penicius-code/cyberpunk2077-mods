-- AutoDropWeaponOnPickupEquip 1.1.1 (CET - no registerHotkey required) by penicius-code
-- Automatically drops the weapon you were holding when you pick up & equip a ground weapon (R on it).
-- Works by watching the inventory (PlayerPuppet:OnItemAddedToInventory): when the weapon in your
-- hands changes to one that entered the inventory a moment ago, the weapon you held before is
-- dropped through the game's own Drop item action once it is back in the inventory.
-- A reload or a normal weapon switch never drops anything: the new weapon was already yours.
-- Only a weapon that really lost its weapon slot is dropped: with a free slot the game puts the
-- new weapon there and keeps the old one equipped, so nothing drops. A holstered weapon is kept too.
-- Fists and cyberware arms (Gorilla Arms, Mantis Blades, Monowire, Projectile Launcher) are never dropped.

local cfg = {
  pickupWindow = 1.0,   -- seconds between a weapon entering the inventory and it being in your hands
  dropDelay  = 0.10,    -- small delay to let the TransactionSystem update after the equip
  dropTimeout = 2.0,    -- give up if the old weapon doesn't come back to the inventory in time
  graceAfterLoad = 5.0, -- ignore inventory adds right after a load (the game re-adds your items then)
  dropHolstered = false, -- true = also drop a holstered weapon the pickup pushed out of its slot
  protectQuestItems = true,
  protectIconics = true,
  debugPrint = false,
}

local t = 0.0
local graceUntil = 0.0

-- Weapons that entered the inventory recently: item key -> time added.
-- Only a swap to one of these counts as "picked up and equipped".
local recentAdds = {}

-- The last weapon that was really in the hands (empty hands during a swap are skipped)
local lastID, lastKey = nil, nil

-- Time the hands were first seen empty (holstered or mid-swap), nil while a weapon is held
local emptySince = nil

-- Drop in progress: { oldID, oldKey, dropAt, deadline }
local pending = nil

local equipCheckFailed = false

local function log(msg)
  print("[AutoDropWeaponOnPickupEquip] " .. msg)
end

local function dbg(msg)
  if cfg.debugPrint then log(msg) end
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

local function getActiveWeaponItemID(player)
  if not player then return nil end
  local w = player:GetActiveWeapon()
  if not w then return nil end
  return w:GetItemID()
end

-- Fists and cyberware arms are never dropped
local function isUndroppableWeapon(itemID)
  if not itemID then return true end
  local okFists, fists = pcall(function() return WeaponObject.IsFists(itemID) end)
  if okFists and fists then return true end
  local okCw, cyberware = pcall(function() return WeaponObject.IsCyberwareWeapon(itemID) end)
  return okCw and cyberware == true
end

-- Still in one of the weapon slots? Then the pickup went into a free slot and the old weapon stays.
-- If the check itself fails, the weapon is treated as equipped (better kept than wrongly dropped).
local function isStillEquipped(player, itemID)
  local ok, equipped = pcall(function() return RPGManager.IsItemEquipped(player, itemID) end)
  if not ok then
    if not equipCheckFailed then
      equipCheckFailed = true
      log("Equip check failed, nothing will be dropped: " .. tostring(equipped))
    end
    return true
  end
  return equipped == true
end

local function resetAfterLoad()
  graceUntil = t + cfg.graceAfterLoad
  recentAdds = {}
  lastID, lastKey = nil, nil
  emptySince = nil
  pending = nil
end

-- Optional: toggle debug prints (bind in CET -> Bindings -> Inputs)
registerInput("ADWOP_ToggleDebug", "ADWOP: Toggle debug logging", function(isDown)
  if not isDown then return end
  cfg.debugPrint = not cfg.debugPrint
  log("debugPrint = " .. tostring(cfg.debugPrint))
end)

registerForEvent("onInit", function()
  resetAfterLoad()

  Observe("PlayerPuppet", "OnGameAttached", function()
    resetAfterLoad()
    dbg("Player attached, inventory adds ignored for " .. cfg.graceAfterLoad .. " s")
  end)

  Observe("PlayerPuppet", "OnItemAddedToInventory", function(_, evt)
    if not evt then return end
    if t < graceUntil then return end
    local ok, isWeapon = pcall(function()
      return RPGManager.GetItemCategory(evt.itemID) == gamedataItemCategory.Weapon
    end)
    if ok and isWeapon then
      recentAdds[itemKey(evt.itemID)] = t
      dbg("Weapon added to inventory: " .. tostring(itemKey(evt.itemID)))
    end
  end)

  log("Loaded. Drops the weapon you held when you pick up and equip a ground weapon.")
end)

-- Idle check: with no pickup in flight only the held-weapon baseline is tracked, at 4 Hz
local tickfixIdleAcc = 0
registerForEvent("onUpdate", function(dt)
  t = t + (dt or 0)
  if not pending and next(recentAdds) == nil then
    tickfixIdleAcc = tickfixIdleAcc + (dt or 0)
    if tickfixIdleAcc < 0.25 then return end
  end
  tickfixIdleAcc = 0

  -- forget old pickups now and then
  for k, added in pairs(recentAdds) do
    if t - added > cfg.pickupWindow + 5.0 then recentAdds[k] = nil end
  end

  local player = GetPlayer()
  if not player then return end

  local newID = getActiveWeaponItemID(player)
  local newKey = itemKey(newID)

  if not newKey then
    if not emptySince then emptySince = t end
  end

  -- Weapon in the hands changed (empty hands in between are ignored)
  if newKey and newKey ~= lastKey then
    local added = recentAdds[newKey]
    if lastID and added and t - added <= cfg.pickupWindow and not pending then
      if isUndroppableWeapon(lastID) then
        dbg("Previous weapon is fists or cyberware, kept")
      elseif emptySince and emptySince < added and not cfg.dropHolstered then
        -- hands were already empty before the pickup: the old weapon was holstered, not held
        dbg("Previous weapon was holstered, kept")
      else
        pending = { oldID = lastID, oldKey = lastKey, dropAt = t + cfg.dropDelay, deadline = t + cfg.dropTimeout }
        dbg("Picked up and equipped " .. newKey .. ", dropping " .. lastKey .. " if it lost its slot")
      end
      recentAdds[newKey] = nil
    end
    lastID, lastKey = newID, newKey
  end
  if newKey then emptySince = nil end

  if not pending then return end
  if t < pending.dropAt then return end
  if t > pending.deadline then
    dbg("Old weapon never came back to the inventory, nothing dropped")
    pending = nil
    return
  end

  -- The pickup took a free weapon slot: the old weapon is still equipped, keep it
  if isStillEquipped(player, pending.oldID) then
    dbg("Old weapon is still in a weapon slot (pickup took a free slot), kept")
    pending = nil
    return
  end

  -- Ensure old weapon is now in inventory before dropping
  local ts = Game.GetTransactionSystem()
  if ts then
    local qty = ts:GetItemQuantity(player, pending.oldID) or 0
    if qty <= 0 then
      pending.dropAt = t + 0.08
      return
    end

    local itemData = ts:GetItemData(player, pending.oldID)
    if cfg.protectQuestItems and (hasTag(itemData, "Quest") or hasTag(itemData, "UnequipBlocked")) then
      dbg("Old weapon is a quest item, kept")
      pending = nil
      return
    end
    if cfg.protectIconics and itemData and isIconic(itemData) then
      dbg("Old weapon is iconic, kept")
      pending = nil
      return
    end
    if itemData then
      local okCan, can = pcall(function() return RPGManager.CanItemBeDropped(player, itemData) end)
      if okCan and can == false then
        dbg("The game doesn't allow dropping the old weapon, kept")
        pending = nil
        return
      end
    end
  end

  -- Drop old weapon into the world (vanilla's Drop item action)
  local oldID = pending.oldID
  pending = nil
  local ok, err = pcall(function()
    ItemActionsHelper.DropItem(player, oldID)
  end)
  if ok then
    dbg("Dropped the old weapon")
  else
    log("Drop failed: " .. tostring(err))
  end
end)
