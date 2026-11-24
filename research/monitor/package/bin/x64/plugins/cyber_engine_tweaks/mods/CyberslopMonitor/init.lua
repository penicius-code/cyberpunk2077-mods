-- CyberslopMonitor 2.0.0 (2026-11-07): game-side half of a set of diagnostics (the log readers are separate).
-- Read only: no game state is changed. Writes CyberslopMonitor.log next to this file (appended per launch, rotated to
-- .1 past 5 MB at launch). Line format is the 1.x one ("HH:MM:SS  <seconds since init>  KIND ..."), so
-- the existing log readers keep working; 2.0 adds kinds they ignore.
--
-- 2.0.0 adds to 1.1.0:
--   state    every 10 s: position, district, police heat + spawned units, NPC census within 60 m (all / AI = alive
--            non-crowd / in combat / crowd / dead), rain, global time dilation, game clock, vehicle / combat PSM,
--            CET Lua heap + net growth per s + GC drops, and an epoch anchor (wall clock to the frame) so the
--            sidecar can line these lines up with PresentMon frames and the other logs to the millisecond
--   qhwheel  the in-world quickhack wheel (scanner) open / close, measured like a menu round trip (it slows time)
--   sub      itemmode/<equipment area> inside the inventory (the cyberdeck / quickhack screen is
--            itemmode/SystemReplacementCW), and back to inventory_screen when the item mode closes
--   event    time dilation changes (value + active), and a "timedilation STUCK" warning when the game stays
--            slowed for 20 s in the world with no menu or quickhack wheel open
--   tick     every 10 s instead of 30 s
--   writes   enter / leave / settle / load / event / photo / qhwheel lines are written at once (crash evidence),
--            everything else at least every 5 s
--
-- Line kinds (every line: "HH:MM:SS  <seconds since init>  KIND ...")
--   init     launch stamp, settings, hook failures
--   enter    the world was left for a menu scenario: kind, the frames right before, context
--   sub      a submenu inside the open scenario (inventory_screen, world_map, cyberware_equip, itemmode/... )
--   leave    back in the world: in-menu stats; LOG_AFTER_S later a "settle" line with the frame list
--   settle   frames after a menu close: list in ms, close hitch, lost ms vs the gameplay baseline, settle time
--   load     loading screen start / end, session attach / detach
--   SPIKE    one gameplay frame over SPIKE_MS (max SPIKE_BUDGET lines per 10 s), with context
--   tick     every TICK_S seconds: frame stats of the period, Lua heap, state
--   state    every TICK_S seconds: world context (see above)
--   photo    photo mode open / close
--   overlay  CET overlay open / close
--   event    pause on / off, time dilation
--   shutdown totals
-- 2.1.0 (2026-11-08): `combat` line once per second while something happens to NPCs (status effects applied:
--   count, new vs re-applied, distinct NPCs, top effect IDs; hits: count, distinct NPCs, top attack IDs; deaths,
--   defeats, quickhack uploads started / completed). Written at once (crash evidence for the heap-corruption CTD family
--   that follows AoE / poison / DoT hits on several NPCs). Time dilation values below 0 (no world yet) are ignored.
-- 2.1.1 (2026-11-08): zoom / aim / FOV polled with pause (0.25 s); every change is an `event zoom` line written at once,
--   and `combat` lines carry the current zoom. A heap CTD in testing came while zooming (aim + scroll) into NPCs that
--   Contagion had just downed.
-- 2.1.2 (2026-11-08): load-safety. 2.1.1 crashed the game on a save load from the pause menu (exe+0x1348bd5,
--   READ 0x280): the 10 s state line called PreventionSpawnSystem.GetNumberOfSpawnedPreventionUnits while the world
--   was being torn down. Now every world read (state line, census, zoom, time dilation, PSM context) runs only while
--   worldSafe(): a session has begun and no load / exit has been requested since. Load requests are caught on every
--   2.31 path (Load Game menu, death screen "load last save", quickload, and pause turning off while a menu scenario
--   is still open = load / exit to main menu from the pause menu); the gate opens again at the next session begin.
--   The police unit count (the crashing native) is gone; heat stays.
local VERSION = "2.1.2"
local CFG = {
  SPIKE_MS = 100,        -- gameplay frame counted as a spike (real frames on the test PC run 25 to 55 ms before frame generation)
  SPIKE_BUDGET = 20,     -- SPIKE lines per 10 s
  TICK_S = 10,           -- tick + state cadence
  LOG_AFTER_S = 5,       -- seconds of frames captured after every return to the world
  RING = 40,             -- frames remembered before a transition
  SETTLE_FACTOR = 1.5,   -- settled = SETTLE_N frames in a row under baseline * SETTLE_FACTOR (and under SPIKE_MS)
  SETTLE_N = 15,
  LOG_FILE = "CyberslopMonitor.log",
  FLUSH_S = 5,           -- buffered lines are written at least this often
  FLUSH_LINES = 40,      -- or as soon as this many are waiting
  POLL_S = 0.25,         -- pause + time dilation check interval
  ROTATE_BYTES = 5 * 1024 * 1024,
  CENSUS_M = 60,         -- NPC census radius (m)
  CENSUS_MAX = 200,      -- target parts looked at per census
  TD_STUCK_S = 20,       -- time dilation active this long in the world (no menu / wheel) = STUCK warning
  COMBAT_S = 1,          -- combat activity line cadence (only written when something happened)
  COMBAT_TOP = 5,        -- effect / attack IDs listed per line
}

local S = {
  t0 = os.clock(), lastClock = nil, frames = 0, spikes = 0, menus = 0,
  ring = {}, ringPos = 0,                 -- last CFG.RING frame wall times (ms)
  tick = { n = 0, sum = 0, max = 0, over = 0, list = {}, t = 0 },
  baseline = 40,                          -- median gameplay frame of the last tick in the world (ms)
  inWorld = false, scenario = "startup", sub = "-",
  tr = nil,                               -- open transition {kind, t0, n, sum, max, over, openFrames, subs}
  after = nil,                            -- capture after a return to the world
  paused = false, overlay = false, photo = false, loading = nil, attached = false, wheel = false,
  spikeBudget = CFG.SPIKE_BUDGET, budgetReset = 0, lastEvent = "-",
  hookFails = {},
  epoch = nil, epochRel = 0,              -- last os.time() edge and its seconds-since-init
  lastKB = nil, growKB = 0, gcDrops = 0,  -- Lua heap net growth / GC drops since the last tick
  td = { value = 1, active = false, since = nil, stuckLogged = false, mode = nil, dead = false },
  census = { dead = false, fails = 0 },
  session = false,                        -- a world session has begun (MenuScenario_Idle entered from None)
  unload = nil,                           -- now() of a load / exit request; world reads stop until the next session
}

local function now() return os.clock() - S.t0 end

-- World reads (natives on game systems / the player) only while this is true. During a load or an exit to the main
-- menu the systems are torn down under CET's onUpdate, and a native call then reads freed memory (2.1.1 crash).
-- Not while paused either: a load is requested from a paused menu, and the pause flag drops in the same frame.
-- (The loading screen is not a gate: fast travel shows one without a new session, and its "hidden" hook never fires.)
local function worldSafe()
  return S.session and not S.unload and not S.paused
end

local buf, bufN, lastFlush = {}, 0, 0

local function flush()
  lastFlush = os.clock()
  if bufN == 0 then return end
  local f = io.open(CFG.LOG_FILE, "a")
  if f then
    f:write(table.concat(buf))
    f:close()
  end
  buf, bufN = {}, 0
end

local IMMEDIATE = { load = true, ente = true, leav = true, sett = true, even = true, phot = true, qhwh = true, shut = true,
                    comb = true }

local function log(fmt, ...)
  local ok, text = pcall(string.format, fmt, ...)
  bufN = bufN + 1
  buf[bufN] = string.format("%s %9.3f  ", os.date("%H:%M:%S"), now()) .. (ok and text or ("format error: " .. tostring(text))) .. "\n"
  if bufN >= CFG.FLUSH_LINES or IMMEDIATE[fmt:sub(1, 4)] then flush() end
end

-- a load / exit was requested: stop world reads now (written at once, so the last line before a load crash says so)
-- soft = inferred from the pause flag (undone if the world resumes from a menu); explicit hooks are never undone
local function markUnload(why, soft)
  if S.unload then
    if not soft then S.unloadSoft = false end
    return
  end
  S.unload, S.unloadSoft = now(), soft == true
  log("load    %s requested: world reads off until the next session | scenario=%s sub=%s", why, S.scenario, S.sub)
end

-- once per launch: keep one older log, start fresh past 5 MB
do
  local f = io.open(CFG.LOG_FILE, "r")
  if f then
    local size = f:seek("end")
    f:close()
    if size and size > CFG.ROTATE_BYTES then
      os.remove(CFG.LOG_FILE .. ".1")
      os.rename(CFG.LOG_FILE, CFG.LOG_FILE .. ".1")
    end
  end
end

local function cname(x)
  local ok, s = pcall(function() return NameToString(x) end)
  if ok and s and s ~= "" then return s end
  local ok2, s2 = pcall(tostring, x)
  return ok2 and s2 or "?"
end

local function enumName(x)
  local ok, s = pcall(tostring, x)
  if not ok or not s then return "?" end
  -- CET prints enums like "gamedataEquipmentArea : SystemReplacementCW (40)"
  return s:match(":%s*([%w_]+)") or s:match("([%w_]+)%s*%(") or s
end

local function luaKB() return math.floor(collectgarbage("count")) end

local function median(t)
  if #t == 0 then return 0 end
  local c = {}
  for i = 1, #t do c[i] = t[i] end
  table.sort(c)
  return c[math.floor((#c + 1) / 2)]
end

local function pct(t, p)
  if #t == 0 then return 0 end
  local c = {}
  for i = 1, #t do c[i] = t[i] end
  table.sort(c)
  return c[math.max(1, math.min(#c, math.ceil(#c * p)))]
end

local function joinInts(t)
  local o = {}
  for i = 1, #t do o[i] = string.format("%.0f", t[i]) end
  return table.concat(o, " ")
end

local function ringList()
  local o, n = {}, #S.ring
  for i = 1, n do
    o[i] = S.ring[((S.ringPos + i - 1) % n) + 1]
  end
  return o
end

-- context ---------------------------------------------------------------------------------------------------

local function isPaused()
  local ok, p = pcall(function()
    local h = Game.GetSystemRequestsHandler()
    return h and h:IsGamePaused()
  end)
  return ok and p == true
end

local function psm()
  local veh, combat, loco = -1, -1, -1
  if not worldSafe() then return veh, combat, loco end
  pcall(function()
    local player = Game.GetPlayer()
    if not player then return end
    local bb = player:GetPlayerStateMachineBlackboard()
    local d = GetAllBlackboardDefs().PlayerStateMachine
    veh = bb:GetInt(d.Vehicle)
    combat = bb:GetInt(d.Combat)
    loco = bb:GetInt(d.Locomotion)
  end)
  return veh, combat, loco
end

local function context()
  local veh, combat, loco = psm()
  return string.format("veh=%d combat=%d loco=%d paused=%s overlay=%s luaKB=%d", veh, combat, loco,
    tostring(S.paused), tostring(S.overlay), luaKB())
end

local function stateStr()
  return string.format("scenario=%s sub=%s", S.scenario, S.sub)
end

-- Pause state + load detection. Called by the 0.25 s poll and right before every batch of world reads, so a load
-- requested since the last poll is seen before the reads. Pause turning off while a menu scenario is still open
-- (MenuScenario_PauseMenu ...) is a load or an exit to the main menu: 16 of 16 cases in the 2.x log; a normal
-- resume enters MenuScenario_Idle first, so the scenario is already "world" when the pause drops.
local function checkPause()
  local p = isPaused()
  if p == S.paused then return end
  S.paused = p
  log("event   %-28s | %s", p and "pause on" or "pause off", stateStr())
  if not p and S.session and S.scenario ~= "world" and S.scenario ~= "QuickhackWheel" and S.scenario ~= "PhotoMode" then
    markUnload("pause dropped inside " .. S.scenario .. " (load / exit)", true)
  end
end

-- time dilation (global): the quickhack wheel, Sandevistan, Kerenzikov, finishers and some mods set it.
-- The working call form is found once and cached; if none works the probe stops asking.
local TD_FORMS = {
  function(ts) return ts:IsTimeDilationActive(), ts:GetActiveTimeDilation() end,
  function(ts) return ts:IsTimeDilationActive(CName.new("")), ts:GetActiveTimeDilation(CName.new(""), false) end,
}

local function readTD()
  if S.td.dead or not worldSafe() then return nil end
  local ts = Game.GetTimeSystem()
  if not ts then return nil end
  if S.td.mode then
    local ok, a, v = pcall(TD_FORMS[S.td.mode], ts)
    if ok then return a == true, tonumber(v) or 1 end
    return nil
  end
  for i = 1, #TD_FORMS do
    local ok, a, v = pcall(TD_FORMS[i], ts)
    if ok then
      S.td.mode = i
      return a == true, tonumber(v) or 1
    end
  end
  S.td.dead = true
  log("init    time dilation read failed in both call forms; td not logged")
  return nil
end

-- zoom / aim / FOV (Kiroshi zoom on aim + scroll)
S.zoom = { level = -1, aim = -1, fov = -1, dead = false }

local function readZoom()
  local lvl, aim, fov = -1, -1, -1
  local ok = pcall(function()
    local player = Game.GetPlayer()
    if not player then return end
    local bb = player:GetPlayerStateMachineBlackboard()
    local d = GetAllBlackboardDefs().PlayerStateMachine
    lvl = bb:GetFloat(d.ZoomLevel)
    aim = bb:GetInt(d.UpperBody)
  end)
  pcall(function() fov = Game.GetPlayer():GetFPPCameraComponent():GetFOV() end)
  return ok, lvl, aim, fov
end

local function pollZoom()
  local z = S.zoom
  if z.dead or not S.inWorld or not worldSafe() then return end
  local ok, lvl, aim, fov = readZoom()
  if not ok then
    z.dead = true
    log("init    zoom read failed; zoom not logged")
    return
  end
  if math.abs(lvl - z.level) >= 0.05 or aim ~= z.aim or math.abs(fov - z.fov) >= 1 then
    if z.level >= 0 then  -- skip the first reading
      log("event   zoom %.2f aim=%d fov=%.1f (was %.2f / %d / %.1f) | %s", lvl, aim, fov, z.level, z.aim, z.fov, stateStr())
    end
    z.level, z.aim, z.fov = lvl, aim, fov
  end
end

local function pollTD()
  local active, v = readTD()
  if active == nil or v < 0 then return end  -- -1 = no world / player yet
  local td = S.td
  if active ~= td.active or math.abs(v - td.value) >= 0.05 then
    log("event   timedilation %.2f active=%s | %s | wheel=%s", v, tostring(active), stateStr(), tostring(S.wheel))
    td.active, td.value = active, v
    if active and not td.since then td.since = now() end
    if not active then td.since, td.stuckLogged = nil, false end
  end
  if active and td.since and not td.stuckLogged and S.inWorld and not S.tr and not S.wheel and not S.paused
      and now() - td.since >= CFG.TD_STUCK_S then
    td.stuckLogged = true
    log("event   timedilation STUCK %.2f for %.0f s in the world with no menu or quickhack wheel open | %s",
      v, now() - td.since, context())
  end
end

-- NPC census within CENSUS_M: the AI load around V. One targeting query per tick.
local function enumVal(enumType, name, fallback)
  local ok, v = pcall(function() return Enum.new(enumType, name) end)
  if ok and v ~= nil then return v end
  local ok2, v2 = pcall(function() return _G[enumType][name] end)
  if ok2 and v2 ~= nil then return v2 end
  return fallback
end

local function census()
  local c = S.census
  if c.dead or not worldSafe() then return nil end
  local res = nil
  local ok, err = pcall(function()
    local player = Game.GetPlayer()
    if not player then return end
    local ts = Game.GetTargetingSystem()
    if not ts then return end
    local q = TargetSearchQuery.new()
    q.testedSet = enumVal("TargetingSet", "Complete", 3)
    q.maxDistance = CFG.CENSUS_M
    q.filterObjectByDistance = true
    q.includeSecondaryTargets = false
    q.ignoreInstigator = true
    local a, b = ts:GetTargetParts(player, q)
    local parts = type(b) == "table" and b or (type(a) == "table" and a or nil)
    if parts == nil then
      local a2, b2 = ts:GetTargetParts(player, q, {})
      parts = type(b2) == "table" and b2 or (type(a2) == "table" and a2 or {})
    end
    local seen, n, ai, combat, crowd, dead, other = {}, 0, 0, 0, 0, 0, 0
    for i = 1, math.min(#parts, CFG.CENSUS_MAX) do
      local comp = TS_TargetPartInfo.GetComponent(parts[i])
      local ent = comp and comp:GetEntity()
      if ent then
        local key = tostring(ent:GetEntityID().hash)
        if not seen[key] then
          seen[key] = true
          local okN, isNPC = pcall(function() return ent:IsNPC() end)
          if okN and isNPC then
            n = n + 1
            local okD, isDead = pcall(function() return ent:IsDead() end)
            if okD and isDead then
              dead = dead + 1
            else
              local okC, isCrowd = pcall(function() return ent:IsCrowd() end)
              if okC and isCrowd then
                crowd = crowd + 1
              else
                ai = ai + 1
                local okK, inCombat = pcall(function() return NPCPuppet.IsInCombat(ent) end)
                if okK and inCombat then combat = combat + 1 end
              end
            end
          else
            other = other + 1
          end
        end
      end
    end
    res = string.format("npc=%d ai=%d incombat=%d crowd=%d dead=%d objs=%d", n, ai, combat, crowd, dead, other)
  end)
  if not ok then
    c.fails = c.fails + 1
    if c.fails >= 3 then
      c.dead = true
      log("init    NPC census disabled after 3 failures: %s", tostring(err))
    end
    return nil
  end
  return res
end

local function worldState()
  local parts = {}
  if not worldSafe() then
    return S.unload and "reads=off-unloading" or (S.loading and "reads=off-loading" or "reads=off-no-session")
  end
  pcall(function()
    local p = Game.GetPlayer()
    local pos = p and p:GetWorldPosition()
    if pos then parts[#parts + 1] = string.format("pos=%.1f,%.1f,%.1f", pos.x, pos.y, pos.z) end
  end)
  pcall(function()
    local ps = Game.GetScriptableSystemsContainer():Get("PreventionSystem")
    if ps then
      parts[#parts + 1] = "heat=" .. tostring(ps:GetHeatStageAsInt())
      local d = ps:GetCurrentDistrict()
      if d then parts[#parts + 1] = "district=" .. tostring(TDBID.ToStringDEBUG(d:GetDistrictID())):gsub("%s", "_") end
    end
  end)
  pcall(function()
    local w = Game.GetWeatherSystem()
    if w then parts[#parts + 1] = string.format("rain=%.2f", w:GetRainIntensity()) end
  end)
  pcall(function()
    local gt = Game.GetTimeSystem():GetGameTime()
    local okH, h = pcall(function() return GameTime.Hours(gt) end)    -- static native (self: GameTime)
    local okM, m = pcall(function() return GameTime.Minutes(gt) end)
    if not okH then h = gt:Hours() end
    if not okM then m = gt:Minutes() end
    parts[#parts + 1] = string.format("gametime=%02d:%02d", h, m)
  end)
  return table.concat(parts, " ")
end

-- combat activity (status effects / hits / deaths / uploads on NPCs), one line per second with activity -------

local idCache, idCacheN = {}, 0

local function recId(rec)
  -- TweakDB record -> "Group.Name" (cached by hash; ToStringDEBUG only once per ID)
  local ok, s = pcall(function()
    local id = rec:GetID()
    local key = tostring(id.hash) .. ":" .. tostring(id.length)
    local v = idCache[key]
    if not v then
      v = TDBID.ToStringDEBUG(id) or "?"
      if idCacheN < 2000 then idCache[key], idCacheN = v, idCacheN + 1 end
    end
    return v
  end)
  return ok and s or "?"
end

local function entKey(ent)
  local ok, k = pcall(function() return tostring(ent:GetEntityID().hash) end)
  return ok and k or "?"
end

local function newCombat()
  return { t0 = os.clock(), any = false, fx = 0, fxNew = 0, fxIds = {}, fxNpcs = {}, nFxNpcs = 0,
           hits = 0, hitIds = {}, hitNpcs = {}, nHitNpcs = 0, deaths = 0, defeated = 0, upStart = 0, upDone = 0 }
end
S.cb = newCombat()

local function topList(t)
  local arr = {}
  for k, n in pairs(t) do arr[#arr + 1] = { k, n } end
  table.sort(arr, function(a, b) return a[2] > b[2] end)
  local o = {}
  for i = 1, math.min(#arr, CFG.COMBAT_TOP) do o[i] = arr[i][1] .. ":" .. arr[i][2] end
  if #arr > CFG.COMBAT_TOP then o[#o + 1] = "+" .. (#arr - CFG.COMBAT_TOP) end
  return #o > 0 and table.concat(o, ",") or "-"
end

local function flushCombat()
  local cb = S.cb
  if cb.any then
    log("combat  fx=%d new=%d fxNpcs=%d hits=%d hitNpcs=%d deaths=%d defeated=%d upload=%d/%d zoom=%.2f aim=%d | fx %s | hits %s | %s",
      cb.fx, cb.fxNew, cb.nFxNpcs, cb.hits, cb.nHitNpcs, cb.deaths, cb.defeated, cb.upStart, cb.upDone,
      S.zoom.level, S.zoom.aim, topList(cb.fxIds), topList(cb.hitIds), stateStr())
  end
  S.cb = newCombat()
end

local function onNpcEffect(self, evt)
  local cb = S.cb
  cb.any = true
  cb.fx = cb.fx + 1
  local isNew = false
  pcall(function() isNew = evt.isNewApplication == true end)
  if isNew then cb.fxNew = cb.fxNew + 1 end
  local id = "?"
  pcall(function() id = recId(evt.staticData) end)
  cb.fxIds[id] = (cb.fxIds[id] or 0) + 1
  local k = entKey(self)
  if not cb.fxNpcs[k] then cb.fxNpcs[k], cb.nFxNpcs = true, cb.nFxNpcs + 1 end
end

local function onNpcHit(self, evt)
  local cb = S.cb
  cb.any = true
  cb.hits = cb.hits + 1
  local id = "?"
  pcall(function() id = recId(evt.attackData:GetAttackDefinition():GetRecord()) end)
  cb.hitIds[id] = (cb.hitIds[id] or 0) + 1
  local k = entKey(self)
  if not cb.hitNpcs[k] then cb.hitNpcs[k], cb.nHitNpcs = true, cb.nHitNpcs + 1 end
end

-- transitions -----------------------------------------------------------------------------------------------

local function beginTransition(kind)
  if S.tr then  -- a scenario switched straight into another one (hub -> vendor, map -> fast travel ...)
    S.tr.subs[#S.tr.subs + 1] = string.format("%s@%.2f", kind, now() - S.tr.t0)
    S.scenario = kind
    return
  end
  S.menus = S.menus + 1
  S.inWorld, S.scenario, S.sub = false, kind, "-"
  S.tr = { kind = kind, t0 = now(), n = 0, sum = 0, max = 0, over = 0, openMax = 0, subs = {}, luaKB = luaKB(),
           pre = ringList() }
  S.lastEvent = kind .. "@" .. string.format("%.3f", S.tr.t0)
  log("enter   %-28s | baseline=%.0f ms, frames before: %s | %s", kind, S.baseline, joinInts(S.tr.pre), context())
end

local function subMenu(name)
  S.sub = name
  if S.tr then
    S.tr.subs[#S.tr.subs + 1] = string.format("%s@%.2f", name, now() - S.tr.t0)
  end
  log("sub     %-28s | %s", name, stateStr())
end

local function endTransition(prev)
  local tr = S.tr
  S.inWorld, S.scenario, S.sub, S.tr = true, "world", "-", nil
  -- back in the same world from a menu: a load / exit was not happening after all (on a real load the next scenario
  -- event is the session begin from None, never a return from the pause menu)
  if S.unload and S.unloadSoft and not (prev and prev:find("+Load", 1, true)) then
    log("load    world resumed from %s %.1f s after the unload flag: false alarm, world reads back on", prev or "?",
      now() - S.unload)
    S.unload = nil
  end
  if not tr then
    log("leave   %-28s | no matching enter (session start?) | %s", prev or "?", context())
    S.after = { kind = prev or "?", t0 = now(), frames = {}, path = "-", luaKB = luaKB() }
    return
  end
  if prev and prev:find("+Load", 1, true) then tr.kind = prev end
  local dur = now() - tr.t0
  local path = #tr.subs > 0 and table.concat(tr.subs, ",") or "-"
  log("leave   %-28s | in menu %.1f s, %d frames, avg %.0f, max %.0f ms, over %d ms: %d, open hitch (first 10 frames) %.0f ms, path %s, luaKB %d -> %d | %s",
    tr.kind, dur, tr.n, tr.n > 0 and tr.sum / tr.n or 0, tr.max, CFG.SPIKE_MS, tr.over, tr.openMax, path, tr.luaKB, luaKB(), context())
  S.after = { kind = tr.kind, t0 = now(), frames = {}, path = path, luaKB = luaKB(), dur = dur }
end

local function finishAfter()
  local a = S.after
  S.after = nil
  local fr = a.frames
  if #fr == 0 then return end
  local mx, over, lost, settleMs, settled = 0, 0, 0, 0, false
  local run, acc = 0, 0
  local limit = math.max(S.baseline * CFG.SETTLE_FACTOR, CFG.SPIKE_MS)
  for i = 1, #fr do
    local w = fr[i]
    acc = acc + w
    if w > mx then mx = w end
    if w > CFG.SPIKE_MS then over = over + 1 end
    if w > limit then lost = lost + (w - S.baseline) end
    if w <= limit then
      run = run + 1
      if run == CFG.SETTLE_N and not settled then settled, settleMs = true, math.max(0, acc - w * CFG.SETTLE_N) end
    else
      run = 0
    end
  end
  local first3 = math.max(fr[1] or 0, fr[2] or 0, fr[3] or 0)
  log("settle  %-28s | close hitch (first 3) %.0f ms, max %.0f ms, over %d ms: %d, lost %.0f ms vs baseline %.0f, settled after %s, p50 %.0f, luaKB %d -> %d, path %s | frames: %s",
    a.kind, first3, mx, CFG.SPIKE_MS, over, lost, S.baseline, settled and string.format("%.0f ms", settleMs) or "never in window",
    median(fr), a.luaKB, luaKB(), a.path, joinInts(fr))
end

-- hooks -----------------------------------------------------------------------------------------------------

local function observe(cls, fn, cb)
  local ok, err = pcall(Observe, cls, fn, cb)
  if not ok then
    S.hookFails[#S.hookFails + 1] = cls .. "." .. fn
    log("init    hook failed %s.%s: %s", cls, fn, tostring(err))
  end
end

local function installHooks()
  -- world <-> any menu scenario (pause, hub, vendor, death, storage, fast travel, wardrobe, time skip, breach ...)
  observe("MenuScenario_Idle", "OnLeaveScenario", function(self, nextScenario)
    if S.tr and S.tr.kind == "QuickhackWheel" then  -- wheel open while a menu opens: close the wheel record first
      S.wheel = false
      endTransition("QuickhackWheel")
      S.after = nil
    end
    beginTransition(cname(nextScenario))
  end)
  observe("MenuScenario_Idle", "OnEnterScenario", function(self, prevScenario)
    local prev = cname(prevScenario)
    if prev == "None" then
      S.session, S.unload, S.loading = true, nil, nil
      log("load    world scenario started (session begin) | %s", context())
      if S.tr then
        endTransition(S.tr.kind .. "+Load")
      else
        S.inWorld, S.scenario, S.sub = true, "world", "-"
        S.after = { kind = "SessionStart", t0 = now(), frames = {}, path = "-", luaKB = luaKB() }
      end
      return
    end
    endTransition(prev)
  end)
  -- hub submenus: inventory_screen, world_map, cyberware_equip, crafting_main, quest_log, new_perks, phone ...
  observe("MenuScenario_HubMenu", "OnOpenMenu", function(self, menuName) subMenu(cname(menuName)) end)
  observe("MenuScenario_HubMenu", "OnEnterScenario", function(self)
    local ok, n = pcall(function() return cname(self.m_hubMenuInitData and self.m_hubMenuInitData.m_menuName) end)
    if ok and n and n ~= "?" and n ~= "None" and n ~= "" then subMenu(n) end
  end)
  observe("MenuScenario_HubMenu", "OnSwitchToTimeManager", function() subMenu("time_manager") end)
  -- inventory item modes: the cyberdeck (quickhack programs) screen is itemmode/SystemReplacementCW
  observe("InventoryItemModeLogicController", "SetupMode", function(self, displayData)
    local area = "?"
    pcall(function() area = enumName(displayData.m_equipmentArea) end)  -- InventoryItemDisplayData.m_equipmentArea
    subMenu("itemmode/" .. area)
  end)
  observe("InventoryItemModeLogicController", "RequestClose", function()
    if S.tr and S.sub:sub(1, 9) == "itemmode/" then subMenu("inventory_screen") end
  end)
  -- vendor tabs
  for name, label in pairs({ OnSwitchToVendor = "fullscreen_vendor", OnSwitchToRipperDoc = "ripperdoc",
                             OnSwitchToCrafting = "crafting_main", OnSwitchToGlamdoc = "glamdoc",
                             OnSwitchToCharacter = "new_perks", OnSwitchToInventory = "inventory_screen" }) do
    observe("MenuScenario_Vendor", name, function() subMenu("vendor/" .. label) end)
  end
  -- pause submenus
  for name, label in pairs({ OnSwitchToSettings = "Settings", OnSwitchToLoadGame = "LoadGame",
                             OnSwitchToSaveGame = "SaveGame", OnSwitchToDlc = "Dlc", OnSwitchToPauseMenu = "PauseMenu",
                             OnSwitchToBrightnessSettings = "Brightness", OnSwitchToHDRSettings = "HDR",
                             OnSwitchToControllerPanel = "Controller" }) do
    observe("MenuScenario_PauseMenu", name, function() subMenu("pause/" .. label) end)
  end
  -- pre-game (main menu) scenarios
  for _, cls in ipairs({ "MenuScenario_SingleplayerMenu", "MenuScenario_LoadGame", "MenuScenario_NewGame",
                         "MenuScenario_Settings", "MenuScenario_PreGameSubMenu", "MenuScenario_Credits" }) do
    observe(cls, "OnEnterScenario", function(self, prevScenario)
      S.session = false  -- main menu: no world
      log("load    %-28s | from %s | %s", cls, cname(prevScenario), context())
      S.scenario, S.sub = cls, "-"
    end)
  end
  -- load / exit requests (2.31 scripts): stop world reads before the world is torn down
  observe("LoadGameMenuGameController", "LoadGame", function() markUnload("save load (Load Game menu)") end)
  observe("LoadGameMenuGameController", "OnTransitionFinished", function() markUnload("save load (Load Game menu)") end)
  observe("DeathMenuGameController", "HandleMenuItemActivate", function() markUnload("death screen action") end)
  observe("gameuiInGameMenuGameController", "OnQuickLoadSavesReady", function(self, saves)
    local ok, n = pcall(function() return #saves end)
    if not ok or (n or 0) > 0 then markUnload("quickload") end
  end)
  -- loading screens and session attach / detach
  observe("LoadingScreenProgressBarController", "OnInitialize", function()
    S.loading = now()
    log("load    loading screen shown | %s | %s", stateStr(), context())
  end)
  observe("LoadingScreenProgressBarController", "OnUninitialize", function()
    log("load    loading screen hidden after %s | %s", S.loading and string.format("%.1f s", now() - S.loading) or "?", stateStr())
    S.loading = nil
  end)
  observe("PlayerPuppet", "OnGameAttached", function(self)
    local ok, isP = pcall(function() return self:IsPlayerControlled() end)
    if ok and isP == false then return end
    S.attached = true
    S.inWorld, S.scenario, S.sub, S.tr, S.wheel = true, "world", "-", nil, false
    log("load    player attached (session start)%s | %s", S.loading and string.format(", %.1f s after the loading screen appeared", now() - S.loading) or "", context())
    S.after = { kind = "SessionStart", t0 = now(), frames = {}, path = "-", luaKB = luaKB() }
  end)
  observe("PlayerPuppet", "OnDetach", function(self)
    local ok, isP = pcall(function() return self:IsPlayerControlled() end)
    if ok and isP == false then return end
    if not S.attached then return end
    S.attached = false
    log("load    player detached (session end: main menu, load, death reload) | %s | %s", stateStr(), context())
    S.tr, S.after, S.wheel = nil, nil, false
    S.scenario, S.inWorld = "no-session", false
  end)
  -- photo mode (no scenario of its own)
  observe("gameuiPhotoModeMenuController", "OnShow", function()
    S.photo = true
    log("photo   open | %s", context())
    beginTransition("PhotoMode")
  end)
  observe("gameuiPhotoModeMenuController", "OnHide", function()
    S.photo = false
    log("photo   close")
    if S.tr and S.tr.kind == "PhotoMode" then endTransition("PhotoMode") end
  end)
  -- ESC pause menu controller: catches the pause menu even if the scenario hook misses it
  observe("PauseMenuGameController", "OnInitialize", function()
    if not S.tr then beginTransition("PauseMenuController") end
  end)
  -- combat activity on NPCs (counted, written once per second with activity)
  observe("NPCPuppet", "OnStatusEffectApplied", onNpcEffect)
  observe("NPCPuppet", "OnHit", onNpcHit)
  observe("NPCPuppet", "OnDeath", function() local cb = S.cb; cb.any = true; cb.deaths = cb.deaths + 1 end)
  observe("ScriptedPuppet", "OnDefeated", function() local cb = S.cb; cb.any = true; cb.defeated = cb.defeated + 1 end)
  observe("ScriptedPuppet", "OnUploadProgressStateChanged", function(self, evt)
    local cb = S.cb
    cb.any = true
    local st = -1
    pcall(function() st = tonumber(EnumInt(evt.state)) or -1 end)
    if st < 0 then pcall(function() st = (tostring(evt.state):find("COMPLETED") and 1 or 0) end) end
    if st == 1 then cb.upDone = cb.upDone + 1 else cb.upStart = cb.upStart + 1 end
  end)
  -- in-world quickhack wheel (scanner): vanilla slows time while it is open (quickHackScreen time dilation)
  observe("QuickhacksListGameController", "SetVisibility", function(self, value)
    local open = value == true
    if open == S.wheel then return end
    S.wheel = open
    log("qhwheel %s | %s", open and "open" or "close", context())
    if open then
      if not S.tr then beginTransition("QuickhackWheel") end
    elseif S.tr and S.tr.kind == "QuickhackWheel" then
      endTransition("QuickhackWheel")
    end
  end)
end

registerForEvent("onInit", function()
  log("init    ------------------------------------------------ CyberslopMonitor %s date=%s spike=%d ms after=%d s tick=%d s ring=%d census=%d m",
    VERSION, os.date("%Y-%m-%d"), CFG.SPIKE_MS, CFG.LOG_AFTER_S, CFG.TICK_S, CFG.RING, CFG.CENSUS_M)
  installHooks()
  log("init    hooks installed, %d failed%s", #S.hookFails, #S.hookFails > 0 and (": " .. table.concat(S.hookFails, ", ")) or "")
  S.tick.t = now()
  flush()
end)

registerForEvent("onOverlayOpen", function() S.overlay = true; log("overlay open | %s", stateStr()) end)
registerForEvent("onOverlayClose", function() S.overlay = false; log("overlay close | %s", stateStr()) end)

registerForEvent("onShutdown", function()
  flushCombat()
  log("shutdown frames=%d spikes=%d menus=%d luaKB=%d uptime=%.0f s", S.frames, S.spikes, S.menus, luaKB(), now())
  flush()
end)

registerForEvent("onUpdate", function(dt)
  local c = os.clock()
  local wall = S.lastClock and (c - S.lastClock) * 1000 or 0
  S.lastClock = c
  if wall <= 0 then return end
  S.frames = S.frames + 1

  -- wall clock anchor: the frame on which os.time() ticks over
  local e = os.time()
  if e ~= S.epoch then S.epoch, S.epochRel = e, c - S.t0 end

  -- Lua heap: net growth and GC drops (one heap for every CET mod)
  local kb = collectgarbage("count")
  if S.lastKB then
    local d = kb - S.lastKB
    if d > 0 then S.growKB = S.growKB + d elseif d < -4096 then S.gcDrops = S.gcDrops + 1 end
  end
  S.lastKB = kb

  -- ring of recent frames
  S.ringPos = (S.ringPos % CFG.RING) + 1
  S.ring[S.ringPos] = wall

  -- pause state + time dilation (polled, not per frame)
  if c - (S.pausePoll or 0) >= CFG.POLL_S then
    S.pausePoll = c
    checkPause()
    pollTD()
    pollZoom()
  end

  -- combat activity line (written at once: crash evidence)
  if c - S.cb.t0 >= CFG.COMBAT_S then flushCombat() end

  -- buffered log lines
  if bufN > 0 and c - lastFlush >= CFG.FLUSH_S then flush() end

  -- open transition: in-menu stats
  local tr = S.tr
  if tr then
    tr.n = tr.n + 1
    tr.sum = tr.sum + wall
    if wall > tr.max then tr.max = wall end
    if wall > CFG.SPIKE_MS then tr.over = tr.over + 1 end
    if tr.n <= 10 and wall > tr.openMax then tr.openMax = wall end
  end

  -- capture after a return to the world
  local a = S.after
  if a then
    a.frames[#a.frames + 1] = wall
    if now() - a.t0 >= CFG.LOG_AFTER_S or #a.frames >= 600 then finishAfter() end
  end

  -- gameplay spikes (outside menus and outside the after-window, which logs every frame anyway)
  if c - S.budgetReset > 10 then S.budgetReset = c; S.spikeBudget = CFG.SPIKE_BUDGET end
  if wall > CFG.SPIKE_MS then
    S.spikes = S.spikes + 1
    if not tr and not a and S.spikeBudget > 0 then
      S.spikeBudget = S.spikeBudget - 1
      log("SPIKE   wall=%5.0f ms dt=%4.0f ms | %s | %s | last event %s", wall, dt * 1000, stateStr(), context(), S.lastEvent)
    end
  end

  -- periodic tick + state
  local tk = S.tick
  tk.n = tk.n + 1
  tk.sum = tk.sum + wall
  tk.list[#tk.list + 1] = wall
  if wall > tk.max then tk.max = wall end
  if wall > CFG.SPIKE_MS then tk.over = tk.over + 1 end
  local span = now() - tk.t
  if span >= CFG.TICK_S then
    local med = median(tk.list)
    checkPause()  -- fresh pause / load state right before the world reads below
    if S.inWorld and not tr and not a and not S.paused and tk.n >= 20 then S.baseline = med end
    log("tick    n=%d avg=%.1f p50=%.0f p95=%.0f max=%.0f over%d=%d fps=%.1f luaKB=%d baseline=%.0f | %s",
      tk.n, tk.sum / tk.n, med, pct(tk.list, 0.95), tk.max, CFG.SPIKE_MS, tk.over, tk.n / span, luaKB(), S.baseline, stateStr())
    local veh, combat = psm()
    local cen = (S.inWorld and not tr and not S.paused) and census() or nil
    log("state   world=%d %s %s td=%.2f tdActive=%s wheel=%s veh=%d combat=%d luaKB=%d luaGrowMBs=%.2f gcDrops=%d epoch=%d@%.3f | %s",
      S.inWorld and 1 or 0, worldState(), cen or "npc=-", S.td.value, tostring(S.td.active), tostring(S.wheel),
      veh, combat, luaKB(), S.growKB / 1024 / span, S.gcDrops, S.epoch or 0, S.epochRel, stateStr())
    S.growKB, S.gcDrops = 0, 0
    S.tick = { n = 0, sum = 0, max = 0, over = 0, list = {}, t = now() }
  end
end)
