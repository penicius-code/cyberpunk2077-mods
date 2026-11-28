-- Cyberslop Adam Summon 1.0.0
-- CET window with one toggle: summons the Lore-Accurate Adam Smasher (Nexus 36865) encounter
-- anywhere, at any wanted level. Drives the mod's own command queue
-- (CorpoPlaza.EncounterSystem.DebugRequest, API 9): command 1 = start Mod Adam with police held,
-- 3 = end (Adam withdraws, police restored), 14 = end the current pursuit. A summon runs on a
-- RAM-only ledger, so the save's 7-day repair timer is never touched. The mod ends a summon by
-- itself unless it gets a heartbeat at least every 10 s; onUpdate sends one every frame.

local MOD = "Cyberslop Adam Summon"
local API = 9
local POLL = 0.25          -- the mod's own tick is 0.25 s
local CLEAR_TIMEOUT = 15.0 -- end pursuit -> zero stars
local START_TIMEOUT = 20.0 -- queued start -> "Spawning"

local S = {
  overlay = false,
  active = false,      -- the toggle
  phase = "idle",      -- idle | clearing | starting | running | ending
  timer = 0.0,
  poll = 0.0,
  clearStars = true,
  status = "Off",
  modStatus = "",
  warn = nil,
}

local function sys()
  local ok, s = pcall(function()
    return Game.GetScriptableSystemsContainer():Get("CorpoPlaza.EncounterSystem")
  end)
  if ok then return s end
  return nil
end

local function call(name, arg)
  local s = sys()
  if not s then return nil end
  local ok, r = pcall(function()
    if arg == nil then return s[name](s) end
    return s[name](s, arg)
  end)
  if ok then return r end
  return nil
end

local function snapshot()
  local snap = call("DebugSnapshot")
  if type(snap) ~= "string" then return nil end
  return {
    debug = snap:match("^debug=(%a+)") == "true",
    heat = tonumber(snap:match(" heat=(%d+)") or ""),
    chasing = snap:match(" chasing=(%a+)") == "true",
    owned = snap:match(" owned=(%a+)") == "true",
    raw = snap,
  }
end

local function request(cmd)
  local r = call("DebugRequest", cmd)
  if type(r) == "string" then S.modStatus = r end
  return r
end

local function stop(reason)
  if S.phase == "running" or S.phase == "starting" then request(3) end
  S.active = false
  S.phase = "idle"
  S.timer = 0.0
  S.status = reason or "Off"
end

local function begin()
  S.warn = nil
  local v = call("DebugAPIVersion")
  if v == nil then
    S.active = false
    S.status = "Lore-Accurate Adam Smasher not running (load a save first)"
    return
  end
  if v ~= API then S.warn = "Adam mod API " .. tostring(v) .. ", built for " .. API .. " - may misbehave" end
  local snap = snapshot()
  if not snap then S.active = false; S.status = "Adam mod not ready yet"; return end
  if snap.debug or snap.owned then
    S.active = false
    S.status = "An Adam event is already running - wait until he is gone"
    return
  end
  S.timer = 0.0
  if snap.chasing or (snap.heat and snap.heat > 0) then
    if not S.clearStars then
      S.active = false
      S.status = "Lose your stars first (or tick 'Clear my stars first')"
      return
    end
    request(14)
    S.phase = "clearing"
    S.status = "Ending the police pursuit..."
    return
  end
  request(1)
  S.phase = "starting"
  S.status = "Summoning Adam..."
end

local function step(dt)
  if S.phase == "idle" then return end
  S.timer = S.timer + dt
  local snap = snapshot()
  local st = call("DebugStatus")
  if type(st) == "string" then S.modStatus = st end
  if not snap then stop("Adam mod went away (save loaded or session ended)"); return end

  if S.phase == "clearing" then
    if not snap.chasing and snap.heat == 0 then
      request(1)
      S.phase = "starting"
      S.timer = 0.0
      S.status = "Summoning Adam..."
    elseif S.timer > CLEAR_TIMEOUT then
      S.active = false; S.phase = "idle"
      S.status = "Could not clear the stars: " .. S.modStatus
    end
    return
  end

  if S.phase == "starting" then
    local m = S.modStatus
    if m:find("Spawning Mod Adam", 1, true) or m:find("engaged", 1, true) then
      S.phase = "running"
      S.status = "Adam is coming"
    elseif m:find("blocked", 1, true) or m:find("requires zero stars", 1, true)
        or m:find("already present", 1, true) or m:find("still leaving", 1, true) then
      if snap.debug then request(3) end
      S.active = false; S.phase = "idle"
      S.status = m
    elseif S.timer > START_TIMEOUT then
      stop("Start timed out: " .. m)
    end
    return
  end

  if S.phase == "running" then
    local m = S.modStatus
    if m:find("engaged", 1, true) then S.status = "Adam engaged - police held off" end
    if m:find("withdrawing", 1, true) then S.status = "Adam at 20% - withdrawing" end
    if m:find("gone - press Reset", 1, true) or (not snap.owned and S.timer > 1.5) then
      -- withdrew, or the spawn failed (no spot found etc.): end the summon, police back on
      request(3)
      S.active = false; S.phase = "idle"
      if m:find("Last failure", 1, true) and not m:find("gone", 1, true) then
        S.status = "Adam could not spawn here: " .. m
      else
        S.status = "Adam is gone - police back on"
      end
    elseif not snap.debug and S.timer > 2.0 then
      S.active = false; S.phase = "idle"
      S.status = "Event ended: " .. m
    end
  end
end

registerForEvent("onInit", function()
  print("[" .. MOD .. "] loaded")
end)

registerForEvent("onOverlayOpen", function() S.overlay = true end)
registerForEvent("onOverlayClose", function() S.overlay = false end)

registerForEvent("onUpdate", function(dt)
  if S.phase ~= "idle" then
    call("DebugHeartbeat")
    S.poll = S.poll + dt
    if S.poll >= POLL then
      local d = S.poll
      S.poll = 0.0
      step(d)
    end
  end
end)

registerForEvent("onShutdown", function()
  if S.phase ~= "idle" then request(3) end
end)

registerHotkey("CyberslopAdamSummonToggle", "Toggle Adam Smasher summon", function()
  if S.active then stop("Off") else S.active = true; begin() end
end)

registerForEvent("onDraw", function()
  if not S.overlay then return end
  if ImGui.Begin("Adam Summon") then
    local value, pressed = ImGui.Checkbox("Summon Adam Smasher", S.active)
    if pressed then
      if value then S.active = true; begin() else stop("Off") end
    end
    local cs, csp = ImGui.Checkbox("Clear my stars first", S.clearStars)
    if csp then S.clearStars = cs end
    ImGui.TextWrapped(S.status)
    if S.modStatus ~= "" and S.phase ~= "idle" then
      ImGui.TextWrapped("Mod: " .. S.modStatus)
    end
    if S.warn then ImGui.TextWrapped(S.warn) end
  end
  ImGui.End()
end)

-- test hook for tools/mock.lua
return { _S = S, _step = step, _begin = begin, _stop = stop }
