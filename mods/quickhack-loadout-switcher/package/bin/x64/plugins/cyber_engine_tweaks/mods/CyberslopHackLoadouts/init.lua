-- Cyberslop Hack Loadouts 1.0.2 (2026-11-28)
-- CET window + hotkeys that load Quickhack Loadouts' saved deck loadouts without opening the inventory.
-- Saving / naming stays in the inventory menu (Quickhack Loadouts). All game calls go through
-- CyberslopHackLoadoutsSystem (r6\scripts\CyberslopHackLoadouts) and run in onUpdate, never in onDraw.
-- 1.0.1: load result codes from redscript (busy / already active / blocked), inGame cleared on HUD teardown,
-- window says why it has nothing to show.

local mod = { version = '1.0.2' }
local overlay = false
local inGame = false
local pending = nil        -- { kind = 'load', index = i, notify = bool } or { kind = 'step', step = +-1, notify = true }
-- state: 'wait' (no read yet), 'nosystem', 'noplayer', 'error', 'ok'
local cache = { state = 'wait', rows = {}, active = -1, deck = false, age = 99, busy = false, msg = nil, msgAge = 0 }

-- CyberslopHackLoadoutsResult codes
local LOADED, ALREADY, BUSY, EMPTY, NODECK, BLOCKED, NOPLAYER = 0, 1, 2, 3, 4, 5, 6
local resultText = {
    [ALREADY] = 'already loaded',
    [BUSY] = 'swap still running',
    [EMPTY] = 'loadout empty',
    [NODECK] = 'no cyberdeck',
    [BLOCKED] = 'not now (upload, quickhack panel or pause)',
    [NOPLAYER] = 'no player',
}

local debugOn = false      -- Mod Settings "Debug log" ([CyberslopHackLoadouts.CyberslopHackLoadoutsSettings] debugLog)
local lastSig = nil        -- debug: rows signature last logged

local function log(text)
    print('[CyberslopHackLoadouts] ' .. text)
    if debugOn and spdlog then pcall(spdlog.info, '[CyberslopHackLoadouts] ' .. text) end
end

local function dbg(text)
    if debugOn then log(text) end
end

local function system()
    local ok, sys = pcall(function()
        return Game.GetScriptableSystemsContainer():Get('CyberslopHackLoadouts.CyberslopHackLoadoutsSystem')
    end)
    if ok and sys ~= nil then return sys end
    return nil
end

local function readDebug(sys)
    local ok, on = pcall(function() return sys:DebugOn() end)
    local was = debugOn
    debugOn = ok and on == true
    if debugOn and not was then log('debug log on (' .. mod.version .. ')'); lastSig = nil end
end

local function refresh(sys)
    local ok, err = pcall(function()
        if not sys:HasSystem() then cache.state = 'nosystem'; return end
        if not sys:HasPlayer() then cache.state = 'noplayer'; return end
        local rows = {}
        local n = sys:Count()
        for i = 0, n - 1 do
            rows[#rows + 1] = {
                index = i,
                title = sys:Title(i),
                saved = sys:IsSaved(i),
                count = sys:HackCount(i),
                list = sys:HackList(i),
            }
        end
        cache.rows = rows
        cache.active = sys:ActiveIndex()
        cache.deck = sys:HasDeck()
        cache.busy = sys:IsBusy()
        cache.state = 'ok'
        if debugOn then
            local parts = { 'deck=' .. tostring(cache.deck), 'active=' .. tostring(cache.active + 1) }
            for _, r in ipairs(rows) do
                local list = (r.list or ''):gsub('\n', ',')
                parts[#parts + 1] = string.format('%d:%s:%s:%d:%s', r.index + 1, r.title, tostring(r.saved), r.count, list)
            end
            local sig = table.concat(parts, ' | ')
            if sig ~= lastSig then
                lastSig = sig
                log('window rows: ' .. sig)
                sys:DumpLoadouts()   -- per-loadout programs via FTLog
            end
        end
    end)
    if not ok then cache.state = 'error'; log('refresh failed: ' .. tostring(err)) end
    if cache.state ~= 'ok' then dbg('refresh: state ' .. cache.state) end
end

local function run(sys, job)
    local ok, err = pcall(function()
        local index, result
        if job.kind == 'load' then
            index = job.index
            result = sys:Load(index)
        else
            index = sys:LoadNext(job.step)
            result = sys:LastResult()
            if index < 0 and result == EMPTY then
                if not sys:HasDeck() then result = NODECK end
            end
        end
        dbg(string.format('%s %s -> index %s, result %s (%s)', job.kind,
            tostring(job.index and job.index + 1 or job.step), tostring(index + 1), tostring(result),
            result == LOADED and 'loaded' or (resultText[result] or '?')))
        local text
        if result == LOADED then
            text = 'Deck: ' .. sys:Title(index)
        elseif result == ALREADY and index >= 0 then
            text = 'Deck: ' .. sys:Title(index) .. ' (' .. resultText[ALREADY] .. ')'
        else
            text = 'Deck: ' .. (resultText[result] or ('result ' .. tostring(result)))
        end
        if job.notify then
            sys:Notify(text)
        elseif result ~= LOADED then
            cache.msg = text; cache.msgAge = 0
        end
    end)
    if not ok then log('load failed: ' .. tostring(err)) end
end

local function queueLoad(i, notify)
    if inGame then pending = { kind = 'load', index = i, notify = notify } end
end

local function queueStep(step)
    if inGame then pending = { kind = 'step', step = step, notify = true } end
end

registerHotkey('CyberslopHackLoadoutsNext', 'Next quickhack loadout', function() queueStep(1) end)
registerHotkey('CyberslopHackLoadoutsPrev', 'Previous quickhack loadout', function() queueStep(-1) end)
for i = 1, 6 do
    registerHotkey('CyberslopHackLoadouts' .. i, 'Quickhack loadout ' .. i, function() queueLoad(i - 1, true) end)
end

registerForEvent('onInit', function()
    inGame = Game.GetPlayer() ~= nil
    Observe('QuestTrackerGameController', 'OnInitialize', function() inGame = true end)
    -- the HUD goes away on quit-to-menu and on loads; the player can still exist for a moment then
    Observe('QuestTrackerGameController', 'OnUninitialize', function() inGame = false; pending = nil end)
    log('loaded ' .. mod.version)
end)

registerForEvent('onOverlayOpen', function() overlay = true; cache.age = 99; cache.state = 'wait'; cache.msg = nil end)
registerForEvent('onOverlayClose', function() overlay = false end)

registerForEvent('onUpdate', function(dt)
    if not inGame then pending = nil; return end
    if pending == nil and not overlay then return end
    local sys = system()
    if not sys then pending = nil; cache.state = 'nosystem'; return end
    if pending ~= nil then
        local job = pending
        pending = nil
        readDebug(sys)
        run(sys, job)
        cache.age = 0.6   -- the swap finishes over the next frames; re-read soon after
    end
    if overlay then
        cache.age = cache.age + dt
        if cache.msg then
            cache.msgAge = cache.msgAge + dt
            if cache.msgAge > 3 then cache.msg = nil end
        end
        if cache.age >= 0.75 then
            cache.age = 0
            readDebug(sys)
            refresh(sys)
        end
    end
end)

registerForEvent('onDraw', function()
    if not overlay then return end
    if ImGui.Begin('Hack Loadouts', ImGuiWindowFlags.AlwaysAutoResize) then
        if not inGame or cache.state == 'noplayer' then
            ImGui.Text('Load a save first.')
        elseif cache.state == 'wait' then
            ImGui.Text('Reading loadouts...')
        elseif cache.state == 'nosystem' then
            ImGui.Text('Quickhack Loadouts not found.')
        elseif cache.state == 'error' then
            ImGui.Text('Could not read loadouts (see CET log).')
        elseif not cache.deck then
            ImGui.Text('No cyberdeck equipped.')
        else
            for _, row in ipairs(cache.rows) do
                local label = string.format('%d  %s', row.index + 1, row.title)
                if row.saved then
                    label = label .. string.format('  (%d)', row.count)
                else
                    label = label .. '  (empty)'
                end
                local active = row.index == cache.active
                if active then
                    ImGui.PushStyleColor(ImGuiCol.Button, 0.55, 0.12, 0.12, 1.0)
                end
                if not row.saved then ImGui.BeginDisabled(true) end
                if ImGui.Button(label .. '##csqhl' .. row.index, 260, 0) then
                    queueLoad(row.index, false)
                end
                if not row.saved then ImGui.EndDisabled() end
                if active then ImGui.PopStyleColor(1) end
                if row.saved and row.list ~= '' and ImGui.IsItemHovered(ImGuiHoveredFlags.AllowWhenDisabled) then
                    ImGui.SetTooltip(row.list)
                end
            end
            ImGui.Separator()
            if cache.busy then
                ImGui.Text('Swapping...')
            elseif cache.active >= 0 then
                ImGui.Text('Active: ' .. tostring(cache.active + 1))
            else
                ImGui.Text('Active: none (custom)')
            end
            if cache.msg then ImGui.Text(cache.msg) end
            ImGui.TextDisabled('Save / rename in the inventory deck menu.')
        end
    end
    ImGui.End()
end)

return mod
