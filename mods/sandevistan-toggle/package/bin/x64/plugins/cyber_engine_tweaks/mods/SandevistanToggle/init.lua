-- Manual Sandevistan Toggle 1.2 by penicius-code (works in dialogues)
-- Place in: bin/x64/plugins/cyber_engine_tweaks/mods/SandevistanToggle/init.lua

local sandyKey = 'sandevistan' -- vanilla Sandevistan's time dilation reason
local dilation = 0.3           -- world speed while active (V stays at full speed)

-- Our own slow motion is on. The time system alone can't tell: vanilla's reason stays
-- registered while the ease out curve runs, and the real Sandevistan uses the same reason.
local active = false

registerForEvent('onInit', function()
    print("[SandevistanToggle] Loaded! Use Hotkey to toggle Sandevistan.")
end)

-- True while the real Sandevistan cyberware is running (its status effect is on V)
local function VanillaSandevistanRunning(player)
    local ok, res = pcall(function()
        return StatusEffectSystem.ObjectHasStatusEffectOfType(player, gamedataStatusEffectType.Sandevistan)
    end)
    return ok and res == true
end

-- Ends the real Sandevistan the vanilla way. Without its status effect the player state machine
-- leaves the Sandevistan state on the next frame (SandevistanDecisions.ToTimeDilationReady), so the
-- vanilla exit runs (cooldown, cleanup). This also stops cyberware mods that set the time dilation
-- again every tick, which unsetting the dilation alone can't (TDO's Apogee re-sets it every 0.05 s).
local function EndVanillaSandevistan(player)
    pcall(function()
        StatusEffectHelper.RemoveAllStatusEffectsByType(player, gamedataStatusEffectType.Sandevistan)
    end)
    if not VanillaSandevistanRunning(player) then return true end
    -- Fallback: remove the Sandevistan-type effects one by one.
    pcall(function()
        local ses = Game.GetStatusEffectSystem()
        local id = player:GetEntityID()
        local want = EnumInt(gamedataStatusEffectType.Sandevistan)
        for _, eff in ipairs(ses:GetAppliedEffects(id)) do
            local rec = eff:GetRecord()
            local typeRec = rec and rec:StatusEffectType()
            if typeRec and EnumInt(typeRec:Type()) == want then
                ses:RemoveStatusEffect(id, rec:GetID())
            end
        end
    end)
    return not VanillaSandevistanRunning(player)
end

registerHotkey("ToggleSandevistan", "Toggle Sandevistan On/Off", function()
    local player = Game.GetPlayer()
    if not player then return end

    local ts = Game.GetTimeSystem()

    if active and ts:IsTimeDilationActive(sandyKey) then
        ts:UnsetTimeDilation(sandyKey, 'SandevistanEaseOut')
        ts:SetIgnoreTimeDilationOnLocalPlayerZero(false)
        active = false
        print("[SandevistanToggle] Sandevistan DEACTIVATED")
    elseif VanillaSandevistanRunning(player) then
        -- The real Sandevistan is running: the key switches it off, as it always did.
        local ended = EndVanillaSandevistan(player)
        if ts:IsTimeDilationActive(sandyKey) then
            ts:UnsetTimeDilation(sandyKey, 'SandevistanEaseOut')
        end
        ts:SetIgnoreTimeDilationOnLocalPlayerZero(false)
        active = false
        print("[SandevistanToggle] Vanilla Sandevistan DEACTIVATED" .. (ended and "" or " (status effect still on)"))
    else
        -- Other dilations (Kerenzikov, focus mode, other mods) are left alone. If our own
        -- ease out is still running, restart cleanly like vanilla does (unset, then set).
        if ts:IsTimeDilationActive(sandyKey) then
            ts:UnsetTimeDilation(sandyKey)
        end
        ts:SetTimeDilation(sandyKey, dilation)
        ts:SetIgnoreTimeDilationOnLocalPlayerZero(true)
        active = true
        print("[SandevistanToggle] Sandevistan ACTIVATED")
    end
end)
