-- ============================================================
--  Gamma Slider 1.1.0 (2026-10-28)
--  Change the game's gamma (Settings > Video > Brightness) without the pause menu.
-- ============================================================
-- What: the gamma value the brightness screen edits is the engine config var /video/display/Gamma
--       (0.5 to 2.0, step 0.01, vanilla default 1.0). The engine applies a change to that var at once
--       (the brightness screen itself only drives the var, brightnessSettingsMain.swift), so this mod
--       writes it directly and asks the game to save UserSettings.json a moment later.
-- How:  CET overlay (`) > window "Gamma": slider, -/+ buttons, reset.
--       Hotkeys (CET Bindings tab, mod "GammaSlider"): "Gamma up" / "Gamma down" step by `step`,
--       "Gamma reset" sets `resetValue`. They are registerHotkey bindings, so key combinations such as
--       Ctrl + Numpad + work (CET accepts only single keys for registerInput bindings, which is why
--       there is no hold-to-ramp). Every hotkey change shows the new value on screen for a moment.
-- Day / night (1.1.0, off by default): two stored gamma values, switched automatically by in-game time
--       (night from nightStart to dayStart, hours 0 to 23). While it is on, every change (slider, keys)
--       is stored as the value of the current period, so you tune night at night and day by day.
-- Config: config.json next to this file (step, resetValue, showMessage, dayNight, dayGamma, nightGamma,
--       dayStart, nightStart), written when changed.
-- Log: GammaSlider.log. Console: GetMod("GammaSlider").get() / .set(1.2) / .status()

local VERSION = "1.1.0"
local GROUP, VAR = "/video/display", "Gamma"
local CONFIG_FILE = "config.json"
local SAVE_DELAY = 1.5          -- seconds after the last change before UserSettings.json is saved
local MSG_SECONDS = 1.5

local DEFAULTS = {
    step = 0.05, resetValue = 1.0, showMessage = true,
    dayNight = false, dayGamma = 1.0, nightGamma = 1.2, dayStart = 6, nightStart = 20,
}
local PERIOD_CHECK = 2.0        -- seconds between game clock checks

local M = { version = VERSION }
local cfg = {}
local st = {
    value = nil, min = 0.5, max = 2.0, varStep = 0.01, default = 1.0,
    ready = false, dirty = false, saveTimer = 0.0,
    overlay = false, lastError = nil,
    period = nil, periodTimer = 0.0,   -- "day" / "night" while dayNight is on
}

-- ---------------------------------------------------------------- helpers

local function log(fmt, ...)
    spdlog.info(string.format(fmt, ...))
end

local function round2(v)
    return math.floor(v * 100 + 0.5) / 100
end

local function clamp(v)
    if v < st.min then v = st.min end
    if v > st.max then v = st.max end
    return round2(v)
end

local function loadConfig()
    for k, v in pairs(DEFAULTS) do cfg[k] = v end
    local f = io.open(CONFIG_FILE, "r")
    if not f then return end
    local text = f:read("*a")
    f:close()
    local ok, data = pcall(json.decode, text)
    if not ok or type(data) ~= "table" then
        log("config.json unreadable, defaults used")
        return
    end
    for k in pairs(DEFAULTS) do
        if data[k] ~= nil and type(data[k]) == type(DEFAULTS[k]) then cfg[k] = data[k] end
    end
    cfg.step = round2(math.max(0.01, math.min(0.5, cfg.step)))
    cfg.resetValue = round2(math.max(0.5, math.min(2.0, cfg.resetValue)))
    cfg.dayGamma = round2(math.max(0.5, math.min(2.0, cfg.dayGamma)))
    cfg.nightGamma = round2(math.max(0.5, math.min(2.0, cfg.nightGamma)))
    cfg.dayStart = math.floor(math.max(0, math.min(23, cfg.dayStart)))
    cfg.nightStart = math.floor(math.max(0, math.min(23, cfg.nightStart)))
end

local function saveConfig()
    local f = io.open(CONFIG_FILE, "w")
    if not f then return end
    f:write(json.encode(cfg))
    f:close()
end

local function getVar()
    local ok, var = pcall(function()
        local sys = Game.GetSettingsSystem()
        if not sys or not sys:HasVar(GROUP, VAR) then return nil end
        return sys:GetVar(GROUP, VAR)
    end)
    if ok and var then return var end
    st.lastError = ok and "var not found" or tostring(var)
    return nil
end

-- Reads the live value (and range) from the settings system. Returns true when it worked.
local function refresh()
    local var = getVar()
    if not var then return false end
    local ok, err = pcall(function()
        st.value = var:GetValue()
        st.min = var:GetMinValue()
        st.max = var:GetMaxValue()
        st.varStep = var:GetStepValue()
    end)
    if not ok then
        st.lastError = tostring(err)
        return false
    end
    pcall(function() st.default = var:GetDefaultValue() end)   -- vanilla 1.0 if the method is missing
    if not st.ready then
        log("Gamma var found: %.2f (range %.2f to %.2f, default %.2f)", st.value, st.min, st.max, st.default)
    end
    st.ready = true
    return true
end

local function notify(msg)
    if not cfg.showMessage then return end
    pcall(function()
        local m = SimpleScreenMessage.new()
        m.isShown = true
        m.duration = MSG_SECONDS
        m.message = tostring(msg)
        m.isInstant = true
        local defs = Game.GetAllBlackboardDefs()
        Game.GetBlackboardSystem():Get(defs.UI_Notifications):SetVariant(defs.UI_Notifications.WarningMessage, ToVariant(m), true)
    end)
end

local function saveSettings()
    local ok, err = pcall(function()
        GetSingleton("inkMenuScenario"):GetSystemRequestsHandler():RequestSaveUserSettings()
    end)
    if ok then
        log("saved UserSettings.json with gamma %.2f", st.value or -1)
    else
        log("RequestSaveUserSettings failed: %s", tostring(err))
    end
end

-- Sets the gamma var; `quiet` skips the on-screen message (slider drags).
local function apply(v, quiet)
    if not st.ready and not refresh() then
        log("cannot set gamma: %s", tostring(st.lastError))
        return false
    end
    v = clamp(v)
    local var = getVar()
    if not var then return false end
    local ok, err = pcall(function()
        var:SetValue(v)
        local sys = Game.GetSettingsSystem()
        if sys:NeedsConfirmation() then sys:ConfirmChanges() end
    end)
    if not ok then
        st.lastError = tostring(err)
        log("SetValue failed: %s", tostring(err))
        return false
    end
    st.value = v
    if cfg.dayNight and st.period and not st.switching then
        if st.period == "night" then cfg.nightGamma = v else cfg.dayGamma = v end
        st.configDirty = true
    end
    st.dirty = true
    st.saveTimer = SAVE_DELAY
    if not quiet then notify(string.format("Gamma %.2f", v)) end
    return true
end

-- Current period from the game clock; nil outside a game session.
local function currentPeriod()
    local ok, h = pcall(function()
        local player = Game.GetPlayer()
        if not player then return nil end
        return Game.GetTimeSystem():GetGameTime():Hours()
    end)
    if not ok or type(h) ~= "number" then return nil end
    local ds, ns = cfg.dayStart, cfg.nightStart
    local night
    if ns > ds then night = (h >= ns or h < ds) else night = (h >= ns and h < ds) end
    return night and "night" or "day", h
end

-- Applies the stored value of the current period (force: even if the period did not change).
local function checkPeriod(force)
    if not cfg.dayNight then st.period = nil return end
    local p, h = currentPeriod()
    if not p then return end
    if p == st.period and not force then return end
    st.period = p
    local target = (p == "night") and cfg.nightGamma or cfg.dayGamma
    log("period %s (game hour %d): gamma %.2f", p, h, target)
    if not st.ready and not refresh() then return end
    if math.abs((st.value or 0) - target) >= 0.005 then
        st.switching = true
        apply(target, true)
        st.switching = false
    end
end

local function stepBy(dir)
    if not st.ready and not refresh() then return end
    apply(st.value + dir * cfg.step)
end

-- ---------------------------------------------------------------- console API

function M.get()
    refresh()
    return st.value
end

function M.set(v)
    return apply(tonumber(v) or st.value or 1.0)
end

function M.period()
    return currentPeriod()
end

function M.status()
    refresh()
    print(string.format("GammaSlider %s: gamma %s (range %.2f to %.2f), step %.2f, reset %.2f, dirty %s, last error %s",
        VERSION, st.value and string.format("%.2f", st.value) or "?", st.min, st.max, cfg.step, cfg.resetValue,
        tostring(st.dirty), tostring(st.lastError)))
end

-- ---------------------------------------------------------------- events

registerForEvent("onInit", function()
    loadConfig()
    log("GammaSlider %s loaded (step %.2f, reset %.2f, message %s)", VERSION, cfg.step, cfg.resetValue, tostring(cfg.showMessage))
    refresh()   -- the settings system exists in the main menu too; if it is not there yet, the first use retries
end)

registerForEvent("onUpdate", function(dt)
    if cfg.dayNight then
        st.periodTimer = st.periodTimer - dt
        if st.periodTimer <= 0 then
            st.periodTimer = PERIOD_CHECK
            checkPeriod(false)
        end
    end
    if st.configDirty then
        st.configDirty = false
        saveConfig()
    end
    if st.dirty then
        st.saveTimer = st.saveTimer - dt
        if st.saveTimer <= 0 then
            st.dirty = false
            saveSettings()
        end
    end
end)

registerForEvent("onOverlayOpen", function()
    st.overlay = true
    refresh()
end)

registerForEvent("onOverlayClose", function()
    st.overlay = false
end)

registerForEvent("onShutdown", function()
    if st.dirty then
        st.dirty = false
        saveSettings()
    end
end)

-- Hotkeys (one step per press; combinations allowed).
registerHotkey("GammaUp", "Gamma up (one step)", function()
    stepBy(1)
end)

registerHotkey("GammaDown", "Gamma down (one step)", function()
    stepBy(-1)
end)

registerHotkey("GammaReset", "Gamma reset (to the reset value)", function()
    apply(cfg.resetValue)
end)

-- ---------------------------------------------------------------- overlay window

registerForEvent("onDraw", function()
    if not st.overlay then return end
    if not ImGui.Begin("Gamma", ImGuiWindowFlags.AlwaysAutoResize) then
        ImGui.End()
        return
    end
    if not st.ready and not refresh() then
        ImGui.Text("Gamma setting not available yet.")
        ImGui.TextDisabled(tostring(st.lastError))
        ImGui.End()
        return
    end

    ImGui.SetNextItemWidth(260)
    local v, changed = ImGui.SliderFloat("##gamma", st.value, st.min, st.max, "%.2f")
    if changed then apply(v, true) end

    if ImGui.Button("-", 40, 0) then stepBy(-1) end
    ImGui.SameLine()
    if ImGui.Button("+", 40, 0) then stepBy(1) end
    ImGui.SameLine()
    if ImGui.Button(string.format("Reset to %.2f", cfg.resetValue), 120, 0) then apply(cfg.resetValue) end
    ImGui.SameLine()
    if ImGui.Button("Game default", 100, 0) then apply(st.default) end

    ImGui.Separator()
    ImGui.SetNextItemWidth(120)
    local s, sChanged = ImGui.InputFloat("Hotkey step", cfg.step, 0.01, 0.05, "%.2f")
    if sChanged then
        cfg.step = round2(math.max(0.01, math.min(0.5, s)))
        saveConfig()
    end
    ImGui.SameLine()
    if ImGui.Button("Use current as reset", 160, 0) then
        cfg.resetValue = st.value
        saveConfig()
    end
    local show, showChanged = ImGui.Checkbox("Show the value on screen after a hotkey", cfg.showMessage)
    if showChanged then
        cfg.showMessage = show
        saveConfig()
    end
    ImGui.Separator()
    local dn, dnChanged = ImGui.Checkbox("Day / night gamma (switches by game time)", cfg.dayNight)
    if dnChanged then
        cfg.dayNight = dn
        st.period = nil
        saveConfig()
        if dn then checkPeriod(true) end
    end
    if cfg.dayNight then
        ImGui.SetNextItemWidth(200)
        local d, dC = ImGui.SliderFloat("Day gamma", cfg.dayGamma, 0.5, 2.0, "%.2f")
        if dC then cfg.dayGamma = round2(d) saveConfig() if st.period == "day" then checkPeriod(true) end end
        ImGui.SetNextItemWidth(200)
        local n, nC = ImGui.SliderFloat("Night gamma", cfg.nightGamma, 0.5, 2.0, "%.2f")
        if nC then cfg.nightGamma = round2(n) saveConfig() if st.period == "night" then checkPeriod(true) end end
        ImGui.SetNextItemWidth(200)
        local ns, nsC = ImGui.SliderInt("Night starts (hour)", cfg.nightStart, 0, 23)
        if nsC then cfg.nightStart = ns saveConfig() checkPeriod(false) end
        ImGui.SetNextItemWidth(200)
        local ds, dsC = ImGui.SliderInt("Day starts (hour)", cfg.dayStart, 0, 23)
        if dsC then cfg.dayStart = ds saveConfig() checkPeriod(false) end
        ImGui.TextDisabled(st.period and ("Now: " .. st.period .. ". Changes above the line are stored for it.")
            or "Waiting for a game session.")
    end
    ImGui.TextDisabled("Keys: CET Bindings > GammaSlider. Saved to UserSettings.json after each change.")
    ImGui.End()
end)

return M
