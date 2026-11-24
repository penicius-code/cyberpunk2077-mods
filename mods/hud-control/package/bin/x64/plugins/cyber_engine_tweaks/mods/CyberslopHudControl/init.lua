-- Cyberslop HUD Control 1.1.1, built on Cyberpunk 2077 2.31
-- CET overlay window "HUD Control":
--   * hide / show the HUD elements Limited HUD manages (redscript system CyberslopHudControl)
--   * opacity: one preset slider for all HUD elements (10-100 % in steps of 10), then one slider per
--     element (0-100 % in steps of 5); untouched elements keep Limited HUD's own opacity
--   (1.1.1: Quest Compass controls removed)
--   * Cyberslop Scanner Pins on / off, scanner range and near range (Scanner Pins 1.1.0+)
-- Choices are saved in settings.json next to this file and re-applied after every load.
-- Only values changed in this window are saved; anything never touched keeps its Mod Settings value.

local SETTINGS = "settings.json"

local ELEMENTS = {
    { id = 0, label = "Minimap" },
    { id = 1, label = "Quest tracker" },
    { id = 2, label = "Health bar" },
    { id = 3, label = "Stamina bar" },
    { id = 4, label = "Weapon roster / ammo" },
    { id = 5, label = "Hotkeys (dpad / phone)" },
    { id = 6, label = "Input hints" },
    { id = 7, label = "Crouch indicator" },
}
local OPACITY_ELEMENTS = ELEMENTS

-- saved: hidden["h<id>"] = bool; opacity["o<id>"] = 0..1; allOpacity = 10..100;
--        pinsOn, pinsRange, pinsNear = nil or value
local saved = { hidden = {}, opacity = {} }
local overlayOpen = false
local applyTimer = 0
local applyTries = 0
local lastMsg = ""

-- live values for the window (read from the game while the overlay is open)
local live = { hud = false, pins = false,
               pinsOn = true, pinsRange = 200, pinsNear = 50, op = {}, lhudOp = {} }
local liveAt = -1

local function load()
    local f = io.open(SETTINGS, "r")
    if not f then return end
    local txt = f:read("*a")
    f:close()
    local ok, t = pcall(json.decode, txt)
    if ok and type(t) == "table" then
        saved = t
        saved.hidden = type(saved.hidden) == "table" and saved.hidden or {}
        saved.opacity = type(saved.opacity) == "table" and saved.opacity or {}
    end
end

local function save()
    local f = io.open(SETTINGS, "w")
    if not f then lastMsg = "could not write settings.json"; return end
    f:write(json.encode(saved))
    f:close()
end

local function sys(name)
    local c = Game.GetScriptableSystemsContainer()
    if not c then return nil end
    local s = c:Get(CName.new(name))
    if s == nil then return nil end
    return s
end

local function hudSys() return sys("CyberslopHudControl") end
local function pinsSys() return sys("CyberslopScanPinsSystem") end

-- push saved choices into a fresh game session; returns true when everything that is saved got applied
local function applySaved()
    local done = true
    local h = hudSys()
    if not h then return false end
    for _, e in ipairs(ELEMENTS) do
        local v = saved.hidden["h" .. e.id]
        if v ~= nil then h:SetHidden(e.id, v == true) end
    end
    for _, e in ipairs(OPACITY_ELEMENTS) do
        local v = saved.opacity["o" .. e.id]
        if type(v) == "number" then pcall(function() h:SetOpacity(e.id, v) end) end
    end
    local p = pinsSys()
    if p then
        if saved.pinsOn ~= nil then pcall(function() p:CS_SetEnabled(saved.pinsOn) end) end
        if saved.pinsRange ~= nil then pcall(function() p:CS_SetRange(saved.pinsRange) end) end
        if saved.pinsNear ~= nil then pcall(function() p:CS_SetNear(saved.pinsNear) end) end
    end
    return done
end

local function readLive()
    local h, p = hudSys(), pinsSys()
    live.hud = h ~= nil
    if h then
        for _, e in ipairs(OPACITY_ELEMENTS) do
            local ok1, o = pcall(function() return h:GetOpacity(e.id) end)
            local ok2, d = pcall(function() return h:LhudOpacity(e.id) end)
            live.op[e.id] = ok1 and o or -1
            live.lhudOp[e.id] = ok2 and d or 1
        end
    end
    live.pins = false
    if p then
        local ok1, on = pcall(function() return p:CS_GetEnabled() end)
        local ok2, r = pcall(function() return p:CS_GetRange() end)
        local ok3, n = pcall(function() return p:CS_GetNear() end)
        if ok1 and ok2 and ok3 then
            live.pins = true
            live.pinsOn, live.pinsRange, live.pinsNear = on, r, n
        end
    end
end

registerForEvent("onInit", function() load() end)
registerForEvent("onOverlayOpen", function() overlayOpen = true; liveAt = -1 end)
registerForEvent("onOverlayClose", function() overlayOpen = false end)

registerForEvent("onUpdate", function(dt)
    applyTimer = applyTimer + dt
    if applyTimer < 1.0 then return end
    applyTimer = 0
    if not Game.GetPlayer() then applyTries = 0; return end
    local h = hudSys()
    if not h then return end
    local okA, applied = pcall(function() return h:CetApplied() end)
    if not okA or applied then return end
    applyTries = applyTries + 1
    local ok, done = pcall(applySaved)
    if (ok and done) or applyTries >= 30 then
        h:MarkCetApplied()
        applyTries = 0
    end
end)

local function rounded(v, step) return math.floor((v + step / 2) / step) * step end

local function setOpacity(h, id, pct)
    if pct == nil then
        pcall(function() h:SetOpacity(id, -1.0) end)
        saved.opacity["o" .. id] = nil
        live.op[id] = -1
    else
        local v = pct / 100
        pcall(function() h:SetOpacity(id, v) end)
        saved.opacity["o" .. id] = v
        live.op[id] = v
    end
end

registerForEvent("onDraw", function()
    if not overlayOpen then return end
    ImGui.SetNextWindowSize(340, 0, ImGuiCond.FirstUseEver)
    if ImGui.Begin("HUD Control", ImGuiWindowFlags.AlwaysAutoResize) then
        if not Game.GetPlayer() then
            ImGui.TextDisabled("load a save first")
            ImGui.End()
            return
        end
        local now = os.clock()
        if liveAt < 0 or now - liveAt >= 0.25 then liveAt = now; pcall(readLive) end

        local h = hudSys()

        -- HUD elements: show / hide
        ImGui.Text("HUD elements (ticked = shown, LHUD rules apply)")
        if not h then
            ImGui.TextDisabled("CyberslopHudControl redscript missing")
        else
            for _, e in ipairs(ELEMENTS) do
                local hidden = h:IsHidden(e.id)
                local shown, pressed = ImGui.Checkbox(e.label .. "##hud" .. e.id, not hidden)
                if pressed then
                    h:SetHidden(e.id, not shown)
                    saved.hidden["h" .. e.id] = not shown
                    save()
                end
            end

            -- Opacity: preset for all, then per element
            ImGui.Separator()
            ImGui.Text("Opacity")
            ImGui.SetNextItemWidth(200)
            local allNow = type(saved.allOpacity) == "number" and saved.allOpacity or 100
            local all, usedAll = ImGui.SliderInt("All HUD elements##opall", allNow, 10, 100, "%d%%")
            if usedAll then
                all = rounded(all, 10)
                if all < 10 then all = 10 end
                if all ~= saved.allOpacity then
                    saved.allOpacity = all
                    for _, e in ipairs(OPACITY_ELEMENTS) do setOpacity(h, e.id, all) end
                    save()
                end
            end
            if ImGui.Button("Use Limited HUD's own opacity for all##opreset", 270, 0) then
                saved.allOpacity = nil
                for _, e in ipairs(OPACITY_ELEMENTS) do setOpacity(h, e.id, nil) end
                save()
            end
            ImGui.TextDisabled("Per element (shows LHUD's value until moved):")
            for _, e in ipairs(OPACITY_ELEMENTS) do
                local o = live.op[e.id] or -1
                local overridden = o >= 0
                local pct = math.floor(((overridden and o or (live.lhudOp[e.id] or 1)) * 100) + 0.5)
                ImGui.SetNextItemWidth(200)
                local v, used = ImGui.SliderInt(e.label .. "##op" .. e.id, pct, 0, 100, "%d%%")
                if used then
                    v = rounded(v, 5)
                    if v ~= pct or not overridden then
                        setOpacity(h, e.id, v)
                        save()
                    end
                end
                ImGui.SameLine()
                if overridden then
                    if ImGui.SmallButton("LHUD##opclr" .. e.id) then
                        setOpacity(h, e.id, nil)
                        save()
                    end
                else
                    ImGui.TextDisabled("(LHUD)")
                end
            end
        end

        ImGui.Separator()
        -- Scanner Pins
        ImGui.Text("Scanner Pins (world markers while scanning)")
        if not live.pins then
            ImGui.TextDisabled("needs Cyberslop Scanner Pins 1.1.0")
        else
            local p = pinsSys()
            local on, pressed = ImGui.Checkbox("Enabled##pins", live.pinsOn)
            if pressed then
                pcall(function() p:CS_SetEnabled(on) end)
                live.pinsOn = on
                saved.pinsOn = on
                save()
            end
            ImGui.SetNextItemWidth(200)
            local r, used = ImGui.SliderInt("Scanner range (m)##pins", live.pinsRange, 100, 300)
            if used then
                r = rounded(r, 50)
                if r ~= live.pinsRange then
                    pcall(function() p:CS_SetRange(r) end)
                    live.pinsRange = r
                    saved.pinsRange = r
                    save()
                end
            end
            ImGui.SetNextItemWidth(200)
            local n, usedN = ImGui.SliderInt("Always within (m)##pins", live.pinsNear, 0, 100)
            if usedN then
                n = rounded(n, 10)
                if n ~= live.pinsNear then
                    pcall(function() p:CS_SetNear(n) end)
                    live.pinsNear = n
                    saved.pinsNear = n
                    save()
                end
            end
            ImGui.TextDisabled("Range and on/off: markers that spawn after the change")
            ImGui.TextDisabled("(walk away and back, or reload). Near range: at once.")
        end

        if lastMsg ~= "" then ImGui.TextDisabled(lastMsg) end
        ImGui.Separator()
        if ImGui.Button("Reset all to Mod Settings defaults", 270, 0) then
            saved = { hidden = {}, opacity = {} }
            save()
            if h then
                for _, e in ipairs(ELEMENTS) do h:SetHidden(e.id, false) end
                pcall(function() h:SetAllOpacity(-1.0) end)
                for _, e in ipairs(OPACITY_ELEMENTS) do live.op[e.id] = -1 end
            end
            lastMsg = "saved choices cleared (Scanner Pins back after reload)"
        end
    end
    ImGui.End()
end)
