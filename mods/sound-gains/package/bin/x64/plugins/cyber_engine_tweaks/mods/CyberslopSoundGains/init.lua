-- ============================================================
--  Cyberslop Sound Gains 1.0.0 (2026-10-27)
--  Level trim for custom-sound rows that AudioXL did not register itself (the REDmod rows).
-- ============================================================
-- Why: with AudioXL installed every custom sound, REDmod rows included, sits in the engine's custom-sound registry
-- that AudioXL drives, and the "gain" stored in a registry row never reaches the samples (RadioXL, Audio.reds);
-- AudioXL applies levels itself, through SetGain. The engine registers the REDmod rows first (-modded), so a copy of a
-- REDmod in AudioXL's sounds folder is refused as "already registered; skipped" (AudioXL log, 2026-10-27) and
-- the REDmods' info.json gains (dodge, double jump, Kerenzikov, Sandevistan 0.05; Monowire first equip 0.5) play at 1.0.
-- What: once AudioXL's Lua bridge answers (AudioXL.AudioXLLua, a ScriptableSystem), SetGain is called for every row
-- in gains.lua; rows without an engine slot yet are retried once a second for up to 90 s, and every row is set again
-- at each session start (PlayerPuppet.OnGameAttached). Nothing else is touched. Log: CyberslopSoundGains.log.
-- Console: GetMod("CyberslopSoundGains").status()  /  GetMod("CyberslopSoundGains").apply()

local VERSION = "1.0.0"
local GAINS = require("gains")            -- event name -> gain, 1.0 = as recorded (edit gains.lua, not this file)

local RETRY_SECONDS = 1.0
local GIVE_UP_SECONDS = 90.0

local M = { version = VERSION }
local pending = {}                         -- rows still to set in the current pass
local state = { done = {}, failed = {}, timer = 0.0, elapsed = 0.0, polling = false, noBridge = false, pass = 0 }

local function dB(g)
    if g <= 0 then return "silent" end
    return string.format("%+.1f dB", 20 * math.log(g, 10))
end

local function log(fmt, ...)
    spdlog.info(string.format(fmt, ...))
end

local function bridge()
    local ok, sys = pcall(function()
        return Game.GetScriptableSystemsContainer():Get("AudioXL.AudioXLLua")
    end)
    if ok and sys then return sys end
    return nil
end

-- Sets every pending row; true when none is left.
local function applyPending(reason)
    local axl = bridge()
    if not axl then
        if not state.noBridge then
            state.noBridge = true
            log("AudioXL.AudioXLLua not found (%s): AudioXL missing or not loaded yet, nothing set", reason)
        end
        return false
    end
    state.noBridge = false
    local left = {}
    for name, gain in pairs(pending) do
        local okCall, set = pcall(function() return axl:SetGain(name, gain) end)
        if okCall and set then
            state.done[name] = gain
            state.failed[name] = nil
            log("%s = %.3f (%s) set, %s", name, gain, dB(gain), reason)
        else
            local has = false
            pcall(function() has = axl:Has(name) end)
            if not state.failed[name] then
                log("%s: SetGain %s (Has = %s), retrying", name,
                    okCall and "false" or ("error " .. tostring(set)), tostring(has))
            end
            state.failed[name] = (state.failed[name] or 0) + 1
            left[name] = gain
        end
    end
    pending = left
    return next(pending) == nil
end

local function startPass(reason)
    state.pass = state.pass + 1
    pending = {}
    local n = 0
    for name, gain in pairs(GAINS) do
        if type(gain) == "number" and gain >= 0 then
            pending[name] = gain
            n = n + 1
        else
            log("gains.lua: '%s' = %s ignored (not a number >= 0)", tostring(name), tostring(gain))
        end
    end
    state.failed = {}
    state.elapsed, state.timer = 0.0, 0.0
    log("pass %d (%s): %d row(s) to set", state.pass, reason, n)
    state.polling = not applyPending(reason)
    if not state.polling then log("pass %d done: all %d row(s) set", state.pass, n) end
end

registerForEvent("onInit", function()
    log("Cyberslop Sound Gains %s", VERSION)
    startPass("onInit")
    Observe("PlayerPuppet", "OnGameAttached", function(self)
        if self then startPass("session start") end
    end)
end)

registerForEvent("onUpdate", function(dt)
    if not state.polling then return end
    state.timer = state.timer + dt
    state.elapsed = state.elapsed + dt
    if state.timer < RETRY_SECONDS then return end
    state.timer = 0.0
    if applyPending("retry") then
        state.polling = false
        log("pass %d done after %.0f s", state.pass, state.elapsed)
    elseif state.elapsed >= GIVE_UP_SECONDS then
        state.polling = false
        local names = {}
        for name in pairs(pending) do names[#names + 1] = name end
        table.sort(names)
        log("pass %d gave up after %.0f s, not set: %s", state.pass, state.elapsed, table.concat(names, ", "))
    end
end)

function M.apply()
    startPass("console")
end

function M.status()
    local names = {}
    for name in pairs(GAINS) do names[#names + 1] = name end
    table.sort(names)
    for _, name in ipairs(names) do
        local s = pending[name] and "pending" or (state.done[name] and "set" or "not set")
        print(string.format("%-36s %.3f  %s", name, tonumber(GAINS[name]) or -1, s))
    end
    print("AudioXL bridge: " .. (bridge() and "found" or "missing") .. ", polling: " .. tostring(state.polling)
        .. ", pass " .. state.pass)
end

return M
