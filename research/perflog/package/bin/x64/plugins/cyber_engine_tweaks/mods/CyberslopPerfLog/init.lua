-- Cyberslop PerfLog 1.0.1 (2026-11-22)
-- Always-on, lightweight performance log for normal play. Answers later, from the log: when and where did the game
-- hitch, what was V doing (on foot / vehicle / combat / menu), and were the hitches Lua garbage-collector stalls
-- (all CET mods share one Lua state) or something else (engine, redscript, native plugins, GPU).
--
-- Cost: per frame a few arithmetic operations, one collectgarbage("count") and one histogram increment; no game
-- calls, no allocations. Once a second (only unpaused and in game) player / vehicle / combat / position reads in a
-- pcall. One buffered file append every 30 s. No hooks, no game objects kept between calls.
--
-- File: perf-<launch time>.csv in this folder (the 30 newest are kept). Analyse with
--   python -I -X utf8 tools\perf_report.py (in the research folder of this probe)
-- Line types (first column):
--   W  30 s window: time, uptime, seconds per context, frames, fps, p50/p95/p99/worst frame ms, hitches, hitch ms,
--      GC cycles, GC-coinciding hitches + their ms, heap min / end MB, allocation KB/s, position x/y, stalls > 1 s
--   H  one hitch >= 50 ms (max 400 per launch): time, uptime, frame ms, context, gc 0/1, heap MB, x, y
--   S  context change (max 3000 per launch): time, uptime, old context, new context, x, y
--   I  info (launch, session start, notes)

local VERSION = "1.0.1"
local WINDOW = 30.0            -- seconds per W line
local EVENT_MIN_MS = 50        -- H lines for hitches at least this long
local MAX_H = 400
local MAX_S = 3000
local KEEP_FILES = 30
local STALL_MS = 1000          -- frames this long are loading screens / alt-tab, kept out of the frame stats
local GC_DROP_KB = 32          -- heap falling by more than this between frames = GC sweep running

-- state (one table keeps the main chunk small)
local P = {
    file = nil, buf = {}, nbuf = 0, nH = 0, nS = 0,
    uptime = 0, winT = 0, ctxT = 0,
    hist = {}, frames = 0, worst = 0, hitches = 0, hitchMs = 0, stalls = 0,
    gcCycles = 0, gcHitches = 0, gcHitchMs = 0, prevHeap = nil, declining = false,
    heapMin = math.huge, alloc = 0,
    base = 16.7,               -- typical frame ms (hitch baseline): moving average, each frame clipped to 2x
    ctx = "pre", secs = { foot = 0, veh = 0, combat = 0, menu = 0, pre = 0 },
    x = 0, y = 0, started = false,
}
for i = 0, 250 do P.hist[i] = 0 end

local function now() return os.date("%Y-%m-%d %H:%M:%S") end

local function push(line)
    P.nbuf = P.nbuf + 1
    P.buf[P.nbuf] = line
end

local function flush()
    if P.nbuf == 0 or not P.file then return end
    local f = io.open(P.file, "a")
    if f then
        f:write(table.concat(P.buf, "\n", 1, P.nbuf), "\n")
        f:close()
    end
    for i = P.nbuf, 1, -1 do P.buf[i] = nil end
    P.nbuf = 0
end

local function percentile(q)
    local target = P.frames * q
    local acc = 0
    for i = 0, 250 do
        acc = acc + P.hist[i]
        if acc >= target then return i + 0.5 end
    end
    return 250
end

local function closeWindow()
    if P.frames > 0 then
        local p50, p95, p99 = percentile(0.50), percentile(0.95), percentile(0.99)
        local s = P.secs
        push(string.format("W,%s,%.0f,%.0f,%.0f,%.0f,%.0f,%.0f,%d,%.1f,%.1f,%.1f,%.1f,%.1f,%d,%.0f,%d,%d,%.0f,%.1f,%.1f,%.0f,%.0f,%.0f,%d",
            now(), P.uptime, s.foot, s.veh, s.combat, s.menu, s.pre, P.frames, P.frames / math.max(P.winT, 0.001),
            p50, p95, p99, P.worst, P.hitches, P.hitchMs, P.gcCycles, P.gcHitches, P.gcHitchMs,
            (P.heapMin < math.huge and P.heapMin or 0) / 1024, (P.prevHeap or 0) / 1024, P.alloc / math.max(P.winT, 0.001),
            P.x, P.y, P.stalls))
    end
    for i = 0, 250 do P.hist[i] = 0 end
    P.frames, P.worst, P.hitches, P.hitchMs, P.stalls = 0, 0, 0, 0, 0
    P.gcCycles, P.gcHitches, P.gcHitchMs, P.heapMin, P.alloc = 0, 0, 0, math.huge, 0
    for k in pairs(P.secs) do P.secs[k] = 0 end
    P.winT = 0
    flush()
end

local function sampleContext()
    local srh = Game.GetSystemRequestsHandler()
    local new
    if not srh or srh:IsPreGame() then
        new = "pre"
    elseif srh:IsGamePaused() then
        new = "menu"
    else
        local player = Game.GetPlayer()
        if not player then
            new = "pre"
        else
            if Game.GetMountedVehicle(player) then
                new = "veh"
            elseif player:IsInCombat() then
                new = "combat"
            else
                new = "foot"
            end
            local pos = player:GetWorldPosition()
            P.x, P.y = pos.x, pos.y
            if not P.started then
                P.started = true
                push("I," .. now() .. string.format(",%.0f,session start", P.uptime))
            end
        end
    end
    if new ~= P.ctx then
        if P.nS < MAX_S then
            P.nS = P.nS + 1
            push(string.format("S,%s,%.1f,%s,%s,%.0f,%.0f", now(), P.uptime, P.ctx, new, P.x, P.y))
        end
        if new == "pre" then P.started = false end
        P.ctx = new
    end
end

local function prune()
    local ok, list = pcall(dir, ".")
    if not ok or type(list) ~= "table" then return end
    local names = {}
    for _, e in ipairs(list) do
        local n = e.name
        if type(n) == "string" and n:match("^perf%-%d+%-%d+%.csv$") then names[#names + 1] = n end
    end
    table.sort(names)
    for i = 1, #names - KEEP_FILES do pcall(os.remove, names[i]) end
end

registerForEvent("onInit", function()
    prune()
    P.file = "perf-" .. os.date("%Y%m%d-%H%M%S") .. ".csv"
    push("# Cyberslop PerfLog " .. VERSION .. " | W/H/S/I line types: see init.lua header")
    push("I," .. now() .. ",0,launch")
    flush()
end)

registerForEvent("onUpdate", function(dt)
    if not dt or dt <= 0 then return end
    local ms = dt * 1000
    P.uptime = P.uptime + dt
    P.winT = P.winT + dt
    P.secs[P.ctx] = P.secs[P.ctx] + dt

    -- Lua heap: GC cycle detection (sweep = heap falling), allocation estimate, live-heap floor
    local heap = collectgarbage("count")
    local gcFrame = false
    local prev = P.prevHeap
    if prev then
        if heap < prev - GC_DROP_KB then
            if not P.declining then
                P.declining = true
                P.gcCycles = P.gcCycles + 1
                gcFrame = true
            end
        elseif heap > prev then
            P.declining = false
            P.alloc = P.alloc + (heap - prev)
        end
    end
    P.prevHeap = heap
    if heap < P.heapMin then P.heapMin = heap end

    if ms >= STALL_MS then
        P.stalls = P.stalls + 1
    else
        P.frames = P.frames + 1
        local bin = math.floor(ms)
        if bin > 250 then bin = 250 end
        P.hist[bin] = P.hist[bin] + 1
        if ms > P.worst then P.worst = ms end
        local base = P.base
        P.base = base + ((ms < base * 2 and ms or base * 2) - base) * 0.05
        if ms >= base * 2.5 and ms >= base + 18 then
            P.hitches = P.hitches + 1
            P.hitchMs = P.hitchMs + ms
            if gcFrame then
                P.gcHitches = P.gcHitches + 1
                P.gcHitchMs = P.gcHitchMs + ms
            end
            if ms >= EVENT_MIN_MS and P.nH < MAX_H then
                P.nH = P.nH + 1
                push(string.format("H,%s,%.1f,%.1f,%s,%d,%.1f,%.0f,%.0f", now(), P.uptime, ms, P.ctx,
                    gcFrame and 1 or 0, heap / 1024, P.x, P.y))
            end
        end
    end

    P.ctxT = P.ctxT + dt
    if P.ctxT >= 1.0 then
        P.ctxT = 0
        local ok, err = pcall(sampleContext)
        if not ok and P.nS < MAX_S then
            P.nS = P.nS + 1
            push("I," .. now() .. string.format(",%.0f,context read failed: %s", P.uptime, tostring(err):gsub(",", ";")))
        end
    end

    if P.winT >= WINDOW then closeWindow() end
end)

registerForEvent("onShutdown", function()
    closeWindow()
    push("I," .. now() .. string.format(",%.0f,shutdown", P.uptime))
    flush()
end)

return { version = VERSION, state = P }
