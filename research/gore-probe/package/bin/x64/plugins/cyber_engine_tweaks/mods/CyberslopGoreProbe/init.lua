-- Cyberslop Gore Probe 1.1.0 (2026-11-02), CET half
-- Optional hotkeys and an optional on-screen readout for the redscript probe in r6\scripts\zz_zz_CyberslopGoreProbe.
-- Everything is logged by the redscript half to r6\storages\CyberslopGoreProbe\gore-N.txt; it needs none of this.
-- 1.1.0: readout off by default and costs nothing while off (no polling, no drawing); A/B toggle hotkey.
-- Bind the hotkeys in the CET overlay (Bindings). Console: GoreProbe.cut(4), GoreProbe.seen(true), GoreProbe.ab()
-- Remove: delete this folder and r6\scripts\zz_zz_CyberslopGoreProbe.

local hudOn = false
local hudText = ""
local note = ""
local noteUntil = 0
local clock = 0
local nextPoll = 0

local function system()
    local ok, sys = pcall(function()
        return Game.GetScriptableSystemsContainer():Get("CyberslopGoreProbeSystem")
    end)
    if ok then return sys end
    return nil
end

local function say(text)
    if not text or text == "" then return end
    print(text)
    note = text
    noteUntil = clock + 4
end

local function call(name, fn)
    local sys = system()
    if not sys then
        say("Gore Probe: redscript half not loaded (check the redscript log for zz_zz_CyberslopGoreProbe)")
        return nil
    end
    local ok, result = pcall(fn, sys)
    if not ok then
        say("Gore Probe: " .. name .. " failed: " .. tostring(result))
        return nil
    end
    return result
end

GoreProbe = {
    cut = function(part) say(call("ForceCut", function(s) return s:ForceCut(part or 4) end)) end,
    seen = function(gore) say(call("Seen", function(s) return s:Seen(gore and true or false) end)) end,
    mark = function() say(call("Mark", function(s) return s:Mark() end)) end,
    exp = function()
        local on = call("ToggleExperiment", function(s) return s:ToggleExperiment() end)
        if on ~= nil then say("Gore Probe: far-cut experiment " .. (on and "ON" or "OFF")) end
    end,
    ab = function()
        local on = call("ToggleAB", function(s) return s:ToggleAB() end)
        if on ~= nil then say("Gore Probe: automatic A/B engine test " .. (on and "ON" or "OFF")) end
    end,
}

registerHotkey("cgp_seen_yes", "Gore Probe: I SAW gore on the last hit", function() GoreProbe.seen(true) end)
registerHotkey("cgp_seen_no", "Gore Probe: NO gore on the last hit", function() GoreProbe.seen(false) end)
registerHotkey("cgp_cut_head", "Gore Probe: force cut HEAD (crosshair NPC, else last hit)", function() GoreProbe.cut(4) end)
registerHotkey("cgp_cut_arm", "Gore Probe: force cut LEFT ARM (crosshair NPC, else last hit)", function() GoreProbe.cut(0) end)
registerHotkey("cgp_cut_leg", "Gore Probe: force cut RIGHT LEG (crosshair NPC, else last hit)", function() GoreProbe.cut(3) end)
registerHotkey("cgp_mark", "Gore Probe: write a distance mark", function() GoreProbe.mark() end)
registerHotkey("cgp_experiment", "Gore Probe: toggle far-cut experiment", function() GoreProbe.exp() end)
registerHotkey("cgp_ab", "Gore Probe: toggle automatic A/B engine test (on by default)", function() GoreProbe.ab() end)
registerHotkey("cgp_hud", "Gore Probe: show / hide readout", function() hudOn = not hudOn end)

registerForEvent("onUpdate", function(delta)
    clock = clock + delta
    if not hudOn or clock < nextPoll then return end
    nextPoll = clock + 0.1
    local player = Game.GetPlayer()
    if not player then
        hudText = ""
        return
    end
    local sys = system()
    if not sys then
        hudText = "Gore Probe: redscript half not loaded"
        return
    end
    local ok, text = pcall(function() return sys:Hud() end)
    hudText = ok and tostring(text) or ("Gore Probe: " .. tostring(text))
end)

registerForEvent("onDraw", function()
    if not hudOn or hudText == "" then return end
    ImGui.SetNextWindowPos(30, 260, ImGuiCond.FirstUseEver)
    ImGui.SetNextWindowBgAlpha(0.45)
    local flags = ImGuiWindowFlags.NoTitleBar + ImGuiWindowFlags.AlwaysAutoResize + ImGuiWindowFlags.NoFocusOnAppearing
        + ImGuiWindowFlags.NoNav + ImGuiWindowFlags.NoScrollbar + ImGuiWindowFlags.NoCollapse
    if ImGui.Begin("Gore Probe##cgp", flags) then
        ImGui.Text(hudText)
        if clock < noteUntil then
            ImGui.Separator()
            ImGui.Text(note)
        end
    end
    ImGui.End()
end)
