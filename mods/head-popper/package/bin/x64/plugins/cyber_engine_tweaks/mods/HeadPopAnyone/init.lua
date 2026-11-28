-- HeadPopAnyone 1.4.1 (1.4.1: Mod Settings > Head Popper > Debug log replaces DEBUG; 1.4: hold the key HOLD_SECONDS to pop; flat RAM cost from Mod Settings)
-- Trigger the Head Popper dismemberment effect on any NPC you're looking at.
-- Works on alive, unconscious, defeated, and dead enemies.
-- Install: Drop HeadPopAnyone folder into bin/x64/plugins/cyber_engine_tweaks/mods/
--
-- Hotkey is rebindable via CET's Bindings menu (default: unbound — set it there).
-- Aim at the target: the NPC under the crosshair is used, or else the NPC
-- closest to the crosshair within MAX_ANGLE degrees.

local MAX_RANGE = 15.0      -- Maximum targeting range in meters
local MAX_ANGLE = 6.0       -- Max degrees between crosshair and target when no NPC is directly under it
local SKIP_PROTECTED = true -- Leave NPCs the game keeps alive alone (Immortal / Invulnerable, e.g. quest characters)
local HOLD_SECONDS = 3.0    -- Key must be held this long before the pop fires

local function log(msg)
    print("[HeadPopAnyone] " .. msg)
end

-- 1.4.1: Mod Settings > Head Popper > Debug > Debug log (redscript getter; CET reads system fields as nil)
local function dbg(msg)
    local ok, on = pcall(function() return HeadPopHelper.LogOn() end)
    if ok and on then
        log(msg)
        spdlog.info("[HeadPopAnyone] " .. msg)
    end
end

local function Distance(a, b)
    local pa = a:GetWorldPosition()
    local pb = b:GetWorldPosition()
    local dx, dy, dz = pa.x - pb.x, pa.y - pb.y, pa.z - pb.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function IsNPC(entity)
    local ok, res = pcall(function() return entity:IsNPC() end)
    return ok and res == true
end

-- Degrees between the crosshair and a target part (the larger of pitch and yaw,
-- the same measure vanilla uses for its withinAngle checks).
local function PartAngle(part)
    local ok, angles = pcall(function() return part:GetPlayerAngleDistance() end)
    if not ok or not angles then return nil end
    return math.max(math.abs(angles.pitch), math.abs(angles.yaw))
end

local function GetLookAtTarget()
    local player = Game.GetPlayer()
    if not player then return nil end
    local targeting = Game.GetTargetingSystem()

    -- 1. The NPC directly under the crosshair
    local ok, result = pcall(function()
        return targeting:GetLookAtObject(player, false, false)
    end)
    if ok and result and IsNPC(result) then
        local dist = Distance(player, result)
        if dist <= MAX_RANGE then
            dbg(string.format("Target under the crosshair at %.1fm", dist))
            return result
        end
        dbg(string.format("Target under the crosshair too far: %.1fm", dist))
    end

    -- 2. The NPC closest to the crosshair, within MAX_ANGLE degrees
    local best, bestAngle = nil, MAX_ANGLE
    local ok2, success, parts = pcall(function()
        local searchQuery = TSQ_ALL()
        searchQuery.maxDistance = MAX_RANGE
        return targeting:GetTargetParts(player, searchQuery)
    end)
    if ok2 and success and parts then
        for _, part in ipairs(parts) do
            local okEntity, entity = pcall(function() return part:GetComponent():GetEntity() end)
            if okEntity and entity and IsNPC(entity) then
                local angle = PartAngle(part)
                if angle and angle <= bestAngle and Distance(player, entity) <= MAX_RANGE then
                    best, bestAngle = entity, angle
                end
            end
        end
    end
    if best then
        dbg(string.format("Target %.1f deg from the crosshair", bestAngle))
        return best
    end

    dbg("No NPC under the crosshair within " .. MAX_RANGE .. "m")
    return nil
end

local function IsProtected(target)
    local ok, res = pcall(function()
        local godMode = Game.GetGodModeSystem()
        local id = target:GetEntityID()
        return godMode:HasGodMode(id, gameGodModeType.Immortal) or godMode:HasGodMode(id, gameGodModeType.Invulnerable)
    end)
    return ok and res == true
end

local function ShowMessage(text)
    pcall(function()
        local warningMsg = SimpleScreenMessage.new()
        warningMsg.isShown = true
        warningMsg.duration = 1.5
        warningMsg.message = text
        warningMsg.isInstant = true
        Game.GetBlackboardSystem():Get(Game.GetAllBlackboardDefs().UI_Notifications):SetVariant(
            Game.GetAllBlackboardDefs().UI_Notifications.WarningMessage,
            ToVariant(warningMsg), true
        )
    end)
end

local function PopHead(target)
    if not target then return end

    dbg("Attempting head pop via REDscript helper...")

    local ok, err = pcall(function()
        local success = HeadPopHelper.PopHead(target)
        dbg("HeadPopHelper returned: " .. tostring(success))
    end)
    if not ok then
        log("Error calling HeadPopHelper: " .. tostring(err))
        return
    end

    ShowMessage("Head Popped.")
end

local function TryPop()
    local target = GetLookAtTarget()
    if not target then return end
    if SKIP_PROTECTED and IsProtected(target) then
        dbg("Target is protected (Immortal / Invulnerable), skipped")
        ShowMessage("Protected NPC. Head stays on.")
        return
    end
    -- 1.4: flat RAM cost (Mod Settings > Head Popper > RAM cost, default 20), paid in HeadPopAnyone.reds
    local okPay, paid = pcall(function() return HeadPopHelper.PayRam() end)
    if not okPay then
        log("Error calling HeadPopHelper.PayRam: " .. tostring(paid))
        return
    end
    if not paid then
        dbg("Not enough RAM, no pop")
        local okCost, cost = pcall(function() return HeadPopHelper.RamCost() end)
        ShowMessage("Not enough RAM (" .. (okCost and tostring(cost) or "?") .. " needed).")
        return
    end
    PopHead(target)
end

-- 1.4: the key must be held for HOLD_SECONDS; letting go earlier cancels.
-- The target is picked when the hold completes (aim at it at that moment).
local holding = false
local held = 0.0
local fired = false

registerInput("HeadPopAnyone_Pop", "Pop Head (hold " .. HOLD_SECONDS .. " s)", function(isDown)
    if isDown then
        if not holding then
            holding, held, fired = true, 0.0, false
            dbg("Key down, hold started")
        end
    else
        if holding and not fired then dbg(string.format("Key up after %.2f s, cancelled", held)) end
        holding, held, fired = false, 0.0, false
    end
end)

-- The key-up can be lost when the CET overlay opens mid-hold; drop the hold so it can't fire later on its own.
registerForEvent("onOverlayOpen", function()
    if holding and not fired then dbg("Overlay opened, hold dropped") end
    holding, held, fired = false, 0.0, false
end)

registerForEvent("onUpdate", function(dt)
    if not holding or fired then return end
    held = held + (dt or 0)
    if held >= HOLD_SECONDS then
        fired = true -- once per press
        dbg("Hold complete, trying a pop")
        TryPop()
    end
end)

registerForEvent("onInit", function()
    log("Loaded 1.4.1. Hold 'Pop Head' " .. HOLD_SECONDS .. " s (CET Bindings). Max range: " .. MAX_RANGE .. "m")
end)
