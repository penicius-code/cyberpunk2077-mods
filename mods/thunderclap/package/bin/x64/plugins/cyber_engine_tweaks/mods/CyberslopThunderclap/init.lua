-- Cyberslop Thunderclap settings 1.2.1 (2026-11-23; 1.2.0 2026-11-08).
-- Window "Cyberslop Thunderclap" while the CET overlay is open: switch the slow motion on cast on or off.
-- 1.2.1: sets the choice through the redscript service CyberslopThunderclapSlowMo
-- (r6\scripts\CyberslopThunderclap\SlowMoSwitch.reds, method SetSlowMo), which the cast reads.
-- 1.2.0 wrote the TweakDB flat CyberslopThunderclap.Settings.value, which failed on every 2.5 launch.
-- The choice is kept in config.json next to this file and applied again at every launch
-- (retried every second until the service answers, for up to 2 minutes).

local SERVICE = "CyberslopThunderclapSlowMo"
local CONFIG = "config.json"

local settings = { slowMo = true }
local overlayOpen = false
local status = ""
local pending = false
local retryAt = 0
local retryUntil = 0
local clock = 0

local function load()
    local f = io.open(CONFIG, "r")
    if not f then return end
    local text = f:read("*a")
    f:close()
    local ok, data = pcall(json.decode, text)
    if ok and type(data) == "table" and type(data.slowMo) == "boolean" then
        settings.slowMo = data.slowMo
    end
end

local function save()
    local f = io.open(CONFIG, "w")
    if not f then return end
    f:write(json.encode(settings))
    f:close()
end

-- true when the service took the value; otherwise sets status to the reason and returns false
local function apply()
    local ok, res = pcall(function()
        local container = Game.GetScriptableServiceContainer()
        if not container then return "no service container yet" end
        local svc = container:GetService(CName.new(SERVICE))
        if not svc then return "service " .. SERVICE .. " not found (is r6\\scripts\\CyberslopThunderclap\\SlowMoSwitch.reds installed?)" end
        local now = svc:SetSlowMo(settings.slowMo)
        if now ~= settings.slowMo then return "service answered " .. tostring(now) end
        return true
    end)
    if ok and res == true then
        status = "applied"
        pending = false
        return true
    end
    status = ok and tostring(res) or ("error: " .. tostring(res))
    return false
end

local function applyOrRetry(reason)
    if apply() then
        print("[CyberslopThunderclap] slow motion on cast: " .. (settings.slowMo and "on" or "off") .. " (" .. reason .. ")")
    else
        pending = true
        retryAt = clock + 1
        retryUntil = clock + 120
    end
end

registerForEvent("onInit", function()
    load()
    applyOrRetry("launch")
end)

registerForEvent("onUpdate", function(dt)
    clock = clock + (dt or 0)
    if not pending or clock < retryAt then return end
    retryAt = clock + 1
    if apply() then
        print("[CyberslopThunderclap] slow motion on cast: " .. (settings.slowMo and "on" or "off") .. " (applied after retry)")
    elseif clock > retryUntil then
        pending = false
        print("[CyberslopThunderclap] could not set slow motion: " .. status)
    end
end)

registerForEvent("onOverlayOpen", function() overlayOpen = true end)
registerForEvent("onOverlayClose", function() overlayOpen = false end)

registerForEvent("onDraw", function()
    if not overlayOpen then return end
    if ImGui.Begin("Cyberslop Thunderclap", ImGuiWindowFlags.AlwaysAutoResize) then
        local value, changed = ImGui.Checkbox("Slow motion on cast", settings.slowMo)
        if changed then
            settings.slowMo = value
            save()
            applyOrRetry("window")
        end
        ImGui.TextDisabled("10 % speed for 0.5 s when the hack lands")
        if status ~= "applied" and status ~= "" then
            ImGui.TextColored(1, 0.4, 0.4, 1, status)
        end
    end
    ImGui.End()
end)
