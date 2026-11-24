-- HeadPopAnyone 1.3 by penicius-code
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
local DEBUG = false         -- Print targeting details to the CET console

local function log(msg)
    print("[HeadPopAnyone] " .. msg)
end

local function dbg(msg)
    if DEBUG then log(msg) end
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

registerHotkey("HeadPopAnyone_Pop", "Pop Head", function()
    local target = GetLookAtTarget()
    if not target then return end
    if SKIP_PROTECTED and IsProtected(target) then
        dbg("Target is protected (Immortal / Invulnerable), skipped")
        ShowMessage("Protected NPC. Head stays on.")
        return
    end
    PopHead(target)
end)

registerForEvent("onInit", function()
    log("Loaded 1.3. Bind 'Pop Head' in CET Bindings menu. Max range: " .. MAX_RANGE .. "m")
end)
