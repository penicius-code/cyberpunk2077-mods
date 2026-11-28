-- Cyberslop Vehicle Actions 1.8.0 (2026-11-26; 1.7.1 same day); built on 1.1.0 (1.2.0 was reverted)
-- 1.8.0: "Dismiss vehicle" button at the bottom (V's own vehicles only, not while V sits in it; second click within
--        3 s confirms): the car pulls away driverless into traffic and goes back to the garage after 6 s, via
--        bridge 1.1.0 VehicleObject.CSVA_Dismiss. Without the bridge it despawns at once (DespawnPlayerVehicle).
-- 1.7.1: "Hands off automatically after 5 s standing" checkbox (on by default, saved in settings.json) + CET hotkey
--        "Toggle auto hands off" (unbound): V lets go of the wheel after the car V drives has stood still for 5 s and
--        takes it again when the car rolls. If V puts the hands back by key, they stay there until the car has moved.
--        Needs Cyberslop Autodrive Manual Window 1.3.1 (PlayerPuppet.CSAMW_HandsFreeAuto).
-- 1.7.0: "Hands off the wheel" button (Engine section, only while V drives a car) + CET hotkey "Hands off the wheel"
--        (unbound): V takes the hands off the wheel like in autodrive (elbow out of an open window, else hands on the
--        lap) without autodrive. Needs Cyberslop Autodrive Manual Window 1.3.0 (PlayerPuppet.CSAMW_HandsFreeToggle).
-- 1.6.1: "hacked earlier; autodrive watched" reads Hacked Car Fix 1.1.1's getter CSHCF_TakenOver() (the field read was
--        always nil on CET 1.38.1); the "Toggle auto engine start" hotkey no longer starts the car V already sits in
--        (same as the checkbox: the current car counts as handled).
-- 1.6.0: CET 1.38.1 on 2.5 reads every script field as nil (and field writes are not trusted), which hid the Lights
--        section and Power row and made "Engine and power off when I get out" never fire. All field reads / writes
--        now go through the redscript bridge r6\scripts\zz_CyberslopVehicleActions\CSVABridge.reds (EVS fields,
--        headlight mode, multi-tap actions, door / window requests, the exit event), plain field access as fallback.
--        Lights section is now always shown, as checkboxes: Lights (all), Headlights, High beams, Interior lights,
--        Roof light (EVS), Utility lights; EVS when reachable, vanilla light calls otherwise. Engine buttons log an
--        8 s timeline to evscheck.log (diagnostic for "engine on, then the car goes off").
-- 1.5.1: "EVS check" button at the bottom: writes evscheck.log (what CET can read / call of EVS on the target car,
--        with error text). Diagnostic for the missing Power row / Lights section on 2.5.
-- 1.5.0: "Engine and power off when I get out" checkbox (Engine section, saved in settings.json, off by default):
--        when V starts to leave the driver seat (or the front passenger seat after sliding over from it), the
--        engine and power go off through EVS (vanilla without EVS), just before EVS's own exit code runs, so EVS then
--        does its power-off exit steps (interior lights, roof light, crystal dome) as with its "Power off" exit
--        setting. Not in scenes / quest driving or on a quest-locked car. CET hotkey "Toggle auto engine off".
-- 1.4.0: "Start engine when I get in" checkbox (Engine section, saved in settings.json, off by default): once per
--        entry, 0.6 s after V sits in the driver seat, the engine and power go on through EVS (vanilla without EVS),
--        also when the engine still runs but the cabin is dark. Not in scenes / quest driving or Take Control.
--        CET hotkey "Toggle auto engine start" (unbound).
-- 1.3.1: writes Cyberslop Hacked Car Fix's log lines (CSHCFLog system, 1.1.0+) to hackedcar.log in this folder, one
--        flushed line each, and shows the last two under Hack state; the Lua fix sends only DriverReady (no NoDriver)
--        and no longer cancels AI vehicle commands, like the redscript fix 1.1.0.
-- 1.3.0: "Hack state" row + "Fix hacked car" button (and CET hotkey "Fix hacked car", unbound) for a car the vanilla
--        Take Control quickhack left broken: trunk / hood with no interaction, vanilla autodrive (K) switching itself
--        off. Uses Cyberslop Hacked Car Fix (redscript, from the next game start) when it is there, else does the same
--        steps itself. Locks row says "locked out" instead of "disabled".
-- Own CET window "Vehicle Actions" for the vehicle part of AMM's Target Actions plus every
-- Enhanced Vehicle System key action, so EVS's keyboard keys can be unbound:
--   target: the car V sits in, else the car V aims at, else the last one (up to 30 m); Pin keeps it
--   locks: Lock / Unlock all doors (state shown)
--   engine: on / off and power on / off through EVS's own functions (EVS Numpad 1 hold / double tap),
--           "headlights off while parked" (EVS Numpad 1 long hold, engine off);
--           without EVS: vanilla TurnVehicleOn + TurnEngineOn
--   lights (EVS): headlights off / low / high (L hold), utility lights (L tap), roof light and
--           interior lights (Numpad 4 tap / double tap), custom light colours per type (Numpad 1+1)
--   crystal dome (EVS Numpad 4 hold): on / off, "Clear glass now" (forced re-apply, the call EVS uses
--           for the Outlaw "Weiler", whose instant-on effect is broken), "Keep glass clear" (re-applies
--           it when the engine starts and whenever it drops while V is inside)
--   doors and windows per seat (state on the button), trunk, hood, spoiler (EVS Numpad 2+2), all
--   crystal coat on / off (vanilla key double tap), police lights / siren / signal (police cars)
-- AMM 2.12.5 game calls for doors / windows / locks; EVS 17.8 functions for the rest. Neither is touched.
-- Window shows with the CET overlay; CET hotkey "Show / hide window" (unbound). Settings: settings.json.

local SETTINGS_FILE = "settings.json"
local KEEP_RANGE = 30.0          -- metres a looked-away target is kept
local FULL_W, HALF_W, THIRD_W, BTN_H = 352, 172, 112, 26
local DOME_POLL = 0.5            -- seconds between "keep glass clear" checks
local DOME_SETTLE = 1.5          -- seconds after mount / engine start before the forced re-apply
local DOME_COOLDOWN = 3.0        -- seconds between two forced re-applies
local AUTOSTART_POLL = 0.25      -- seconds between "start engine when I get in" checks
local AUTOSTART_SETTLE = 0.6     -- seconds in the driver seat before the start (EVS's own mount code runs first)
local AUTOOFF_POLL = 0.25        -- seconds between "which car is V driving" checks for "off when I get out"
local HANDS_POLL = 0.5           -- seconds between "is the car standing" checks for the automatic hands off
local HANDS_IDLE = 5.0           -- seconds standing before V lets go of the wheel
local HANDS_STILL = 0.3          -- m/s: below this the car counts as standing
local HANDS_MOVED = 1.5          -- m/s: above this the car has moved (hands are back, the timer may run again)
local DISMISS_DRIVE = 6.0        -- seconds the dismissed car drives off before it despawns
local DISMISS_CONFIRM = 3.0      -- seconds the "click again" state of the Dismiss button lasts

local SEATS = {
    { cname = "seat_front_left",  enum = 0, name = "Front left" },
    { cname = "seat_front_right", enum = 1, name = "Front right" },
    { cname = "seat_back_left",   enum = 2, name = "Rear left" },
    { cname = "seat_back_right",  enum = 3, name = "Rear right" },
}
local TRUNK, HOOD = 4, 5

local CUSTOM_LIGHTS = {          -- EVS custom colour toggle: tap count -> light type
    { tap = 1, enum = "Head",     name = "Head" },
    { tap = 2, enum = "Brake",    name = "Tail" },
    { tap = 3, enum = "Utility",  name = "Utility" },
    { tap = 4, enum = "Blinkers", name = "Blinkers" },
    { tap = 5, enum = "Reverse",  name = "Reverse" },
    { tap = 6, enum = "Interior", name = "Interior" },
}

local state = {
    overlay = false,
    show = true,
    keepDomeClear = false,
    autoStart = false,
    auto = { next = 0, vehHash = nil, seatedAt = nil, done = false },
    autoOff = false,
    autoHands = true,
    hands = { next = 0, still = 0, blocked = false, last = 0 },   -- blocked: V put the hands back by key
    off = { next = 0, driverHash = nil },   -- car V sits in and has driven since getting in
    targetId = nil,      -- EntityID of the current target
    pinned = false,
    source = "",
    message = "",
    messageTime = 0,
    clock = 0,
    dome = { next = 0, vehHash = nil, running = false, forceAt = nil, lastForce = -100 },
    dismiss = { hash = nil, at = -100 },   -- car whose Dismiss button waits for the confirming click
}

------------------------------------------------------------------ settings
local function loadSettings()
    local f = io.open(SETTINGS_FILE, "r")
    if not f then return end
    local ok, data = pcall(function() return json.decode(f:read("*a")) end)
    f:close()
    if ok and type(data) == "table" then
        if type(data.show) == "boolean" then state.show = data.show end
        if type(data.keepDomeClear) == "boolean" then state.keepDomeClear = data.keepDomeClear end
        if type(data.autoStart) == "boolean" then state.autoStart = data.autoStart end
        if type(data.autoOff) == "boolean" then state.autoOff = data.autoOff end
        if type(data.autoHands) == "boolean" then state.autoHands = data.autoHands end
    end
end

local function saveSettings()
    local f = io.open(SETTINGS_FILE, "w")
    if not f then return end
    f:write(json.encode({ show = state.show, keepDomeClear = state.keepDomeClear, autoStart = state.autoStart,
                          autoOff = state.autoOff, autoHands = state.autoHands }))
    f:close()
end

local function say(msg)
    state.message = msg
    state.messageTime = state.clock
end

------------------------------------------------------------------ helpers
local function try(fn, ...)
    local ok, res = pcall(fn, ...)
    if ok then return res end
    return nil
end

local function enum(typeName, value)
    local e = try(function() return Enum.new(typeName, value) end)
    if e ~= nil then return e end
    return value
end

local function newObj(cls)
    local o = try(function() return _G[cls].new() end)
    if o == nil then o = try(function() return NewObject("handle:" .. cls) end) end
    return o
end

local function isVehicle(obj)
    return obj ~= nil and try(function() return obj:IsVehicle() end) == true
end

local function isBike(veh)
    return try(function() return veh:IsA("vehicleBikeBaseObject") end) == true
end

local function mountedVehicle(player)
    local v = try(function() return player:GetMountedVehicle() end)
    if isVehicle(v) then return v end
    v = try(function() return player:GetQuickSlotsManager():GetVehicleObject() end)
    if isVehicle(v) then return v end
    return nil
end

local function distance(a, b)
    local pa, pb = a:GetWorldPosition(), b:GetWorldPosition()
    local dx, dy, dz = pa.x - pb.x, pa.y - pb.y, pa.z - pb.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function vehicleName(veh)
    local n = try(function() return veh:GetDisplayName() end)   -- GameObject native, already localized
    if n == nil or n == "" then
        n = try(function() return TDBID.ToStringDEBUG(veh:GetRecordID()) end) or "vehicle"
    end
    return n
end

local function onOff(b) return b and "on" or "off" end

-- current target vehicle (handle) or nil; also sets state.source
local function resolveTarget(player)
    local inCar = mountedVehicle(player)
    local current = state.targetId and Game.FindEntityByID(state.targetId) or nil
    if current ~= nil and not isVehicle(current) then current = nil end

    if state.pinned and current ~= nil then
        state.source = (inCar ~= nil and inCar:GetEntityID().hash == current:GetEntityID().hash) and "in car, pinned" or "pinned"
        return current
    end
    if inCar ~= nil then
        state.targetId = inCar:GetEntityID()
        state.source = "in car"
        return inCar
    end
    local aimed = try(function()
        local ts = Game.GetTargetingSystem()
        return ts:GetLookAtObject(player, false, false) or ts:GetLookAtObject(player, true, false)
    end)
    if isVehicle(aimed) then
        state.targetId = aimed:GetEntityID()
        state.source = "aimed"
        return aimed
    end
    if current ~= nil then
        local d = try(distance, player, current)
        if d ~= nil and d <= KEEP_RANGE then
            state.source = string.format("last, %.0f m", d)
            return current
        end
    end
    state.targetId = nil
    state.pinned = false
    state.source = ""
    return nil
end

------------------------------------------------------------------ vehicle state
local function doorState(ps, e)        -- "Open" / "Closed" / "Detached" / nil
    return try(function() return ps:GetDoorState(e).value end)
end

local function windowState(ps, e)      -- "Open" / "Closed" / nil
    return try(function() return ps:GetWindowState(e).value end)
end

local function lockState(ps)           -- "Available" / "Locked" / "QuestLocked" / ...
    return try(function() return ps:GetDoorInteractionState(0).value end)
end

local function hasSeat(veh, cname)
    return try(function()
        return Game['VehicleComponent::HasSlot;GameInstanceVehicleObjectCName'](veh, CName.new(cname))
    end) == true
end

-- CET 1.38.1 on 2.5 reads every script field as nil (evscheck.log 2026-11-21): fields go through the redscript
-- bridge r6\scripts\zz_CyberslopVehicleActions\CSVABridge.reds (from the next game start), plain reads stay as fallback
local function bridged(vc)             -- bridge compiled in
    return try(function() return vc:CSVA_Bridge() end) == 1
end

local function evsBridged(vc)          -- bridge compiled in with its EVS part
    return try(function() return vc:CSVA_HasEVS() end) == true
end

local EVS_INT = { m_hgyi56_EVS_currentHeadlightsState = true, m_hgyi56_EVS_threeStatesSiren = true }

local function evsField(vc, field)     -- EVS field on VehicleComponentPS
    local ps = try(function() return vc:GetPS() end)
    if ps == nil then return nil end
    if field:find("^m_hgyi56_EVS_") and evsBridged(vc) then
        if EVS_INT[field] then return try(function() return ps:CSVA_GetInt(CName.new(field)) end) end
        return try(function() return ps:CSVA_GetBool(CName.new(field)) end)
    end
    return try(function() return ps[field] end)
end

local COMP_BRIDGE = { m_useAuxiliary = "CSVA_UseAuxiliary", m_hasSpoiler = "CSVA_HasSpoiler",
                      m_hgyi56_EVS_playerIsDismounting = "CSVA_IsDismounting" }

local function compField(vc, field)    -- field on the VehicleComponent itself
    local getter = COMP_BRIDGE[field]
    if getter ~= nil then
        local v = try(function() return vc[getter](vc) end)
        if v ~= nil then return v end
    end
    return try(function() return vc[field] end)
end

-- EVS headlight mode: "Off" / "On" / "HighBeams" (nil without EVS)
local HL_NAMES = { [0] = "Off", [1] = "On", [2] = "HighBeams" }
local HL_INTS = { Off = 0, On = 1, HighBeams = 2 }
local function evsHeadlights(vc)
    local v = evsField(vc, "m_hgyi56_EVS_currentHeadlightsState")
    if type(v) == "number" then return HL_NAMES[v] end
    return try(function() return v.value end)
end

local function domeOn(vc)
    return try(function() return vc:GetPS():GetCrystalDomeState() end) == true
end

local function hasDome(veh, vc)
    if evsField(vc, "m_hgyi56_EVS_hasCrystalDome") == true then return true end
    return try(function() return veh:GetRecord():IsArmoredVehicle() end) == true
end

------------------------------------------------------------------ actions
local function queueDoor(ps, slot, open)
    if pcall(function() ps:CSVA_QueueDoor(CName.new(slot), open) end) then return end
    local ev = open and VehicleDoorOpen.new() or VehicleDoorClose.new()
    ev.slotID = CName.new(slot)
    ev.forceScene = false
    ps:QueuePSEvent(ps, ev)
end

local function queueWindow(ps, slot, open)
    if pcall(function() ps:CSVA_QueueWindow(CName.new(slot), open) end) then return end
    local ev = open and VehicleWindowOpen.new() or VehicleWindowClose.new()
    ev.slotID = CName.new(slot)
    ev.forceScene = false
    ps:QueuePSEvent(ps, ev)
end

-- EVS multi-tap handlers check that the tap count matches their step field; set both, call directly
local TAP_BRIDGE = { MultiTapLightsToggleEvent = "CSVA_CustomLightsTap", MultiTapPoliceLightsEvent = "CSVA_PoliceTap",
                     MultiTapCrystalCoatEvent = "CSVA_CrystalCoatTap" }
local function evsTap(target, stepField, handler, cls, tap)
    if TAP_BRIDGE[cls] and try(function() return target[TAP_BRIDGE[cls]](target, tap) end) == true then return true end
    local evt = newObj(cls)
    if evt == nil then return false end
    return pcall(function()
        target[stepField] = tap
        evt.tapCount = tap
        target[handler](target, evt)
    end)
end

local function setEngine(veh, on, inside)
    local vc = veh:GetVehicleComponent()
    local viaEvs = pcall(function()
        if on then
            -- EVS hold: power first, then clear a "headlights off while parked" shutoff
            vc:hgyi56_EVS_TogglePowerState(true)
            if evsField(vc, "m_hgyi56_EVS_temporaryHeadlightsShutOff") == true then
                vc:hgyi56_EVS_ToggleHeadlightsShutoff(false)
                vc:hgyi56_EVS_ApplyHeadlightsModeWithShutOff()
                vc:hgyi56_EVS_ApplyUtilityLightsWithShutOff()
            end
        end
        vc:hgyi56_EVS_ToggleEngineState(on)
    end)
    if not viaEvs then
        pcall(function() veh:TurnVehicleOn(on) end)
        pcall(function() veh:TurnEngineOn(on) end)
        pcall(function() veh:SetInteriorUIEnabled(on) end)
    end
    -- EVS keeps a car V is not in at Default, so the game does not shut it down
    if viaEvs and on and not inside then
        pcall(function()
            local ctrl = vc:GetVehicleControllerPS()
            if ctrl:GetState() == vehicleEState.On then ctrl:SetState(vehicleEState.Default) end
        end)
    end
    if on then state.dome.forceAt = state.clock + DOME_SETTLE end
    say((on and "Engine on" or "Engine off") .. (viaEvs and " (EVS)" or " (vanilla)"))
    -- 1.6.0 diagnostic: what happens to the car in the next 8 s (evscheck.log)
    state.engTrace = { id = veh:GetEntityID(), start = state.clock, idx = 1,
                       head = string.format("engine %s button, %s, %s", on and "on" or "off",
                                            viaEvs and "EVS" or "vanilla", inside and "in car" or "outside") }
end

local ENG_TRACE_AT = { 0.0, 0.25, 0.5, 1.0, 2.0, 4.0, 8.0 }
local function engTraceTick()
    local t = state.engTrace
    if t == nil then return end
    local el = state.clock - t.start
    if el < ENG_TRACE_AT[t.idx] then return end
    local line
    local veh = Game.FindEntityByID(t.id)
    if veh == nil then
        line = "car gone"
    else
        local vc = veh:GetVehicleComponent()
        local ctrl = try(function() return vc:GetVehicleControllerPS():GetState().value end)
        line = string.format("engine %s, controller %s, EVS power %s, EVS engine %s, headlights %s, driver %s",
            tostring(try(function() return veh:IsEngineTurnedOn() end)), tostring(ctrl),
            tostring(evsField(vc, "m_hgyi56_EVS_powerState")), tostring(evsField(vc, "m_hgyi56_EVS_engineState")),
            tostring(evsHeadlights(vc) or try(function() return vc:GetVehicleControllerPS():GetHeadLightMode().value end)),
            tostring(try(function() return veh:IsPlayerDriver() end)))
    end
    local f = io.open("evscheck.log", "a")
    if f then
        if t.idx == 1 then f:write("==== " .. os.date("%Y-%m-%d %H:%M:%S") .. " " .. t.head .. "\n") end
        f:write(string.format("  +%.2f s: %s\n", el, line))
        f:close()
    end
    t.idx = t.idx + 1
    if t.idx > #ENG_TRACE_AT or veh == nil then state.engTrace = nil end
end

local function setPower(veh, on)
    local vc = veh:GetVehicleComponent()
    local ok = pcall(function()
        if not on and veh:IsEngineTurnedOn() then vc:hgyi56_EVS_ToggleEngineState(false) end
        vc:hgyi56_EVS_TogglePowerState(on)
    end)
    say(ok and (on and "Power on" or "Power off") or "Power needs Enhanced Vehicle System")
end

local function setParkedShutoff(vc, on)
    local ok = pcall(function()
        vc:hgyi56_EVS_ToggleHeadlightsShutoff(on)
        vc:hgyi56_EVS_ApplyHeadlightsModeWithShutOff()
        vc:hgyi56_EVS_ApplyUtilityLightsWithShutOff()
    end)
    say(ok and (on and "Headlights off while parked" or "Headlights back") or "Shutoff failed")
end

local function setHeadlights(vc, mode)   -- "Off" / "On" / "HighBeams"
    local ok = pcall(function()
        local ps = vc:GetPS()
        if evsField(vc, "m_hgyi56_EVS_temporaryHeadlightsShutOff") == true then vc:hgyi56_EVS_ToggleHeadlightsShutoff(false) end
        if not pcall(function() ps:CSVA_SetHeadlightsState(HL_INTS[mode]) end) then
            ps.m_hgyi56_EVS_currentHeadlightsState = enum("vehicleELightMode", mode)
        end
        vc:hgyi56_EVS_ApplyHeadlightsMode()
        vc:hgyi56_EVS_EnsureIsActive_UtilityLights()
        vc:hgyi56_EVS_EnsureIsDisabled_UtilityLights()
    end)
    local names = { Off = "off", On = "low", HighBeams = "high" }
    say(ok and ("Headlights " .. names[mode]) or "Headlights failed")
end

local function toggleUtility(veh, vc)
    local ok = pcall(function()
        local sync = try(function()
            return MyModSettings.GetBool("utilitylights.utilityLightsSynchronizedWithHeadlightsShutoff", veh)
        end)
        if sync == nil then sync = true end
        if evsField(vc, "m_hgyi56_EVS_temporaryHeadlightsShutOff") == true and sync then
            vc:hgyi56_EVS_ToggleHeadlightsShutoff(false)
        else
            vc:hgyi56_EVS_ToggleUtilityLights(evsField(vc, "m_hgyi56_EVS_auxiliaryState") ~= true)
        end
        vc:hgyi56_EVS_ApplyHeadlightsModeWithShutOff()
        vc:hgyi56_EVS_EnsureIsActive_UtilityLights()
        vc:hgyi56_EVS_EnsureIsDisabled_UtilityLights()
    end)
    say(ok and "Utility lights toggled" or "Utility lights failed")
end

-- forced re-apply: ToggleCrystalDome(on, force, not instant, 0, 0, no fast stop) + mesh for the camera,
-- what EVS does when it restores a dome car (instant-on is broken on the Outlaw "Weiler")
local function forceDome(veh, vc)
    local ok = pcall(function()
        vc:ToggleCrystalDome(true, true, false, 0.0, 0.0, false)
    end)
    if not ok then
        ok = pcall(function() vc:hgyi56_EVS_MyToggleCrystalDome(true) end)
    end
    pcall(function() vc:OnVehicleCameraChange(veh:GetCameraManager():IsTPPActive()) end)
    state.dome.lastForce = state.clock
    return ok
end

local function setDome(veh, vc, on, inside)
    local ok
    if on then
        ok = forceDome(veh, vc)
    else
        if state.keepDomeClear then
            state.keepDomeClear = false
            saveSettings()
        end
        ok = pcall(function()
            if inside then vc:hgyi56_EVS_MyToggleCrystalDome(false)
            else vc:ToggleCrystalDome(false, true, false, 0.0, 0.0, false) end
        end)
    end
    say(ok and ("Crystal dome " .. onOff(on)) or "Crystal dome failed")
end

------------------------------------------------------------------ hacked car (vanilla Take Control quickhack)
local HACK_DOORS = { { e = 0, name = "driver door" }, { e = 1, name = "passenger door" },
                     { e = TRUNK, name = "trunk" }, { e = HOOD, name = "hood" } }
local SEAT_NAMES = { "seat_front_left", "seat_front_right", "seat_back_left", "seat_back_right" }

local function interactionState(ps, e)  -- "Available" / "Locked" / "Disabled" / ...
    return try(function() return ps:GetDoorInteractionState(e).value end)
end

-- player state machine still names a remote-controlled car that no longer is one (vanilla then ignores car interactions)
local function staleRemoteId(player)
    return try(function()
        local bb = player:GetPlayerStateMachineBlackboard()
        local id = bb:GetEntityID(GetAllBlackboardDefs().PlayerStateMachine.EntityIDVehicleRemoteControlled)
        if id == nil or id.hash == 0 then return false end
        local rv = Game.FindEntityByID(id)
        if isVehicle(rv) and rv:IsVehicleRemoteControlled() then return false end
        return true
    end) == true
end

local function hackIssues(player, veh, ps)
    local out = {}
    if try(function() return veh:IsVehicleRemoteControlled() end) == true then table.insert(out, "remote control still on") end
    if staleRemoteId(player) then table.insert(out, "player stuck in remote mode") end
    if try(function() return veh:IsVehicleAccelerateQuickhackActive() end) == true then table.insert(out, "accelerate hack running") end
    if try(function() return veh:IsVehicleForceBrakesQuickhackActive() end) == true then table.insert(out, "force-brake hack running") end
    local off = {}
    for _, d in ipairs(HACK_DOORS) do
        if not (isBike(veh) and d.e ~= 0) and interactionState(ps, d.e) == "Disabled" then table.insert(off, d.name) end
    end
    if #off > 0 then table.insert(out, "no interaction: " .. table.concat(off, ", ")) end
    return out
end

local function enableDoor(ps, e)
    if interactionState(ps, e) ~= "Disabled" then return false end
    if pcall(function() ps:CSVA_EnableDoorInteraction(e) end) then return true end
    return pcall(function()
        local ev = VehicleDoorInteractionStateChange.new()
        ev.door = enum("EVehicleDoor", e)
        ev.newState = enum("VehicleDoorInteractionState", "Available")
        ev.source = "CyberslopVehicleActions"
        ps:QueuePSEvent(ps, ev)
    end)
end

-- same steps as Cyberslop Hacked Car Fix's CSHCF_Repair(true, ...), for the running game before that is compiled in
local function luaHackFix(player, veh, ps, vc)
    local done = {}
    local driver = try(function() return veh:IsPlayerDriver() end) == true
    if try(function() return veh:IsVehicleRemoteControlled() end) == true then
        if pcall(function() veh:SetVehicleRemoteControlled(false, false, true) end) then table.insert(done, "remote flag") end
    end
    if staleRemoteId(player) then
        if pcall(function()
            player:GetPlayerStateMachineBlackboard():SetEntityID(
                GetAllBlackboardDefs().PlayerStateMachine.EntityIDVehicleRemoteControlled, EntityID.new())
        end) then table.insert(done, "player remote id") end
    end
    for _, d in ipairs(HACK_DOORS) do
        if enableDoor(ps, d.e) then table.insert(done, d.name) end
    end
    local autodriveOn = try(function()
        return Game.GetScriptableSystemsContainer():Get(CName.new("AutoDriveSystem")):GetAutodriveEnabled()
    end) == true
    autodriveOn = autodriveOn or try(function()
        return veh:GetBlackboard():GetBool(GetAllBlackboardDefs().Vehicle.IsAutopilotOn)
    end) == true
    local ai = try(function() return veh:GetAIComponent() end)
    if driver and not autodriveOn then
        if pcall(function() veh:ForceBrakesUntilStoppedOrFor(0.0) end) then table.insert(done, "brakes") end
    end
    if ai ~= nil then
        for _, seat in ipairs(SEAT_NAMES) do
            local cn = CName.new(seat)
            local occupied = try(function()
                return Game['VehicleComponent::IsSlotOccupied;GameInstanceEntityIDCName'](veh:GetEntityID(), cn)
            end)
            if occupied == false and try(function() return ai:IsSeatReserved(cn) end) == true then
                if pcall(function() ai:ReleaseSeat(cn) end) then table.insert(done, seat .. " reservation") end
            end
        end
    end
    if driver then
        if try(function() return veh:IsEngineTurnedOn() end) ~= true then
            setEngine(veh, true, true)
            table.insert(done, "engine on")
        end
        pcall(function()
            local ctrl = vc:GetVehicleControllerPS()
            if veh:IsEngineTurnedOn() and ctrl:GetState() == vehicleEState.Default then
                ctrl:SetState(enum("vehicleEState", "On"))
                table.insert(done, "car on")
            end
        end)
        if not autodriveOn and pcall(function()
            local ev = AIEvent.new()
            ev.name = CName.new("DriverReady")
            veh:QueueEvent(ev)
        end) then table.insert(done, "driver AI") end
    end
    return done
end

local function fixHackedCar(player, veh)
    local ps = veh:GetVehiclePS()
    local vc = veh:GetVehicleComponent()
    local driver = try(function() return veh:IsPlayerDriver() end) == true
    local tail = driver and " - press K again" or ""
    -- redscript version (Cyberslop Hacked Car Fix) when it is compiled in: also logs [CSHackedCar] to gamelog.log
    local res = try(function() return vc:CSHCF_Repair(true, "Vehicle Actions button") end)
    if res ~= nil then
        res = res:gsub("^%s+", "")
        say(((res == "") and "Hacked car fix: nothing to fix" or ("Hacked car fix: " .. res)) .. tail)
        return
    end
    local done = luaHackFix(player, veh, ps, vc)
    say(((#done == 0) and "Hacked car fix: nothing to fix" or ("Hacked car fix: " .. table.concat(done, ", "))) .. tail)
end

-- Cyberslop Hacked Car Fix log: its CSHCFLog system keeps the last 30 lines; each new one goes to hackedcar.log
local HCF_LOG_FILE = "hackedcar.log"
local hcfLog = { seen = 0, next = 0, recent = {} }

local function hcfSystem()
    return try(function() return Game.GetScriptableSystemsContainer():Get(CName.new("CSHCFLog")) end)
end

local function pollHcfLog()
    if state.clock < hcfLog.next then return end
    hcfLog.next = state.clock + 1.0
    local sys = hcfSystem()
    if sys == nil then return end
    local count = try(function() return sys:Count() end)
    if type(count) ~= "number" or count == hcfLog.seen then return end
    if count < hcfLog.seen then hcfLog.seen = 0 end           -- new game session / system re-created
    local size = try(function() return sys:Size() end) or 0
    local fresh = math.min(count - hcfLog.seen, size)
    hcfLog.seen = count
    if fresh <= 0 then return end
    local stamp = try(function() return os.date("%Y-%m-%d %H:%M:%S") end) or "?"
    local f = io.open(HCF_LOG_FILE, "a")
    for i = size - fresh, size - 1 do
        local line = try(function() return sys:Line(i) end)
        if type(line) == "string" and line ~= "" then
            if f then f:write(stamp .. " " .. line .. "\n"); f:flush() end
            table.insert(hcfLog.recent, line)
            if #hcfLog.recent > 2 then table.remove(hcfLog.recent, 1) end
        end
    end
    if f then f:close() end
end

local function drawHack(player, veh, ps)
    local issues = hackIssues(player, veh, ps)
    -- Cyberslop Hacked Car Fix flag: set by Take Control, cleared once vanilla autodrive has run 8 s in the car
    local taken = try(function() return veh:GetVehicleComponent():GetPS():CSHCF_TakenOver() end) == true
    ImGui.Separator()
    if #issues == 0 then
        ImGui.Text("Hack state: OK" .. (taken and " (hacked earlier; autodrive watched)" or ""))
    else
        ImGui.TextColored(1.0, 0.75, 0.3, 1.0, "Hack state:")
        for _, s in ipairs(issues) do ImGui.TextColored(1.0, 0.75, 0.3, 1.0, "  - " .. s) end
    end
    if ImGui.Button("Fix hacked car (trunk, autodrive)##hackfix", FULL_W, BTN_H) then
        fixHackedCar(player, veh)
    end
    if #hcfLog.recent > 0 then
        local wrapped = pcall(function() ImGui.PushTextWrapPos(FULL_W) end)
        for _, s in ipairs(hcfLog.recent) do
            ImGui.TextColored(0.6, 0.6, 0.6, 1.0, (#s > 160) and (s:sub(1, 160) .. "...") or s)
        end
        if wrapped then pcall(function() ImGui.PopTextWrapPos() end) end
    end
end

------------------------------------------------------------------ keep glass clear (runs without the overlay)
local function domeTick()
    local d = state.dome
    if not state.keepDomeClear or state.clock < d.next then return end
    d.next = state.clock + DOME_POLL

    local player = Game.GetPlayer()
    local veh = player and mountedVehicle(player) or nil
    if veh == nil then d.vehHash, d.running, d.forceAt = nil, false, nil; return end
    local vc = veh:GetVehicleComponent()
    if vc == nil or not hasDome(veh, vc) then return end
    -- leave EVS's exit sequence alone (it turns the dome off on the way out)
    if compField(vc, "m_hgyi56_EVS_playerIsDismounting") == true then return end
    if evsField(vc, "m_hgyi56_EVS_playerIsMounted") == false then return end

    local hash = try(function() return veh:GetEntityID().hash end)
    local running = try(function() return veh:IsEngineTurnedOn() end) == true
    local power = evsField(vc, "m_hgyi56_EVS_powerState") == true
    if hash ~= d.vehHash or (running and not d.running) then
        d.forceAt = state.clock + DOME_SETTLE      -- new car or engine just started
    end
    d.vehHash, d.running = hash, running
    if not (running or power) then return end

    local due = d.forceAt ~= nil and state.clock >= d.forceAt
    if (due or not domeOn(vc)) and state.clock - d.lastForce >= DOME_COOLDOWN then
        if due then d.forceAt = nil end   -- a dome-off catch keeps the pending after-start re-apply
        forceDome(veh, vc)
    end
end

------------------------------------------------------------------ start engine when I get in (runs without the overlay)
local function autoStartTick()
    local a = state.auto
    if state.clock < a.next then return end
    a.next = state.clock + AUTOSTART_POLL
    if not state.autoStart then a.vehHash = nil; return end

    local player = Game.GetPlayer()
    local veh = player and try(function() return player:GetMountedVehicle() end) or nil
    if not isVehicle(veh) or try(function() return veh:IsPlayerDriver() end) ~= true then
        a.vehHash, a.seatedAt, a.done = nil, nil, false      -- out of the driver seat: arm for the next entry
        return
    end
    local hash = try(function() return veh:GetEntityID().hash end)
    if hash ~= a.vehHash then a.vehHash, a.seatedAt, a.done = hash, state.clock, false end
    if a.done or state.clock - a.seatedAt < AUTOSTART_SETTLE then return end

    local vc = veh:GetVehicleComponent()
    if vc == nil then return end
    -- EVS still in its mount / exit sequence: try again next poll
    if compField(vc, "m_hgyi56_EVS_playerIsDismounting") == true then return end
    if evsField(vc, "m_hgyi56_EVS_playerIsMounted") == false then return end
    a.done = true                                            -- once per entry, so V can switch it off again
    -- scenes / quest driving and Take Control: the game handles the car
    if try(function() return player:hgyi56_EVS_IsFullGameplay() end) == false then return end
    if try(function() return veh:IsVehicleRemoteControlled() end) == true then return end

    local engineOn = try(function() return veh:IsEngineTurnedOn() end) == true
    local cabinOn = try(function() return veh:GetBlackboard():GetBool(GetAllBlackboardDefs().Vehicle.IsUIActive) end)
    if engineOn and cabinOn ~= false then return end
    setEngine(veh, true, true)
    say("Auto start: engine on")
end

------------------------------------------------------------------ engine and power off when I get out
-- remembers the car V sits in as driver, so an exit from the front passenger seat after sliding over from the
-- driver seat also counts (EVS's own exit code treats it the same way)
local function autoOffTick()
    local o = state.off
    if state.clock < o.next then return end
    o.next = state.clock + AUTOOFF_POLL
    if not state.autoOff then o.driverHash = nil; return end

    local player = Game.GetPlayer()
    local veh = player and try(function() return player:GetMountedVehicle() end) or nil
    if not isVehicle(veh) then o.driverHash = nil; return end
    local hash = try(function() return veh:GetEntityID().hash end)
    if try(function() return veh:IsPlayerDriver() end) == true then
        o.driverHash = hash
    elseif hash ~= o.driverHash then
        o.driverHash = nil                                   -- passenger in another car
    end
end

local function slotName(cn)
    local s = try(function() return cn.value end)
    if type(s) ~= "string" then s = try(function() return Game.NameToString(cn) end) end
    return s
end

-- ObserveBefore VehicleComponent.OnVehicleStartedMountingEvent: runs before vanilla and EVS's exit code, so EVS
-- already sees the power off and does its power-off exit steps (interior lights, roof light, crystal dome)
local function onExitStart(comp, evt)
    if not state.autoOff or evt == nil then return end
    -- event fields through the bridge (CET reads them as nil), plain reads as fallback
    local mounting = try(function() return evt:CSVA_IsMounting() end)
    if mounting == nil then mounting = evt.isMounting end
    if mounting ~= false then return end
    local who = try(function() return evt:CSVA_Character() end) or evt.character
    if who == nil or not who:IsPlayer() then return end
    local veh = comp:GetVehicle()
    if not isVehicle(veh) then return end

    local slotId = try(function() return evt:CSVA_Slot() end) or evt.slotID
    local slot = slotName(slotId)
    local fromDriver = slot == "seat_front_left"
        or try(function() return VehicleComponent.IsDriverSlot(slotId) end) == true
    if not fromDriver and slot == "seat_front_right" then
        local hash = try(function() return veh:GetEntityID().hash end)
        fromDriver = hash ~= nil and hash == state.off.driverHash
    end
    if not fromDriver then return end
    -- scenes / quest driving and quest-locked cars: the game handles the car
    if try(function() return Game.GetPlayer():hgyi56_EVS_IsFullGameplay() end) == false then return end
    if try(function() return veh:IsVehicleOnStateLocked() end) == true then return end

    -- EVS's "Power off" exit order: power, then engine
    local viaEvs = pcall(function()
        comp:hgyi56_EVS_TogglePowerState(false)
        comp:hgyi56_EVS_ToggleEngineState(false)
    end)
    if not viaEvs then
        pcall(function() veh:TurnEngineOn(false) end)
        pcall(function() veh:TurnVehicleOn(false) end)
        pcall(function() veh:SetInteriorUIEnabled(false) end)
    end
    state.off.driverHash = nil
    say("Auto off: engine and power off" .. (viaEvs and " (EVS)" or " (vanilla)"))
end

------------------------------------------------------------------ UI
local function label(kind, s)
    if s == nil then return kind .. ": ?" end
    if s == "Detached" then return kind .. ": gone" end
    return kind .. ": " .. string.lower(s)
end

local function drawEngine(veh, vc, inside)
    ImGui.Separator()
    local engineOn = try(function() return veh:IsEngineTurnedOn() end) == true
    local power = evsField(vc, "m_hgyi56_EVS_powerState")
    local evsEngine = evsField(vc, "m_hgyi56_EVS_engineState")
    local line = "Engine: " .. (engineOn and "running" or "off")
    if power ~= nil then line = line .. "   Power: " .. onOff(power) end
    if evsEngine ~= nil and evsEngine ~= engineOn then line = line .. "   (EVS flag: " .. onOff(evsEngine) .. ")" end
    ImGui.Text(line)
    if ImGui.Button((engineOn and "Engine off" or "Engine on") .. "##engine", power ~= nil and HALF_W or FULL_W, BTN_H) then
        setEngine(veh, not engineOn, inside)
    end
    if power ~= nil then
        ImGui.SameLine()
        if ImGui.Button((power and "Power off" or "Power on") .. "##power", HALF_W, BTN_H) then
            setPower(veh, not power)
        end
        local shut = evsField(vc, "m_hgyi56_EVS_temporaryHeadlightsShutOff")
        if not engineOn and shut ~= nil then
            if ImGui.Button((shut and "Headlights back on" or "Headlights off while parked") .. "##shutoff", FULL_W, BTN_H) then
                setParkedShutoff(vc, not shut)
            end
        end
    end
    local v, changed = ImGui.Checkbox("Start engine when I get in (all cars)##autostart", state.autoStart)
    if changed then
        state.autoStart = v
        -- not for the car V already sits in: it counts as handled, the next entry starts
        state.auto.vehHash = inside and try(function() return veh:GetEntityID().hash end) or nil
        state.auto.seatedAt = state.clock
        state.auto.done = inside
        saveSettings()
        say(v and "Engine starts when you get in" or "Auto engine start off")
    end
    local off, offChanged = ImGui.Checkbox("Engine and power off when I get out (all cars)##autooff", state.autoOff)
    if offChanged then
        state.autoOff = off
        state.off.next = 0                                   -- pick up the car V sits in on the next frame
        saveSettings()
        say(off and "Engine and power go off when you get out" or "Auto engine off disabled")
    end
end

-- vanilla lights (no EVS, or the bridge not compiled in yet): head light mode on the controller PS, the other
-- light types through vehicleController.ToggleLights; the game has no getter for those, so the window remembers them
local vanillaLights = {}   -- vehicle hash -> { Interior = bool, Utility = bool }

local function vanillaHeadMode(vc)       -- "Off" / "On" / "HighBeams"
    return try(function() return vc:GetVehicleControllerPS():GetHeadLightMode().value end)
end

local function vanillaToggle(veh, vc, lightType, on)
    local ok = pcall(function()
        vc:GetVehicleController():ToggleLights(on, enum("vehicleELightType", lightType))
    end)
    if ok then
        local h = try(function() return veh:GetEntityID().hash end) or 0
        vanillaLights[h] = vanillaLights[h] or {}
        vanillaLights[h][lightType] = on
    end
    return ok
end

local function vanillaState(veh, lightType)
    local h = try(function() return veh:GetEntityID().hash end) or 0
    return vanillaLights[h] ~= nil and vanillaLights[h][lightType] == true
end

local function setHeadMode(veh, vc, evs, mode)   -- "Off" / "On" / "HighBeams"
    if evs then setHeadlights(vc, mode) return end
    local ok = pcall(function() vc:GetVehicleControllerPS():SetHeadLightMode(enum("vehicleELightMode", mode)) end)
    local names = { Off = "off", On = "on", HighBeams = "high beams" }
    say(ok and ("Headlights " .. names[mode]) or "Headlights failed")
end

local function setInterior(veh, vc, evs, on)
    local ok
    if evs then ok = pcall(function() vc:hgyi56_EVS_ToggleInteriorLights(on) end)
    else ok = vanillaToggle(veh, vc, "Interior", on) end
    say(ok and ("Interior lights " .. onOff(on)) or "Interior lights failed")
end

local function setRoof(vc, on)
    local ok = pcall(function() vc:hgyi56_EVS_ToggleRoofLight(on, false) end)
    say(ok and ("Roof light " .. onOff(on)) or "Roof light failed")
end

local function drawLights(veh, vc)
    -- EVS path when its state is readable (bridge compiled in); vanilla otherwise
    local evsMode = evsHeadlights(vc)
    local evs = evsMode ~= nil
    local bike = isBike(veh)
    local shut = evs and evsField(vc, "m_hgyi56_EVS_temporaryHeadlightsShutOff") == true
    local mode = evs and evsMode or vanillaHeadMode(vc)
    local headOn = mode ~= nil and mode ~= "Off" and not shut
    local high = headOn and mode == "HighBeams"
    local inner, roof, aux
    if evs then
        inner = evsField(vc, "m_hgyi56_EVS_interiorLightsState") == true
        roof = evsField(vc, "m_hgyi56_EVS_roofLightState") == true
        if compField(vc, "m_useAuxiliary") == true and evsField(vc, "m_hgyi56_EVS_isPoliceVehicle") ~= true then
            aux = evsField(vc, "m_hgyi56_EVS_auxiliaryState") == true
        end
    else
        inner = vanillaState(veh, "Interior")
        if compField(vc, "m_useAuxiliary") == true then aux = vanillaState(veh, "Utility") end
    end
    local anyOn = headOn or (not bike and inner) or (evs and not bike and roof) or aux == true

    ImGui.Separator()
    ImGui.Text("Lights" .. (evs and "" or " (vanilla, EVS not reachable yet)")
        .. (shut and "   headlights off while parked" or ""))

    local v, changed = ImGui.Checkbox("Lights (all)##lall", anyOn)
    if changed then
        if v then
            setHeadMode(veh, vc, evs, "On")
            if not bike then setInterior(veh, vc, evs, true) end
            say("Lights on")
        else
            setHeadMode(veh, vc, evs, "Off")
            if not bike then
                setInterior(veh, vc, evs, false)
                if evs and roof then setRoof(vc, false) end
            end
            if aux then
                if evs then toggleUtility(veh, vc) else vanillaToggle(veh, vc, "Utility", false) end
            end
            say("Lights off")
        end
    end

    v, changed = ImGui.Checkbox("Headlights##lhead", headOn)
    if changed then setHeadMode(veh, vc, evs, v and "On" or "Off") end
    ImGui.SameLine(190)
    v, changed = ImGui.Checkbox("High beams##lhigh", high)
    if changed then setHeadMode(veh, vc, evs, v and "HighBeams" or "On") end

    local col = 0
    local function nextBox()
        if col > 0 then ImGui.SameLine(col * 190) end
        col = (col + 1) % 2
    end
    if not bike then
        nextBox()
        v, changed = ImGui.Checkbox("Interior lights##linner", inner)
        if changed then setInterior(veh, vc, evs, v) end
        if evs then
            nextBox()
            v, changed = ImGui.Checkbox("Roof light##lroof", roof)
            if changed then setRoof(vc, v) end
        end
    end
    if aux ~= nil then
        nextBox()
        v, changed = ImGui.Checkbox("Utility lights##laux", aux)
        if changed then
            if evs then toggleUtility(veh, vc)
            else say(vanillaToggle(veh, vc, "Utility", v) and ("Utility lights " .. onOff(v)) or "Utility lights failed") end
        end
    end
    if not evs then return end

    local player = Game.GetPlayer()
    ImGui.Text("Custom light colours (EVS, all cars):")
    for i, cl in ipairs(CUSTOM_LIGHTS) do
        local cur = try(function() return player:hgyi56_EVS_GetLightsCustomSettingsEnabled(enum("vehicleELightType", cl.enum)) end)
        if cur ~= nil then
            if (i - 1) % 3 ~= 0 then ImGui.SameLine() end
            local v, changed = ImGui.Checkbox(cl.name .. "##cl" .. cl.tap, cur)
            if changed then
                local ok = evsTap(player, "m_hgyi56_EVS_toggleCustomLightsStep",
                    "hgyi56_EVS_OnMultiTapLightsToggleEvent", "MultiTapLightsToggleEvent", cl.tap)
                say(ok and (cl.name .. " custom colour " .. onOff(v)) or (cl.name .. " custom colour failed"))
            end
        end
    end
end

local function drawDome(veh, vc, inside)
    if isBike(veh) or not hasDome(veh, vc) then return end
    local on = domeOn(vc)
    ImGui.Separator()
    ImGui.Text("Crystal dome: " .. (on and "on (clear glass)" or "off (screens)"))
    if ImGui.Button((on and "Dome off" or "Dome on") .. "##dome", HALF_W, BTN_H) then
        setDome(veh, vc, not on, inside)
    end
    ImGui.SameLine()
    if ImGui.Button("Clear glass now##domeforce", HALF_W, BTN_H) then
        say(forceDome(veh, vc) and "Crystal dome re-applied" or "Crystal dome failed")
    end
    local v, changed = ImGui.Checkbox("Keep glass clear (engine start, in car)", state.keepDomeClear)
    if changed then
        state.keepDomeClear = v
        state.dome.vehHash = nil       -- re-arm the start check
        saveSettings()
        say(v and "Keeping crystal dome clear" or "Crystal dome left to EVS")
    end
end

local function drawDoorsWindows(veh, vc, ps)
    local seats = {}
    for _, seat in ipairs(SEATS) do
        if hasSeat(veh, seat.cname) then table.insert(seats, seat) end
    end
    if #seats == 0 then seats = { SEATS[1], SEATS[2] } end

    ImGui.Separator()
    ImGui.Text("Doors / windows")
    for _, seat in ipairs(seats) do
        local d = doorState(ps, seat.enum)
        if ImGui.Button(label(seat.name .. " door", d) .. "##d" .. seat.enum, HALF_W, BTN_H) and d ~= "Detached" then
            queueDoor(ps, seat.cname, d ~= "Open")
        end
        ImGui.SameLine()
        local w = windowState(ps, seat.enum)
        if ImGui.Button(label("window", w) .. "##w" .. seat.enum, HALF_W, BTN_H) then
            queueWindow(ps, seat.cname, w ~= "Open")
        end
    end

    local t, h = doorState(ps, TRUNK), doorState(ps, HOOD)
    local spoiler = nil
    if compField(vc, "m_hasSpoiler") == true then spoiler = evsField(vc, "m_hgyi56_EVS_spoilerState") end
    local w = spoiler ~= nil and THIRD_W or HALF_W
    if ImGui.Button(label("Trunk", t) .. "##trunk", w, BTN_H) and t ~= "Detached" then
        queueDoor(ps, "trunk", t ~= "Open")
    end
    ImGui.SameLine()
    if ImGui.Button(label("Hood", h) .. "##hood", w, BTN_H) and h ~= "Detached" then
        queueDoor(ps, "hood", h ~= "Open")
    end
    if spoiler ~= nil then
        ImGui.SameLine()
        if ImGui.Button("Spoiler: " .. (spoiler and "up" or "down") .. "##spoiler", w, BTN_H) then
            if pcall(function() vc:hgyi56_EVS_ToggleSpoiler(not spoiler) end) then
                say(spoiler and "Spoiler down" or "Spoiler up") else say("Spoiler failed") end
        end
    end

    if ImGui.Button("Open all doors", HALF_W, BTN_H) then
        for _, seat in ipairs(seats) do queueDoor(ps, seat.cname, true) end
        say("Doors open")
    end
    ImGui.SameLine()
    if ImGui.Button("Close all doors", HALF_W, BTN_H) then
        for _, seat in ipairs(seats) do queueDoor(ps, seat.cname, false) end
        queueDoor(ps, "trunk", false)
        queueDoor(ps, "hood", false)
        say("Doors, trunk, hood closed")
    end
    if ImGui.Button("Open all windows", HALF_W, BTN_H) then
        for _, seat in ipairs(seats) do queueWindow(ps, seat.cname, true) end
        say("Windows open")
    end
    ImGui.SameLine()
    if ImGui.Button("Close all windows", HALF_W, BTN_H) then
        for _, seat in ipairs(seats) do queueWindow(ps, seat.cname, false) end
        say("Windows closed")
    end
end

local function drawExtras(veh, vc, ps)
    local police = evsField(vc, "m_hgyi56_EVS_isPoliceVehicle") == true
    if police then
        local siren = evsField(vc, "m_hgyi56_EVS_threeStatesSiren") or 0
        local names = { [0] = "off", [1] = "lights", [2] = "lights + siren" }
        ImGui.Separator()
        ImGui.Text("Police: " .. (names[siren] or tostring(siren)))
        local btns = { { "Lights##pol1", 1, "Police lights" }, { "Siren##pol2", 2, "Siren" }, { "Signal##pol3", 3, "Police signal" } }
        for i, b in ipairs(btns) do
            if i > 1 then ImGui.SameLine() end
            if ImGui.Button(b[1], THIRD_W, BTN_H) then
                local ok = evsTap(vc, "m_hgyi56_EVS_cyclePoliceSirenStep",
                    "hgyi56_EVS_OnMultiTapPoliceLightsEvent", "MultiTapPoliceLightsEvent", b[2])
                say(ok and b[3] or (b[3] .. " failed"))
            end
        end
        return
    end
    if try(function() return vc:GetIsVehicleVisualCustomizationEnabled() end) == true then
        local coat = try(function() return ps:GetIsVehicleVisualCustomizationActive() end) == true
        ImGui.Separator()
        if ImGui.Button("Crystal coat: " .. onOff(coat) .. "##coat", FULL_W, BTN_H) then
            local ok = evsTap(vc, "m_hgyi56_EVS_cycleCrystalCoatStep",
                "hgyi56_EVS_OnMultiTapCrystalCoatEvent", "MultiTapCrystalCoatEvent", 2)
            say(ok and ("Crystal coat " .. onOff(not coat)) or "Crystal coat failed")
        end
    end
end

------------------------------------------------------------------ dismiss (1.8.0)
local function dismissVehicle(veh)
    local name = vehicleName(veh)
    local res = try(function() return veh:CSVA_Dismiss(DISMISS_DRIVE) end)
    if res == nil then   -- bridge 1.1.0 not compiled in yet: despawn at once
        local ok = pcall(function()
            local id = NewObject("vehicleGarageVehicleID")
            id.recordID = veh:GetRecordID()
            Game.GetVehicleSystem():DespawnPlayerVehicle(id)
        end)
        res = ok and 0 or -1
    end
    if res == 0 then
        state.targetId, state.pinned = nil, false
        say(name .. " dismissed")
    elseif res == 1 then
        say("Dismiss: not your vehicle")
    elseif res == 2 then
        say("Dismiss: get out first")
    else
        say("Dismiss failed")
    end
end

local function drawDismiss(veh, inside)
    ImGui.Separator()
    if try(function() return veh:IsPlayerVehicle() end) ~= true then
        ImGui.TextDisabled("Dismiss: only your own vehicles")
        return
    end
    if inside then
        ImGui.TextDisabled("Dismiss: get out first")
        return
    end
    local hash = try(function() return veh:GetEntityID().hash end)
    local armed = hash ~= nil and state.dismiss.hash == hash and state.clock - state.dismiss.at < DISMISS_CONFIRM
    if ImGui.Button((armed and "Click again to dismiss" or "Dismiss vehicle") .. "##dismiss", FULL_W, BTN_H) then
        if armed then
            state.dismiss.hash = nil
            dismissVehicle(veh)
        else
            state.dismiss.hash, state.dismiss.at = hash, state.clock
        end
    end
end

------------------------------------------------------------------ hands off the wheel (1.7.0)
-- Cyberslop Autodrive Manual Window 1.3.0 does the work; state: 0 hands on the wheel, 1 off by key, 2 autodrive
local HANDS_MSG = {
    [1] = "Hands off the wheel", [0] = "Hands back on the wheel",
    [-1] = "Hands off: only while driving a car", [-2] = "Hands off: autodrive already does it",
    [-3] = "Hands off: stop the car first",
}

local function handsState(player)
    return try(function() return player:CSAMW_HandsFreeState() end)
end

local function toggleHands(player)
    local res = try(function() return player:CSAMW_HandsFreeToggle() end)
    if res == nil then say("Hands off: needs Cyberslop Autodrive Manual Window 1.3.0") return end
    say(HANDS_MSG[res] or ("Hands off: " .. tostring(res)))
end

local function drawHands(player, veh, inside)
    if not inside or isBike(veh) then return end
    if try(function() return veh:IsPlayerDriver() end) ~= true then return end
    local st = handsState(player)
    if st == nil then return end
    ImGui.Separator()
    local text = (st == 2) and "Hands off the wheel: autodrive" or ("Hands off the wheel: " .. onOff(st == 1))
    if ImGui.Button(text .. "##handsoff", FULL_W, BTN_H) then
        toggleHands(player)
    end
    local v, changed = ImGui.Checkbox("Hands off automatically after 5 s standing##autohands", state.autoHands)
    if changed then
        state.autoHands = v
        state.hands.still, state.hands.blocked = 0, false
        saveSettings()
    end
end

-- 1.7.1: the car V drives stands for HANDS_IDLE seconds -> hands off (the reds puts them back when it rolls)
local function handsAutoTick()
    local h = state.hands
    if state.clock < h.next then return end
    h.next = state.clock + HANDS_POLL
    if not state.autoHands then h.still = 0; return end

    local player = Game.GetPlayer()
    local veh = player and try(function() return player:GetMountedVehicle() end) or nil
    if not isVehicle(veh) or isBike(veh) or try(function() return veh:IsPlayerDriver() end) ~= true then
        h.still, h.blocked, h.last = 0, false, 0
        return
    end
    local st = handsState(player)
    if st == nil then return end                              -- Autodrive Manual Window 1.3.0+ not there
    local speed = math.abs(try(function() return veh:GetCurrentSpeed() end) or 99)
    if h.last == 1 and st == 0 and speed < HANDS_STILL then h.blocked = true end   -- back on the wheel by key
    h.last = st
    if speed > HANDS_MOVED then h.blocked = false end
    if speed >= HANDS_STILL or st ~= 0 or h.blocked then h.still = 0; return end
    h.still = h.still + HANDS_POLL
    if h.still < HANDS_IDLE then return end
    local res = try(function() return player:CSAMW_HandsFreeAuto() end)
    h.still = (res == 1) and 0 or (HANDS_IDLE - 1.0)          -- refused (getting in, weapon out): try again in 1 s
    if res == 1 then h.last = 1 end
end

------------------------------------------------------------------ EVS check (1.5.1 diagnostic)
-- writes evscheck.log in this folder: what CET can read / call of EVS on the target car, with the error text
local EVS_CHECK_FILE = "evscheck.log"

local function evsCheck(player, veh)
    local lines = {}
    local function P(name, fn)
        local ok, res = pcall(fn)
        local text
        if ok then
            if type(res) == "userdata" then
                local cls = try(function() return res:GetClassName().value end)
                local val = try(function() return res.value end)
                text = "userdata" .. (cls and (" class " .. cls) or "") .. (val and (" value " .. tostring(val)) or "")
                    .. " (" .. tostring(res) .. ")"
            else
                text = type(res) .. " " .. tostring(res)
            end
        else
            text = "ERROR " .. tostring(res)
        end
        lines[#lines + 1] = name .. " = " .. text
    end
    local vc = veh:GetVehicleComponent()
    local ps = try(function() return vc:GetPS() end)
    local vps = try(function() return veh:GetVehiclePS() end)
    P("CET version", function() return GetVersion() end)
    P("vehicle", function() return vehicleName(veh) end)
    P("vc class", function() return vc:GetClassName().value end)
    P("vc:GetPS() class", function() return ps:GetClassName().value end)
    P("veh:GetVehiclePS() class", function() return vps:GetClassName().value end)
    P("vanilla ps:GetCrystalDomeState()", function() return ps:GetCrystalDomeState() end)
    P("vanilla vc.m_useAuxiliary", function() return vc.m_useAuxiliary end)
    for _, f in ipairs({ "powerState", "engineState", "currentHeadlightsState", "temporaryHeadlightsShutOff",
                         "roofLightState", "interiorLightsState", "auxiliaryState", "hasCrystalDome", "isPoliceVehicle" }) do
        P("ps.m_hgyi56_EVS_" .. f, function() return ps["m_hgyi56_EVS_" .. f] end)
        P("vehiclePS.m_hgyi56_EVS_" .. f, function() return vps["m_hgyi56_EVS_" .. f] end)
    end
    P("vc.m_hgyi56_EVS_playerIsMounted", function() return vc.m_hgyi56_EVS_playerIsMounted end)
    P("vc.m_hgyi56_EVS_playerIsDismounting", function() return vc.m_hgyi56_EVS_playerIsDismounting end)
    P("vc.m_evsOnFixGen (EVS On Fix, no module)", function() return vc.m_evsOnFixGen end)
    P("ps.m_csHcfTakenOver (Hacked Car Fix)", function() return ps.m_csHcfTakenOver end)
    P("vc:hgyi56_EVS_IsHeadlightsOff()", function() return vc:hgyi56_EVS_IsHeadlightsOff() end)
    P("vc:hgyi56_EVS_IsCrystalCoatActive()", function() return vc:hgyi56_EVS_IsCrystalCoatActive() end)
    P("type(vc.hgyi56_EVS_ToggleEngineState)", function() return type(vc.hgyi56_EVS_ToggleEngineState) end)
    P("player:hgyi56_EVS_IsFullGameplay()", function() return player:hgyi56_EVS_IsFullGameplay() end)
    P("player:hgyi56_EVS_GetLightsCustomSettingsEnabled(Headlights)", function()
        return player:hgyi56_EVS_GetLightsCustomSettingsEnabled(enum("vehicleELightType", "Head")) end)
    P("EVS MyModSettings system", function()
        return Game.GetScriptableSystemsContainer():Get("Hgyi56.Enhanced_Vehicle_System.MyModSettings") end)
    P("bridge vc:CSVA_Bridge()", function() return vc:CSVA_Bridge() end)
    P("bridge vc:CSVA_HasEVS()", function() return vc:CSVA_HasEVS() end)
    P("bridge ps:CSVA_GetBool(powerState)", function() return ps:CSVA_GetBool(CName.new("m_hgyi56_EVS_powerState")) end)
    P("bridge ps:CSVA_GetInt(currentHeadlightsState)", function()
        return ps:CSVA_GetInt(CName.new("m_hgyi56_EVS_currentHeadlightsState")) end)
    P("bridge vc:CSVA_UseAuxiliary()", function() return vc:CSVA_UseAuxiliary() end)
    P("evsField power (window's read)", function() return evsField(vc, "m_hgyi56_EVS_powerState") end)
    P("evsHeadlights (window's read)", function() return evsHeadlights(vc) end)
    P("vanilla head light mode", function() return vc:GetVehicleControllerPS():GetHeadLightMode() end)
    P("veh:IsEngineTurnedOn()", function() return veh:IsEngineTurnedOn() end)
    P("controller state", function() return vc:GetVehicleControllerPS():GetState() end)

    local f = io.open(EVS_CHECK_FILE, "a")
    if f == nil then return false end
    f:write("==== " .. os.date("%Y-%m-%d %H:%M:%S") .. " (" .. state.source .. ")\n")
    for _, l in ipairs(lines) do f:write(l .. "\n") end
    f:close()
    return true
end

local function drawWindow()
    local player = Game.GetPlayer()
    if player == nil then
        ImGui.Text("No player (main menu / loading).")
        return
    end
    local veh = resolveTarget(player)
    if veh == nil then
        ImGui.TextWrapped("Aim at a vehicle or get in one.")
        return
    end
    local ps = veh:GetVehiclePS()
    local vc = veh:GetVehicleComponent()
    local inside = state.source == "in car" or state.source == "in car, pinned"

    ImGui.Text(vehicleName(veh))
    ImGui.SameLine()
    ImGui.TextColored(0.55, 0.85, 0.95, 1.0, "(" .. state.source .. ")")
    local pinned, changed = ImGui.Checkbox("Pin this vehicle", state.pinned)
    if changed then state.pinned = pinned end

    -- locks
    ImGui.Separator()
    local lock = lockState(ps)
    local lockText = (lock == "Available") and "unlocked" or (lock == "QuestLocked" and "quest locked"
        or (lock == "Disabled" and "locked out (see Hack state)" or string.lower(lock or "?")))
    ImGui.Text("Locks: " .. lockText)
    if ImGui.Button("Lock##lock", HALF_W, BTN_H) then
        if pcall(function() ps:LockAllVehDoors() end) then say("Locked") else say("Lock failed") end
    end
    ImGui.SameLine()
    if ImGui.Button("Unlock##unlock", HALF_W, BTN_H) then
        if pcall(function() ps:UnlockAllVehDoors() end) then say("Unlocked") else say("Unlock failed") end
    end

    drawHack(player, veh, ps)
    drawEngine(veh, vc, inside)
    drawHands(player, veh, inside)
    drawLights(veh, vc)
    drawDome(veh, vc, inside)
    if not isBike(veh) then
        drawDoorsWindows(veh, vc, ps)
    end
    drawExtras(veh, vc, ps)
    drawDismiss(veh, inside)

    ImGui.Separator()
    if ImGui.Button("EVS check (writes evscheck.log)##evscheck", FULL_W, BTN_H) then
        local ok, res = pcall(evsCheck, player, veh)
        say((ok and res) and "EVS check written to evscheck.log" or ("EVS check failed: " .. tostring(res)))
    end

    if state.message ~= "" and state.clock - state.messageTime < 4.0 then
        ImGui.Separator()
        ImGui.TextColored(0.6, 0.9, 0.6, 1.0, state.message)
    end
end

------------------------------------------------------------------ events
registerForEvent("onInit", function()
    loadSettings()
    ObserveBefore("VehicleComponent", "OnVehicleStartedMountingEvent", function(self, evt)
        pcall(onExitStart, self, evt)
    end)
end)

registerHotkey("toggle_window", "Show / hide window", function()
    state.show = not state.show
    saveSettings()
end)

-- the car V sits in or aims at (pinned car first), message shows in the window
registerHotkey("fix_hacked_car", "Fix hacked car", function()
    local player = Game.GetPlayer()
    if player == nil then return end
    local ok, err = pcall(function()
        local veh = resolveTarget(player)
        if veh == nil then say("Fix hacked car: no car in reach") return end
        fixHackedCar(player, veh)
    end)
    if not ok then say("Fix hacked car failed: " .. tostring(err)) end
end)

registerHotkey("toggle_autostart", "Toggle auto engine start", function()
    state.autoStart = not state.autoStart
    -- 1.6.1: like the checkbox, the car V already sits in counts as handled (the next entry starts)
    local player = Game.GetPlayer()
    local veh = player and try(function() return player:GetMountedVehicle() end) or nil
    local inside = isVehicle(veh) and try(function() return veh:IsPlayerDriver() end) == true
    state.auto.vehHash = inside and try(function() return veh:GetEntityID().hash end) or nil
    state.auto.seatedAt = state.clock
    state.auto.done = inside
    saveSettings()
    say(state.autoStart and "Engine starts when you get in" or "Auto engine start off")
end)

registerHotkey("toggle_autooff", "Toggle auto engine off", function()
    state.autoOff = not state.autoOff
    state.off.next = 0
    saveSettings()
    say(state.autoOff and "Engine and power go off when you get out" or "Auto engine off disabled")
end)

registerHotkey("toggle_hands_off", "Hands off the wheel", function()
    local player = Game.GetPlayer()
    if player == nil then return end
    pcall(toggleHands, player)
end)

registerHotkey("toggle_auto_hands_off", "Toggle auto hands off", function()
    state.autoHands = not state.autoHands
    state.hands.still, state.hands.blocked = 0, false
    saveSettings()
    say(state.autoHands and "Hands go off the wheel after 5 s standing" or "Automatic hands off disabled")
end)

registerForEvent("onOverlayOpen", function() state.overlay = true end)
registerForEvent("onOverlayClose", function() state.overlay = false end)

registerForEvent("onUpdate", function(dt)
    state.clock = state.clock + (dt or 0)
    pcall(domeTick)
    pcall(autoStartTick)
    pcall(autoOffTick)
    pcall(handsAutoTick)
    pcall(pollHcfLog)
    if not pcall(engTraceTick) then state.engTrace = nil end
end)

registerForEvent("onDraw", function()
    if not state.overlay or not state.show then return end
    ImGui.SetNextWindowSize(380, 0, ImGuiCond.FirstUseEver)
    if ImGui.Begin("Vehicle Actions", ImGuiWindowFlags.AlwaysAutoResize) then
        local ok, err = pcall(drawWindow)
        if not ok then
            ImGui.TextWrapped("Error: " .. tostring(err))
        end
    end
    ImGui.End()
end)

return {}
