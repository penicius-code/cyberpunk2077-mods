-- Cyberslop Bane Log 1.0.1 (2026-11-27, V's mod)
-- Everything Cyberbane tells you, in one CET window, so a missed card or text is never lost:
--   HISTORY: every text Cyberbane's gangs, Rivals, fixers and crews sent you (and your replies), plus every place it
--            marked on the map (Rival whereabouts, gatherings, sit-downs, hangouts, places the map remembers), newest
--            first, with the game day and time. Kept in history.json across sessions (last 500 entries).
--   ON THE MAP: Cyberbane's pins that are on the map right now, nearest first, each with a TRACK button (GPS route,
--            same as tracking it on the world map). People markers (hunters, bagmen...) in their own section.
-- Reads: Cyberbane's phone store at runtime (CyberbaneSystem:GetPhone(), method calls inside pcall: a Cyberbane
-- update can only make the texts part go quiet, never break anything); the pins through the redscript half
-- (r6\scripts\CyberslopBaneLog, CyberslopBaneLogSystem), which finds them by Cyberbane's caption tag and tracks them
-- through Overlay Map's native plugin.
-- Cost: onUpdate does nothing but add dt until a check is due: texts every 3 s, pins every 9 s (every 2 s while the
-- window is open and expanded). The window is drawn only while the CET overlay is open. Optional hotkey hides/shows it.
-- 1.0.1: a text is new by its place in the thread, not by its words, so a line Cyberbane sends again is logged again
-- (CET reloads inside one game session still add nothing twice: each entry carries the session number); a pin is
-- logged when it appears, unless the same pin was logged less than a game day ago (people: 3 game hours), and people
-- pins are keyed by name, not by position, so a moving hunter is one entry; history.json is written through
-- history.tmp.json first and read back from it if the main file is broken; TRACK buttons have their own IDs.

local VERSION = "1.0.1"
local SYS_NAME = "CyberslopBaneLogSystem"
local CB_SYS = "CyberbaneSystem"
local HISTORY = "history.json"
local HISTORY_TMP = "history.tmp.json"   -- complete copy written before history.json, read if that one is broken
local CONFIG = "config.json"
local MAX_ENTRIES = 500
local TEXT_EVERY = 3.0
local PIN_EVERY = 9.0
local PIN_EVERY_OPEN = 2.0
local BODIES = 16          -- newest lines read from a thread when it changed
local SAVE_DELAY = 10.0    -- s after the first unsaved entry before history.json is written
local SHOW_MAX = 200       -- entries drawn at once (more on request)
local PIN_RELOG = 86400    -- game s: the same place pin is logged again only after a game day
local PEOPLE_RELOG = 3 * 3600

local cfg = { show = true, filter = 1, people = false, ownReplies = true }

-- state in one table (keeps the draw functions' upvalue count low)
local S = {
    overlay = false, shown = false, inGame = false,
    tText = 0, tPin = 0, dirtyAt = -1, clock = 0,
    entries = {},        -- oldest first: { seq, kind, who, text, day, hm, ts, real, key, mine, sess, x, y }
    seq = 0, seenSeq = 0,
    session = nil,       -- the game session (CyberslopBaneLogSystem:Session()) the per-session state below is for
    win = {},            -- thread name -> { b = bodies, m = mine } as last read (newest BODIES, oldest first)
    threadKey = {},      -- thread index -> size|preview seen
    threadCount = 0,
    pinLast = {},        -- pin key -> game timestamp it was last logged (from history too)
    present = {},        -- pin key -> true: on the map at the last check of this session
    pins = {}, pinByKey = {}, tracked = -1, canTrack = nil, trackWhy = "",
    search = "", showMax = SHOW_MAX, status = "", statusAt = 0, lastErr = nil,
    textsOk = nil,
}

local FILTERS = { "Everything", "Texts", "Map" }

local function logLine(s)
    if spdlog and spdlog.info then spdlog.info("[CyberslopBaneLog] " .. s) else print("[CyberslopBaneLog] " .. s) end
end

local function valid(x)
    return x ~= nil and IsDefined(x)
end

local function reportError(where, err)
    local msg = tostring(err)
    if S.lastErr ~= msg then
        S.lastErr = msg
        logLine(where .. " error: " .. msg)
    end
end

-- ---------------------------------------------------------------- files

local function readRaw(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local s = f:read("*a")
    f:close()
    return s
end

local function decode(s)
    if not s or s == "" then return nil end
    local ok, t = pcall(json.decode, s)
    if ok and type(t) == "table" then return t end
    return nil
end

local function writeAll(path, s)
    local f = io.open(path, "w")
    if not f then return false end
    f:write(s)
    f:close()
    return true
end

local function saveCfg() writeAll(CONFIG, json.encode(cfg)) end

-- game seconds of an entry: stored since 1.0.1, worked out from day + hh:mm for older ones
local function entryTs(e)
    if type(e.ts) == "number" then return e.ts end
    local h, m = tostring(e.hm or ""):match("^(%d+):(%d+)$")
    return (tonumber(e.day) or 0) * 86400 + (tonumber(h) or 0) * 3600 + (tonumber(m) or 0) * 60
end

local function loadAll()
    local c = decode(readRaw(CONFIG))
    if c then
        if type(c.show) == "boolean" then cfg.show = c.show end
        if c.filter == 1 or c.filter == 2 or c.filter == 3 then cfg.filter = c.filter end
        if type(c.people) == "boolean" then cfg.people = c.people end
        if type(c.ownReplies) == "boolean" then cfg.ownReplies = c.ownReplies end
    end
    local raw = readRaw(HISTORY)
    local h = decode(raw)
    local t = decode(readRaw(HISTORY_TMP))
    -- a crash between the two writes leaves the copy one save ahead: take the newer readable one
    if h and t and (tonumber(t.saved) or 0) > (tonumber(h.saved) or 0) then h = t end
    if not h then
        h = t
        if raw and raw ~= "" then
            -- unreadable history.json: kept aside once, never overwritten blind
            writeAll("history.broken-" .. os.time() .. ".json", raw)
            logLine("history.json unreadable, kept as history.broken-*.json; " .. (h and "read history.tmp.json" or "no copy"))
            S.dirtyAt = S.clock   -- write a good history.json soon, so the next start does not find it broken again
        end
    end
    if h and type(h.entries) == "table" then
        for _, e in ipairs(h.entries) do
            if type(e) == "table" and type(e.text) == "string" then
                S.seq = S.seq + 1
                e.seq = S.seq
                S.entries[#S.entries + 1] = e
                if e.kind == "pin" and e.key then
                    local ts = entryTs(e)
                    if not S.pinLast[e.key] or ts > S.pinLast[e.key] then S.pinLast[e.key] = ts end
                end
            end
        end
        S.seenSeq = S.seq
    end
end

local function saveHistory()
    local out = {}
    for i, e in ipairs(S.entries) do
        out[i] = { kind = e.kind, who = e.who, text = e.text, day = e.day, hm = e.hm, ts = e.ts, real = e.real,
            key = e.key, mine = e.mine, sess = e.sess, x = e.x, y = e.y }
    end
    local s = json.encode({ version = VERSION, saved = os.time(), entries = out })
    -- the copy first: whichever write a crash cuts short, the other file is whole
    if writeAll(HISTORY_TMP, s) then writeAll(HISTORY, s) end
    S.dirtyAt = -1
end

-- ---------------------------------------------------------------- recording

local function gameNow()
    local ok, ts = pcall(function() return Game.GetTimeSystem():GetGameTimeStamp() end)
    if not ok or type(ts) ~= "number" then return 0 end
    return ts
end

local function add(e)
    local ts = gameNow()
    local day = math.floor(ts / 86400)
    local rem = ts - day * 86400
    e.ts = ts
    e.day = day
    e.hm = ts > 0 and string.format("%02d:%02d", math.floor(rem / 3600), math.floor((rem % 3600) / 60)) or ""
    e.real = os.time()
    e.sess = S.session
    S.seq = S.seq + 1
    e.seq = S.seq
    S.entries[#S.entries + 1] = e
    while #S.entries > MAX_ENTRIES do table.remove(S.entries, 1) end
    if S.dirtyAt < 0 then S.dirtyAt = S.clock end
end

-- A new game session (a load): Cyberbane's phone starts empty and the pins are placed again, so the per-session state
-- starts over. A CET reload inside the same session instead starts from what this session already logged.
local function syncSession()
    local sys = Game.GetScriptableSystemsContainer():Get(SYS_NAME)
    local tok = 0
    if valid(sys) then tok = sys:Session() or 0 end
    if tok == S.session then return end
    S.session = tok
    S.win, S.threadKey, S.threadCount, S.present = {}, {}, 0, {}
    if tok == 0 then return end
    for _, e in ipairs(S.entries) do
        if e.sess == tok and e.kind == "text" and e.who then
            local w = S.win[e.who]
            if not w then w = { b = {}, m = {} }; S.win[e.who] = w end
            w.b[#w.b + 1] = e.text
            w.m[#w.m + 1] = e.mine == true
            if #w.b > BODIES then table.remove(w.b, 1); table.remove(w.m, 1) end
        end
    end
end

local function getCBPhone()
    local sc = Game.GetScriptableSystemsContainer()
    if not sc then return nil end
    local sys = sc:Get(CB_SYS)
    if not valid(sys) then return nil end
    local ph = sys:GetPhone()
    if not valid(ph) then return nil end
    return ph
end

-- How many of the newest lines read now (b, m) were already in the last read (prev): the longest end of prev that the
-- new read starts with. A thread only grows at its end (old lines drop off the front when Cyberbane's store is full).
local function overlap(prev, b, m)
    local np, nb = #prev.b, #b
    local k = math.min(np, nb)
    while k > 0 do
        local same = true
        for j = 1, k do
            local p = np - k + j
            if prev.b[p] ~= b[j] or prev.m[p] ~= m[j] then same = false; break end
        end
        if same then return k end
        k = k - 1
    end
    return 0
end

local function pollTexts()
    local ph = getCBPhone()
    if not ph then S.textsOk = false; return end
    S.textsOk = true
    local n = ph:ThreadCount() or 0
    if n < S.threadCount then S.threadKey = {}; S.win = {} end -- Cyberbane started its phone over
    S.threadCount = n
    for i = 0, n - 1 do
        local okSize, size = pcall(function() return ph:ThreadSize(i) end)
        local key = tostring(okSize and size or "?") .. "|" .. (ph:ThreadPreview(i) or "")
        if S.threadKey[i] ~= key then
            S.threadKey[i] = key
            local name = ph:ThreadName(i) or "?"
            local bodies = ph:ThreadBodies(i, BODIES) or {}
            local mineRaw = ph:ThreadMine(i, BODIES) or {}
            local b, m = {}, {}
            for j, body in ipairs(bodies) do
                b[j] = type(body) == "string" and body or ""
                m[j] = mineRaw[j] == true
            end
            local prev = S.win[name] or { b = {}, m = {} }
            for j = overlap(prev, b, m) + 1, #b do
                if b[j] ~= "" then add({ kind = "text", who = name, text = b[j], mine = m[j] }) end
            end
            S.win[name] = { b = b, m = m }
        end
    end
end

-- caption -> kind, title, note (Cyberbane's caption scheme, UI/RivalPin.reds)
local function parsePin(cap)
    if cap:sub(1, 9) ~= "CB_RIVAL|" then return "place", (cap ~= "" and cap or "A marked place"), "" end
    local b = cap:sub(10)
    local m = b:sub(1, 1)
    if m == "+" then return "hunter", b:sub(2), "out looking for you" end
    if m == "~" then
        local name, note = b:sub(2):match("^(.-)%^(.*)$")
        return "person", name or b:sub(2), note or ""
    end
    if m == "#" then return "event", b:sub(2), "" end
    if m == "@" then return "memory", "Something happened here", "the map remembers it for a day" end
    return "rival", b, "Rival's last known place"
end

local function isPeople(kind)
    return kind == "hunter" or kind == "person"
end

-- People move with their NPC: keyed by name. Places by name and 25 m cell.
local function pinKey(kind, title, x, y)
    if isPeople(kind) then return kind .. "|" .. title end
    return kind .. "|" .. title .. "|" .. math.floor(x / 25) .. "," .. math.floor(y / 25)
end

local function pollPins()
    local sys = Game.GetScriptableSystemsContainer():Get(SYS_NAME)
    if not valid(sys) then S.pins = {}; S.pinByKey = {}; return end
    if S.canTrack == nil then
        S.canTrack = sys:CanTrack() == true
        if not S.canTrack then S.trackWhy = tostring(sys:TrackWhy() or "") end
    end
    local n = sys:Refresh() or 0
    local now = gameNow()
    local pins, byKey, present = {}, {}, {}
    for i = 0, n - 1 do
        local cap = sys:Caption(i) or ""
        local kind, title, note = parsePin(cap)
        local x, y = sys:X(i) or 0, sys:Y(i) or 0
        local p = { i = i, kind = kind, title = title, note = note, dist = sys:Dist(i) or -1, x = x, y = y,
            key = pinKey(kind, title, x, y) }
        pins[#pins + 1] = p
        byKey[p.key] = p
        local people = isPeople(kind)
        -- logged when it appears this session, unless the same pin was logged lately (a load puts pins back)
        if not S.present[p.key] and not present[p.key] and (not people or cfg.people) then
            local last = S.pinLast[p.key]
            local window = people and PEOPLE_RELOG or PIN_RELOG
            if not last or (now > 0 and math.abs(now - last) >= window) then
                S.pinLast[p.key] = now
                local text = title
                if note ~= "" then text = text .. " (" .. note .. ")" end
                add({ kind = "pin", who = kind, text = text, key = p.key, x = x, y = y })
            end
        end
        present[p.key] = true
    end
    table.sort(pins, function(a, b) return a.dist < b.dist end)
    S.pins, S.pinByKey, S.present = pins, byKey, present
    S.tracked = sys:TrackedIndex() or -1
end

local function track(p)
    local sys = Game.GetScriptableSystemsContainer():Get(SYS_NAME)
    if not valid(sys) or not p then return end
    local ok = sys:Track(p.i) == true
    S.status = ok and ("Tracking: " .. p.title) or "Could not track that one (it may be gone, or the game refused it)"
    S.statusAt = S.clock
    S.tPin = PIN_EVERY -- re-read now
end

local function untrack()
    local sys = Game.GetScriptableSystemsContainer():Get(SYS_NAME)
    if not valid(sys) then return end
    if sys:Untrack() then S.status = "Stopped tracking"; S.statusAt = S.clock end
    S.tPin = PIN_EVERY
end

-- ---------------------------------------------------------------- drawing

local KIND_COL = {
    text = { 0.37, 0.96, 1.0, 1 }, mine = { 0.75, 0.75, 0.72, 1 },
    rival = { 1.0, 0.33, 0.3, 1 }, event = { 0.98, 0.83, 0.12, 1 }, memory = { 0.8, 0.62, 1.0, 1 },
    place = { 0.98, 0.83, 0.12, 1 }, hunter = { 1.0, 0.33, 0.3, 1 }, person = { 0.62, 0.9, 0.62, 1 },
}
local KIND_WORD = {
    rival = "RIVAL", event = "GATHERING", memory = "REMEMBERED", place = "PLACE", hunter = "HUNTER", person = "MARKED",
}

local function distText(d)
    if not d or d < 0 then return "" end
    if d >= 1000 then return string.format("%.1f km", d / 1000) end
    return string.format("%d m", math.floor(d + 0.5))
end

local function trackButton(p, id)
    if not p then return end
    if S.tracked == p.i then
        if ImGui.SmallButton("UNTRACK##" .. id) then untrack() end
    elseif S.canTrack then
        if ImGui.SmallButton("TRACK##" .. id) then track(p) end
    end
end

local function matches(e, q)
    if cfg.filter == 2 and e.kind ~= "text" then return false end
    if cfg.filter == 3 and e.kind ~= "pin" then return false end
    if e.kind == "text" and e.mine and not cfg.ownReplies then return false end
    if q ~= "" then
        local hay = ((e.who or "") .. " " .. (e.text or "")):lower()
        if not hay:find(q, 1, true) then return false end
    end
    return true
end

local function drawHistory()
    ImGui.SetNextItemWidth(130)
    if ImGui.BeginCombo("##cbl_filter", FILTERS[cfg.filter]) then
        for i, name in ipairs(FILTERS) do
            if ImGui.Selectable(name, cfg.filter == i) then cfg.filter = i; S.showMax = SHOW_MAX; saveCfg() end
        end
        ImGui.EndCombo()
    end
    ImGui.SameLine()
    ImGui.SetNextItemWidth(220)
    local txt, changed = ImGui.InputTextWithHint("##cbl_search", "search", S.search, 120)
    if changed then S.search = txt or ""; S.showMax = SHOW_MAX end
    ImGui.SameLine()
    local v, ch = ImGui.Checkbox("my replies", cfg.ownReplies)
    if ch then cfg.ownReplies = v; saveCfg() end

    ImGui.BeginChild("##cbl_hist", 0, 0, false)
    local q = (S.search or ""):lower()
    local drawn = 0
    for idx = #S.entries, 1, -1 do
        local e = S.entries[idx]
        if matches(e, q) then
            drawn = drawn + 1
            if drawn > S.showMax then
                if ImGui.Button("Show older##cbl_more") then S.showMax = S.showMax + SHOW_MAX end
                break
            end
            local stamp = (e.day and e.day > 0) and ("Day " .. e.day .. " " .. (e.hm or "")) or (e.hm or "")
            ImGui.TextDisabled(stamp)
            ImGui.SameLine()
            if e.kind == "text" then
                local c = e.mine and KIND_COL.mine or KIND_COL.text
                ImGui.TextColored(c[1], c[2], c[3], c[4], e.mine and ("You -> " .. (e.who or "")) or (e.who or "?"))
            else
                local c = KIND_COL[e.who] or KIND_COL.place
                ImGui.TextColored(c[1], c[2], c[3], c[4], "MAP " .. (KIND_WORD[e.who] or "PIN"))
                local live = e.key and S.pinByKey[e.key]
                if live then
                    ImGui.SameLine()
                    ImGui.TextDisabled(distText(live.dist))
                    ImGui.SameLine()
                    trackButton(live, "h" .. e.seq)
                else
                    ImGui.SameLine()
                    ImGui.TextDisabled("(gone from the map)")
                end
            end
            ImGui.TextWrapped(e.text or "")
            ImGui.Separator()
        end
    end
    if drawn == 0 then ImGui.TextDisabled("Nothing yet.") end
    ImGui.EndChild()
end

local function drawPinRow(p)
    local c = KIND_COL[p.kind] or KIND_COL.place
    trackButton(p, "p" .. p.i)
    ImGui.SameLine()
    ImGui.TextColored(c[1], c[2], c[3], c[4], KIND_WORD[p.kind] or "PIN")
    ImGui.SameLine()
    ImGui.TextDisabled(distText(p.dist))
    ImGui.SameLine()
    if S.tracked == p.i then ImGui.TextColored(0.37, 0.96, 1.0, 1, "TRACKED") ImGui.SameLine() end
    ImGui.TextWrapped(p.title .. ((p.note ~= "") and ("  -  " .. p.note) or ""))
end

local function drawPins()
    if S.canTrack == false then
        ImGui.TextColored(1, 0.5, 0.4, 1, "Tracking unavailable: " .. S.trackWhy)
    end
    local places, people = {}, {}
    for _, p in ipairs(S.pins) do
        if isPeople(p.kind) then people[#people + 1] = p else places[#places + 1] = p end
    end
    if S.canTrack and #places > 0 then
        if ImGui.Button("Track nearest place##cbl_near") then track(places[1]) end
        ImGui.SameLine()
    end
    if S.tracked >= 0 then
        if ImGui.Button("Untrack##cbl_untr") then untrack() end
        ImGui.SameLine()
    end
    local v, ch = ImGui.Checkbox("log people markers in History", cfg.people)
    if ch then cfg.people = v; saveCfg() end
    ImGui.BeginChild("##cbl_pins", 0, 0, false)
    ImGui.TextDisabled(string.format("PLACES (%d)", #places))
    for _, p in ipairs(places) do drawPinRow(p) end
    if #places == 0 then ImGui.TextDisabled("No Cyberbane places on the map right now.") end
    ImGui.Spacing()
    if ImGui.CollapsingHeader(string.format("PEOPLE (%d)##cbl_people", #people)) then
        for _, p in ipairs(people) do drawPinRow(p) end
    end
    ImGui.EndChild()
end

local function drawBody()
    if not S.inGame then ImGui.TextDisabled("Load a save first.") return end
    if S.textsOk == false then
        ImGui.TextColored(1, 0.5, 0.4, 1, "Cyberbane's phone not found (texts are not recorded).")
    end
    if S.status ~= "" and S.clock - S.statusAt < 6 then ImGui.TextColored(0.37, 0.96, 1.0, 1, S.status) end
    if ImGui.BeginTabBar("##cbl_tabs") then
        if ImGui.BeginTabItem("HISTORY##cbl_t1") then
            S.seenSeq = S.seq
            drawHistory()
            ImGui.EndTabItem()
        end
        if ImGui.BeginTabItem(string.format("ON THE MAP (%d)##cbl_t2", #S.pins)) then
            drawPins()
            ImGui.EndTabItem()
        end
        ImGui.EndTabBar()
    end
end

-- ---------------------------------------------------------------- events

registerForEvent("onInit", function()
    local ok, err = pcall(loadAll)
    if not ok then logLine("history not read: " .. tostring(err)) end
    logLine("loaded " .. VERSION .. ", " .. #S.entries .. " entries")
end)

registerForEvent("onShutdown", function()
    if S.dirtyAt >= 0 then pcall(saveHistory) end
end)

registerForEvent("onOverlayOpen", function()
    S.overlay = true
    S.tPin = PIN_EVERY
    S.tText = TEXT_EVERY
end)

registerForEvent("onOverlayClose", function()
    S.overlay = false
end)

registerHotkey("CyberslopBaneLogToggle", "Show / hide the Bane Log window", function()
    cfg.show = not cfg.show
    saveCfg()
end)

registerForEvent("onUpdate", function(dt)
    S.clock = S.clock + dt
    S.tText = S.tText + dt
    S.tPin = S.tPin + dt
    if S.tText < TEXT_EVERY and S.tPin < PIN_EVERY_OPEN then return end
    if S.tText >= TEXT_EVERY then
        S.tText = 0
        S.inGame = valid(Game.GetPlayer())
        if S.inGame then
            local okS, errS = pcall(syncSession)
            if not okS then reportError("session", errS) end
            local ok, err = pcall(pollTexts)
            if not ok then S.textsOk = false; reportError("texts", err) end
        end
        if S.dirtyAt >= 0 and S.clock - S.dirtyAt >= SAVE_DELAY then
            local ok, err = pcall(saveHistory)
            if not ok then reportError("save", err) end
        end
    end
    local every = (S.overlay and S.shown) and PIN_EVERY_OPEN or PIN_EVERY
    if S.tPin >= every then
        S.tPin = 0
        if S.inGame then
            local okS, errS = pcall(syncSession)
            if not okS then reportError("session", errS) end
            local ok, err = pcall(pollPins)
            if not ok then reportError("pins", err) end
        end
    end
end)

registerForEvent("onDraw", function()
    if not S.overlay or not cfg.show then return end
    ImGui.SetNextWindowSize(560, 640, ImGuiCond.FirstUseEver)
    ImGui.SetNextWindowSizeConstraints(360, 260, 6000, 4000)
    local new = S.seq - S.seenSeq
    local title = new > 0 and string.format("Bane Log (%d new)###CyberslopBaneLog", new) or "Bane Log###CyberslopBaneLog"
    local shown = ImGui.Begin(title)
    S.shown = shown and true or false
    if shown then
        local ok, err = pcall(drawBody)
        if not ok then reportError("draw", err) end
    end
    ImGui.End()
end)

return {}
