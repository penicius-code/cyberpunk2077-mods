-- GrappleTools: Corpse Throw 1.1 by penicius-code
-- Hotkey: the body under the crosshair goes on V's shoulder, ready for a Savage Sling throw.
-- Place in: bin/x64/plugins/cyber_engine_tweaks/mods/GrappleTools/init.lua

local settings = {
    corpseRange = 5.0,
    maxAngle = 15.0,           -- max degrees between crosshair and body when no body is directly under it
    includeUnconscious = true, -- also pick up NPCs that are down but alive (knocked out or defeated), not only dead ones
}

local function Distance(a, b)
    local pa = a:GetWorldPosition()
    local pb = b:GetWorldPosition()
    local dx, dy, dz = pa.x - pb.x, pa.y - pb.y, pa.z - pb.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local warnedDefeatedCheck = false

-- True only when fn runs without an error and returns true
local function Try(fn)
    local ok, res = pcall(fn)
    return ok and res == true
end

-- Vanilla Defeated status: beaten to 0 HP without dying. DefeatedWithRecover (fist fight
-- opponents, they get back up) is a different type and stays out. Says once if the check fails.
local function HasDefeatedState(entity)
    local ok, res = pcall(function()
        return StatusEffectSystem.ObjectHasStatusEffectOfType(entity, gamedataStatusEffectType.Defeated)
    end)
    if not ok and not warnedDefeatedCheck then
        warnedDefeatedCheck = true
        print("[GrappleTools] Defeated check failed, downed NPCs are skipped: " .. tostring(res))
    end
    return ok and res == true
end

-- The throw kills a living body. Reason to leave a defeated NPC alone, or nil:
-- bosses go down before their quest scene, Immortal / Invulnerable NPCs are companions and
-- quest characters, passengers of a stopped car still sit in their seat. An API error never blocks.
local function DefeatedBlocker(entity)
    if Try(function() return ScriptedPuppet.IsBoss(entity) end) then return "is a boss" end
    if Try(function()
        local godMode = Game.GetGodModeSystem()
        local id = entity:GetEntityID()
        return godMode:HasGodMode(id, gameGodModeType.Immortal) or godMode:HasGodMode(id, gameGodModeType.Invulnerable)
    end) then
        return "is protected by the game (quest character)"
    end
    if Try(function() return VehicleComponent.IsMountedToVehicle(entity) end) then return "still sits in a vehicle" end
    return nil
end

-- Dead NPC, or with includeUnconscious an NPC that is down but alive (knocked out or defeated).
-- Second result: why a defeated NPC was left alone.
local function CheckBody(entity)
    if not Try(function() return entity:IsNPC() end) then return false end
    if Try(function() return entity:IsDead() end) then return true end
    if not settings.includeUnconscious then return false end
    if Try(function() return ScriptedPuppet.IsUnconscious(entity) end) then return true end
    if not HasDefeatedState(entity) then return false end
    local reason = DefeatedBlocker(entity)
    return reason == nil, reason
end

-- Degrees between the crosshair and a target part (the larger of pitch and yaw)
local function PartAngle(part)
    local ok, angles = pcall(function() return part:GetPlayerAngleDistance() end)
    if not ok or not angles then return nil end
    return math.max(math.abs(angles.pitch), math.abs(angles.yaw))
end

-- The body under the crosshair, or else the body closest to it within maxAngle degrees.
-- Also returns how many target parts the targeting system listed, how many of them were bodies,
-- and why the defeated NPC V aimed at was left alone (under the crosshair, else closest to it).
local function GetCrosshairBody(player)
    local targetingSystem = Game.GetTargetingSystem()
    local skipReason, skipAngle = nil, settings.maxAngle

    local ok, lookAt = pcall(function()
        return targetingSystem:GetLookAtObject(player, false, false)
    end)
    if ok and lookAt then
        local isBody, reason = CheckBody(lookAt)
        if (isBody or reason) and Distance(player, lookAt) <= settings.corpseRange then
            if isBody then return lookAt, 1, 1 end
            skipReason, skipAngle = reason, -1
        end
    end

    local best, bestAngle, partCount, bodyCount = nil, settings.maxAngle, 0, 0
    local ok2, success, parts = pcall(function()
        local searchQuery = TSQ_ALL()
        searchQuery.maxDistance = settings.corpseRange
        return targetingSystem:GetTargetParts(player, searchQuery)
    end)
    if ok2 and success and parts then
        for _, part in ipairs(parts) do
            partCount = partCount + 1
            local okEntity, entity = pcall(function() return part:GetComponent():GetEntity() end)
            if okEntity and entity then
                local isBody, reason = CheckBody(entity)
                if isBody or reason then
                    local angle = PartAngle(part)
                    local inRange = angle and Distance(player, entity) <= settings.corpseRange
                    if isBody then
                        bodyCount = bodyCount + 1
                        if inRange and angle <= bestAngle then
                            best, bestAngle = entity, angle
                        end
                    elseif inRange and angle <= skipAngle then
                        skipReason, skipAngle = reason, angle
                    end
                end
            end
        end
    end
    return best, partCount, bodyCount, skipReason
end

-- Reason V can't pick up a body right now, or nil
local function CarryBlocker(player)
    local ok, reason = pcall(function()
        local defs = Game.GetAllBlackboardDefs()
        local psm = Game.GetBlackboardSystem():GetLocalInstanced(player:GetEntityID(), defs.PlayerStateMachine)
        if psm then
            if psm:GetBool(defs.PlayerStateMachine.Carrying) then return "already carrying a body" end
            if psm:GetInt(defs.PlayerStateMachine.Vehicle) ~= 0 then return "in a vehicle" end
        end
        if Game.GetWorkspotSystem():IsActorInWorkspot(player) then return "in a scene" end
        return nil
    end)
    if not ok then return nil end -- don't block on an API error
    return reason
end

registerForEvent('onInit', function()
    print("[GrappleTools] Loaded! Use hotkey to Savage Sling a dead NPC.")
end)

registerHotkey("CorpseThrow", "Corpse Throw (Savage Sling Dead NPC)", function()
    local player = Game.GetPlayer()
    if not player then return end

    local blocker = CarryBlocker(player)
    if blocker then
        print("[GrappleTools] Can't pick up a body: " .. blocker)
        return
    end

    local npc, partCount, bodyCount, skipReason = GetCrosshairBody(player)
    if not npc then
        if skipReason then
            print("[GrappleTools] Not picked up: the downed NPC you aimed at " .. skipReason)
        elseif partCount > 0 then
            -- The counts tell whether the targeting system lists bodies at all
            print(string.format("[GrappleTools] No corpse found in crosshair (%d targets within %.0f m, %d of them bodies)",
                partCount, settings.corpseRange, bodyCount))
        else
            print("[GrappleTools] No target in range")
        end
        return
    end

    local playerID = player:GetEntityID()
    local npcID = npc:GetEntityID()

    local ses = Game.GetStatusEffectSystem()
    ses:ApplyStatusEffect(npcID, TweakDBID.new('BaseStatusEffect.ThrownNPC'))

    local mountingEvent = MountingRequest.new()
    local slotId = MountingSlotId.new()
    slotId.id = 'leftShoulder'

    local mountInfo = MountingInfo.new()
    mountInfo.childId = npcID
    mountInfo.parentId = playerID
    mountInfo.slotId = slotId

    mountingEvent.lowLevelMountingInfo = mountInfo
    mountingEvent.preservePositionAfterMounting = false

    Game.GetMountingFacility():Mount(mountingEvent)

    print("[GrappleTools] Corpse mounted for throw!")
end)
