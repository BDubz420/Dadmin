-- DAdmin Player History Core
-- Phase 5: indexed per-player moderation history with summaries and linked records.
if CLIENT then return end

DAdmin = DAdmin or {}
DAdmin.History = DAdmin.History or {}

local HISTORY_FILE = "history.json"
local DEFAULT_BUCKETS = { "warnings", "kicks", "bans", "reports", "sits", "cases", "notes", "mutes", "gags", "punishments", "logs" }
local MAX_BUCKET_ENTRIES = 250
local history = {}

local function now() return os.time() end

local function shallowCopy(tbl)
    return istable(tbl) and table.Copy(tbl) or {}
end

local function blank(steamid)
    local out = {
        steamid = tostring(steamid or ""),
        firstSeen = now(),
        lastSeen = now(),
        names = {},
        summary = {
            warnings = 0,
            kicks = 0,
            bans = 0,
            reports = 0,
            sits = 0,
            mutes = 0,
            gags = 0,
            cases = 0,
            punishments = 0,
            notes = 0
        },
        links = {}
    }

    for _, bucket in ipairs(DEFAULT_BUCKETS) do out[bucket] = {} end
    return out
end

local function ensure(steamid)
    steamid = tostring(steamid or "")
    if steamid == "" then return blank("") end

    local record = istable(history[steamid]) and history[steamid] or blank(steamid)
    history[steamid] = record
    record.steamid = record.steamid or steamid
    record.firstSeen = record.firstSeen or now()
    record.lastSeen = record.lastSeen or now()
    record.names = istable(record.names) and record.names or {}
    record.summary = istable(record.summary) and record.summary or {}
    record.links = istable(record.links) and record.links or {}

    for _, bucket in ipairs(DEFAULT_BUCKETS) do
        record[bucket] = istable(record[bucket]) and record[bucket] or {}
        record.summary[bucket] = tonumber(record.summary[bucket] or #record[bucket]) or 0
    end

    return record
end

local function recordName(steamid, name)
    if not name or name == "" then return end
    local record = ensure(steamid)
    record.names[tostring(name)] = now()
end

function DAdmin.History.Load()
    history = (DAdmin.Storage and DAdmin.Storage.Load and DAdmin.Storage.Load(HISTORY_FILE, {})) or {}
    for steamid, _ in pairs(history) do ensure(steamid) end
    return history
end

function DAdmin.History.Save()
    if DAdmin.Storage and DAdmin.Storage.Save then
        return DAdmin.Storage.Save(HISTORY_FILE, history)
    end
end

function DAdmin.History.TouchPlayer(ply)
    if not IsValid(ply) then return end
    local sid = ply:SteamID()
    local record = ensure(sid)
    record.lastSeen = now()
    recordName(sid, ply:Nick())
    DAdmin.History.Save()
end

function DAdmin.History.Add(steamid, bucket, data)
    steamid = tostring(steamid or "")
    bucket = tostring(bucket or "notes")
    if steamid == "" then return false end

    local entry = shallowCopy(data)
    if not istable(data) then entry = { details = tostring(data or "") } end
    entry.id = entry.id or (bucket .. "_" .. tostring(now()) .. "_" .. tostring(math.random(1000, 9999)))
    entry.timestamp = entry.timestamp or now()
    entry.bucket = bucket

    local record = ensure(steamid)
    record[bucket] = istable(record[bucket]) and record[bucket] or {}
    table.insert(record[bucket], 1, entry)
    record.summary[bucket] = (tonumber(record.summary[bucket] or 0) or 0) + 1
    record.lastSeen = now()

    if entry.name then recordName(steamid, entry.name) end
    if entry.target then recordName(steamid, entry.target) end

    DAdmin.History.Save()
    return true, entry
end

function DAdmin.History.Link(steamid, key, value)
    steamid = tostring(steamid or "")
    if steamid == "" then return false end
    local record = ensure(steamid)
    key = tostring(key or "link")
    record.links[key] = record.links[key] or {}
    table.insert(record.links[key], 1, value)
    DAdmin.History.Save()
    return true
end

function DAdmin.History.AddNote(admin, steamid, note)
    local entry = {
        admin = IsValid(admin) and admin:Nick() or "Console",
        adminSteamID = IsValid(admin) and admin:SteamID() or "CONSOLE",
        details = tostring(note or "")
    }
    return DAdmin.History.Add(steamid, "notes", entry)
end

function DAdmin.History.Get(steamid)
    return ensure(steamid)
end

function DAdmin.History.GetAll()
    return history
end

function DAdmin.History.GetSummary(steamid)
    local record = ensure(steamid)
    return record.summary or {}
end

function DAdmin.History.Search(term)
    term = string.lower(tostring(term or ""))
    local out = {}
    for steamid, record in pairs(history) do
        local hit = string.find(string.lower(steamid), term, 1, true)
        if not hit and istable(record.names) then
            for name in pairs(record.names) do
                if string.find(string.lower(name), term, 1, true) then hit = true break end
            end
        end
        if hit then out[#out + 1] = record end
    end
    return out
end

function DAdmin.History.Prune()
    local removed = 0
    for _, record in pairs(history) do
        for _, bucket in ipairs(DEFAULT_BUCKETS) do
            local list = record[bucket]
            if istable(list) then
                while #list > MAX_BUCKET_ENTRIES do
                    table.remove(list)
                    removed = removed + 1
                end
            end
        end
    end
    if removed > 0 then DAdmin.History.Save() end
    return removed
end

DAdmin.History.Load()

hook.Add("PlayerInitialSpawn", "DAdmin_HistoryTouchInitial", function(ply)
    timer.Simple(3, function()
        if IsValid(ply) and DAdmin.History then DAdmin.History.TouchPlayer(ply) end
    end)
end)

hook.Add("PlayerDisconnected", "DAdmin_HistoryTouchDisconnect", function(ply)
    if IsValid(ply) and DAdmin.History then DAdmin.History.TouchPlayer(ply) end
end)

DAdmin.RegisterCommand("history", {
    permission = "history",
    description = "Show a player's moderation history summary",
    category = "Moderation",
    args = {{ name = "target", type = "player" }},
    run = function(admin, targets)
        for _, ply in ipairs(targets or {}) do
            local h = DAdmin.History.Get(ply:SteamID())
            local s = h.summary or {}
            DAdmin.Msg(admin, ply:Nick() .. " history: " ..
                "warns=" .. tostring(s.warnings or 0) ..
                ", bans=" .. tostring(s.bans or 0) ..
                ", kicks=" .. tostring(s.kicks or 0) ..
                ", reports=" .. tostring(s.reports or 0) ..
                ", cases=" .. tostring(s.cases or 0))
        end
    end
})

DAdmin.RegisterCommand("historynote", {
    permission = "history.note",
    description = "Add a private staff note to a SteamID",
    category = "Moderation",
    args = {{ name = "steamid", type = "steamid" }, { name = "note", type = "string" }},
    run = function(admin, steamid, note)
        local ok = DAdmin.History.AddNote(admin, steamid, note)
        DAdmin.Msg(admin, ok and "History note added." or "Could not add history note.")
        return ok
    end
})
