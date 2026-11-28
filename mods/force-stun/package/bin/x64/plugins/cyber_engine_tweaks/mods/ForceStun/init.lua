-- ForceStun 1.2.4
-- Apply ActualStun to crosshair target via hotkey
-- Works with Gorilla Arms equipped - no weapon swap needed.
-- Pipeline: ForceStun → ActualStun on NPC → Grapple prompt appears → SavageSlingAlways → Throw
-- ActualStun comes from Buttslinger Quickmelee (Nexus 10556). Without it ForceStun
-- applies the vanilla stun instead (no grapple prompt).
-- 1.2: the shock add-on (r6\scripts\ForceStun\ForceStunShock.reds + r6\tweaks\ForceStun\ForceStunShock.yaml)
-- applies the stun with the Mod Settings duration, silent shock damage (a would-be kill becomes an Unconscious
-- knockout) and the electrified look; 1.2.1: RAM cost. Settings: Mod Settings > ForceStun. Without the add-on this file falls back
-- to the 1.1 behaviour.
-- Place in: bin/x64/plugins/cyber_engine_tweaks/mods/ForceStun/init.lua

local settings = {
    maxRange = 15.0,  -- max targeting range in meters
    maxAngle = 8.0,   -- max degrees between crosshair and target when no NPC is directly under it
}

local warnedNoButtslinger = false
local warnedNoShock = false

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

-- Living, conscious NPC (not dead, defeated or knocked out)
local function IsStunnable(entity)
    local ok, res = pcall(function()
        return entity:IsNPC() and ScriptedPuppet.IsActive(entity)
    end)
    return ok and res == true
end

-- Degrees between the crosshair and a target part (the larger of pitch and yaw)
local function PartAngle(part)
    local ok, angles = pcall(function() return part:GetPlayerAngleDistance() end)
    if not ok or not angles then return nil end
    return math.max(math.abs(angles.pitch), math.abs(angles.yaw))
end

-- The NPC under the crosshair, or else the NPC closest to it within maxAngle degrees.
-- Second result: true when the NPC under the crosshair is down or inactive (can't be stunned).
local function GetCrosshairNPC(player)
    local targetingSystem = Game.GetTargetingSystem()
    local downUnderCrosshair = false

    local ok, lookAt = pcall(function()
        return targetingSystem:GetLookAtObject(player, false, false)
    end)
    if ok and lookAt and Distance(player, lookAt) <= settings.maxRange then
        if IsStunnable(lookAt) then
            return lookAt, false
        end
        downUnderCrosshair = IsNPC(lookAt)
    end

    local best, bestAngle = nil, settings.maxAngle
    local ok2, success, parts = pcall(function()
        local searchQuery = TSQ_NPC()
        searchQuery.maxDistance = settings.maxRange
        return targetingSystem:GetTargetParts(player, searchQuery)
    end)
    if ok2 and success and parts then
        for _, part in ipairs(parts) do
            local okEntity, entity = pcall(function() return part:GetComponent():GetEntity() end)
            if okEntity and entity and IsStunnable(entity) then
                local angle = PartAngle(part)
                if angle and angle <= bestAngle then
                    best, bestAngle = entity, angle
                end
            end
        end
    end
    return best, downUnderCrosshair
end

local function HasRecord(path)
    local ok, record = pcall(function() return TweakDB:GetRecord(path) end)
    return ok and record ~= nil
end

-- The redscript shock system, or nil when the add-on is not installed.
local function GetShockSystem()
    local ok, sys = pcall(function()
        return Game.GetScriptableSystemsContainer():Get('ForceStunShockSystem')
    end)
    if ok and sys then return sys end
    return nil
end

local shockMessages = {
    stun = "[ForceStun] Target stunned and shocked! Grab them (F) for Savage Sling.",
    vanilla = "[ForceStun] Target stunned (vanilla stun) and shocked.",
    ko = "[ForceStun] The shock knocked the target out.",
    immune = "[ForceStun] Target is stun-immune right now (just stunned): nothing done, no RAM used.",
}

-- 1.1 behaviour, used when the shock add-on is missing
local function PlainStun(target)
    local ses = Game.GetStatusEffectSystem()
    local targetID = target:GetEntityID()

    if HasRecord("BaseStatusEffect.ActualStun") then
        -- Apply the Buttslinger_Opening which chains into ActualStun
        ses:ApplyStatusEffect(targetID, TweakDBID.new('BaseStatusEffect.Buttslinger_Opening'))

        -- Also apply ActualStun directly as fallback
        ses:ApplyStatusEffect(targetID, TweakDBID.new('BaseStatusEffect.ActualStun'))

        print("[ForceStun] Target stunned! Grab them (F) for Savage Sling.")
    else
        -- Buttslinger Quickmelee not installed: vanilla stun
        ses:ApplyStatusEffect(targetID, TweakDBID.new('BaseStatusEffect.Stun'))
        if not warnedNoButtslinger then
            warnedNoButtslinger = true
            print("[ForceStun] Buttslinger Quickmelee not found, using the vanilla stun. Install it for the grab prompt.")
        end
        print("[ForceStun] Target stunned (vanilla stun).")
    end
end

registerForEvent('onInit', function()
    print("[ForceStun] Loaded! Use hotkey to stun targeted NPC.")
end)

-- 1.2.4: registerInput instead of registerHotkey: a CET hotkey only fires when no other key is held, so it never
-- fired while walking (W) or zoomed (right mouse). Same id, so the existing binding (F3) stays. Fires on key down.
registerInput("ForceStunTarget", "Force Stun Target (for Savage Sling)", function(isDown)
    if not isDown then return end
    local player = Game.GetPlayer()
    if not player then return end

    -- Get the NPC in crosshair
    local target, downUnderCrosshair = GetCrosshairNPC(player)
    if not target then
        if downUnderCrosshair then
            print("[ForceStun] The NPC under the crosshair is down or inactive, can't be stunned")
        else
            print("[ForceStun] No NPC in crosshair")
        end
        return
    end

    local sys = GetShockSystem()
    if sys then
        local ok, res = pcall(function() return sys:Shock(target) end)
        if ok and shockMessages[res] then
            print(shockMessages[res])
            return
        end
        local cost, have = nil, nil
        if ok and type(res) == "string" then cost, have = res:match("^noram:(%d+):(%d+)$") end
        if cost then
            print("[ForceStun] Not enough RAM (" .. have .. " / " .. cost .. ")")
            return
        end
        if ok and res == "none" then
            print("[ForceStun] The target can't be stunned")
            return
        end
        print("[ForceStun] Shock add-on call failed (" .. tostring(res) .. "), using the plain stun")
    elseif not warnedNoShock then
        warnedNoShock = true
        print("[ForceStun] Shock add-on (r6\\scripts\\ForceStun) not loaded, using the plain stun")
    end
    PlainStun(target)
end)
