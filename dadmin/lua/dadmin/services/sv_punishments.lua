-- DAdmin Punishment Service
-- Phase 5: persistent punishments with IDs, history, case linking, and expiry cleanup.
if CLIENT then return end

DAdmin = DAdmin or {}
DAdmin.Punishments = DAdmin.Punishments or {}
DAdmin.Bans = DAdmin.Bans or {}
DAdmin.Mutes = DAdmin.Mutes or {}
DAdmin.Gags = DAdmin.Gags or {}

local function now() return os.time() end
local function minutesFromSeconds(seconds)
    seconds = tonumber(seconds or 0) or 0
    if seconds <= 0 then return 0 end
    return math.ceil(seconds / 60)
end
local function expiry(seconds)
    seconds = tonumber(seconds or 0) or 0
    return seconds > 0 and (now() + seconds) or 0
end
local function isExpired(data)
    return istable(data) and tonumber(data.expires or 0) > 0 and tonumber(data.expires or 0) <= now()
end
local function can(admin, perm)
    return not DAdmin.HasPermission or DAdmin.HasPermission(admin, perm)
end
local function resolved(admin, target)
    if IsValid(target) then return { target } end
    return (DAdmin.Players and DAdmin.Players.ResolveTarget and DAdmin.Players.ResolveTarget(admin, target)) or {}
end
local function adminInfo(admin)
    return IsValid(admin) and admin:Nick() or "Console", IsValid(admin) and admin:SteamID() or "CONSOLE"
end
local function newID(kind)
    return tostring(kind or "punishment") .. "_" .. tostring(now()) .. "_" .. tostring(math.random(1000,9999))
end

local function openCaseFor(steamid, admin, reason)
    if not DAdmin.Cases then return nil end
    local existing = DAdmin.Cases.FindOpenForPlayer and DAdmin.Cases.FindOpenForPlayer(steamid)
    if existing then return existing end
    local _, aSteam = adminInfo(admin)
    return DAdmin.Cases.Create and DAdmin.Cases.Create(steamid, nil, aSteam, reason or "Punishment")
end

local function recordPunishment(kind, admin, ply, data)
    data = data or {}
    data.id = data.id or newID(kind)
    data.type = kind
    data.timestamp = data.timestamp or now()

    if IsValid(ply) then
        data.target = data.target or ply:Nick()
        data.targetSteamID = data.targetSteamID or ply:SteamID()
    end

    if DAdmin.History and DAdmin.History.Add and data.targetSteamID then
        DAdmin.History.Add(data.targetSteamID, kind == "ban" and "bans" or (kind == "mute" and "mutes" or (kind == "gag" and "gags" or "punishments")), table.Copy(data))
        DAdmin.History.Add(data.targetSteamID, "punishments", table.Copy(data))
    end

    local case = openCaseFor(data.targetSteamID, admin, data.reason or kind)
    if case and DAdmin.Cases and DAdmin.Cases.AttachPunishment then
        data.caseID = case.id
        DAdmin.Cases.AttachPunishment(case.id, table.Copy(data), admin)
    end

    return data
end

function DAdmin.Punishments.Load()
    DAdmin.Bans = (DAdmin.Storage and DAdmin.Storage.Load and DAdmin.Storage.Load("bans.json", {})) or {}
    DAdmin.Mutes = (DAdmin.Storage and DAdmin.Storage.Load and DAdmin.Storage.Load("mutes.json", {})) or {}
    DAdmin.Gags = (DAdmin.Storage and DAdmin.Storage.Load and DAdmin.Storage.Load("gags.json", {})) or {}
end

function DAdmin.Punishments.Save()
    if DAdmin.Storage and DAdmin.Storage.Save then
        DAdmin.Storage.Save("bans.json", DAdmin.Bans or {})
        DAdmin.Storage.Save("mutes.json", DAdmin.Mutes or {})
        DAdmin.Storage.Save("gags.json", DAdmin.Gags or {})
    end
end

function DAdmin.Punishments.Kick(admin, target, reason)
    if not can(admin, "kick") then return false, "permission denied" end
    local count = 0
    for _, ply in ipairs(resolved(admin, target)) do
        local aName, aSteam = adminInfo(admin)
        local entry = recordPunishment("kick", admin, ply, {
            admin = aName,
            adminSteamID = aSteam,
            reason = reason or "Kicked"
        })
        if DAdmin.Log then DAdmin.Log("kick", admin, ply, entry.reason) end
        count = count + 1
        ply:Kick(entry.reason)
    end
    return count > 0
end

function DAdmin.Punishments.Ban(admin, target, length, reason)
    if not can(admin, "ban") then return false, "permission denied" end
    length = tonumber(length or 0) or 0
    local count = 0

    for _, ply in ipairs(resolved(admin, target)) do
        local aName, aSteam = adminInfo(admin)
        local ban = recordPunishment("ban", admin, ply, {
            name = ply:Nick(),
            steamid = ply:SteamID(),
            admin = aName,
            adminSteamID = aSteam,
            reason = reason or "Banned",
            length = length,
            created = now(),
            expires = expiry(length)
        })

        DAdmin.Bans[ply:SteamID()] = ban
        if DAdmin.Log then DAdmin.Log("ban", admin, ply, ban.reason) end

        ply:Ban(minutesFromSeconds(length), ban.reason)
        ply:Kick(ban.reason)
        count = count + 1
    end

    DAdmin.Punishments.Save()
    return count > 0
end

function DAdmin.Punishments.Unban(admin, steamid)
    if not can(admin, "ban") then return false, "permission denied" end
    steamid = tostring(steamid or "")
    local old = DAdmin.Bans[steamid]
    DAdmin.Bans[steamid] = nil
    DAdmin.Punishments.Save()
    game.ConsoleCommand("removeid " .. steamid .. "\n")
    game.ConsoleCommand("writeid\n")

    if DAdmin.History and DAdmin.History.Add then
        local aName, aSteam = adminInfo(admin)
        DAdmin.History.Add(steamid, "punishments", { type = "unban", admin = aName, adminSteamID = aSteam, previous = old, timestamp = now() })
    end

    if DAdmin.Log then DAdmin.Log("unban", admin, steamid, "") end
    return true
end

function DAdmin.Punishments.Mute(admin, target, length, reason)
    if not can(admin, "mute") then return false, "permission denied" end
    length = tonumber(length or 0) or 0
    local count = 0

    for _, ply in ipairs(resolved(admin, target)) do
        local aName, aSteam = adminInfo(admin)
        local mute = recordPunishment("mute", admin, ply, {
            name = ply:Nick(),
            steamid = ply:SteamID(),
            admin = aName,
            adminSteamID = aSteam,
            reason = reason or "Muted",
            created = now(),
            length = length,
            expires = expiry(length)
        })
        DAdmin.Mutes[ply:SteamID()] = mute
        if DAdmin.Log then DAdmin.Log("mute", admin, ply, mute.reason) end
        DAdmin.Msg(ply, "You have been muted.")
        count = count + 1
    end

    DAdmin.Punishments.Save()
    return count > 0
end

function DAdmin.Punishments.Unmute(admin, target)
    if not can(admin, "mute") then return false, "permission denied" end
    local count = 0
    for _, ply in ipairs(resolved(admin, target)) do
        DAdmin.Mutes[ply:SteamID()] = nil
        if DAdmin.History and DAdmin.History.Add then DAdmin.History.Add(ply:SteamID(), "punishments", { type = "unmute", timestamp = now() }) end
        if DAdmin.Log then DAdmin.Log("unmute", admin, ply, "") end
        DAdmin.Msg(ply, "You have been unmuted.")
        count = count + 1
    end
    DAdmin.Punishments.Save()
    return count > 0
end

function DAdmin.Punishments.Gag(admin, target, length, reason)
    if not can(admin, "gag") then return false, "permission denied" end
    length = tonumber(length or 0) or 0
    local count = 0

    for _, ply in ipairs(resolved(admin, target)) do
        local aName, aSteam = adminInfo(admin)
        local gag = recordPunishment("gag", admin, ply, {
            name = ply:Nick(),
            steamid = ply:SteamID(),
            admin = aName,
            adminSteamID = aSteam,
            reason = reason or "Gagged",
            created = now(),
            length = length,
            expires = expiry(length)
        })
        DAdmin.Gags[ply:SteamID()] = gag
        if DAdmin.Log then DAdmin.Log("gag", admin, ply, gag.reason) end
        DAdmin.Msg(ply, "You have been gagged.")
        count = count + 1
    end

    DAdmin.Punishments.Save()
    return count > 0
end

function DAdmin.Punishments.Ungag(admin, target)
    if not can(admin, "gag") then return false, "permission denied" end
    local count = 0
    for _, ply in ipairs(resolved(admin, target)) do
        DAdmin.Gags[ply:SteamID()] = nil
        if DAdmin.History and DAdmin.History.Add then DAdmin.History.Add(ply:SteamID(), "punishments", { type = "ungag", timestamp = now() }) end
        if DAdmin.Log then DAdmin.Log("ungag", admin, ply, "") end
        DAdmin.Msg(ply, "You have been ungagged.")
        count = count + 1
    end
    DAdmin.Punishments.Save()
    return count > 0
end

function DAdmin.Punishments.GetActiveForSteamID(steamid)
    steamid = tostring(steamid or "")
    return {
        ban = DAdmin.Bans and DAdmin.Bans[steamid] or nil,
        mute = DAdmin.Mutes and DAdmin.Mutes[steamid] or nil,
        gag = DAdmin.Gags and DAdmin.Gags[steamid] or nil
    }
end

function DAdmin.Punishments.CountBansToday()
    local start = os.time({ year = tonumber(os.date("%Y")), month = tonumber(os.date("%m")), day = tonumber(os.date("%d")), hour = 0 })
    local count = 0
    for _, ban in pairs(DAdmin.Bans or {}) do
        if (ban.created or 0) >= start then count = count + 1 end
    end
    return count
end

function DAdmin.Punishments.PruneExpired()
    local changed = false
    for steamid, ban in pairs(DAdmin.Bans or {}) do
        if isExpired(ban) then
            DAdmin.Bans[steamid] = nil
            if DAdmin.History and DAdmin.History.Add then DAdmin.History.Add(steamid, "punishments", { type = "ban_expired", previous = ban, timestamp = now() }) end
            changed = true
        end
    end
    for steamid, mute in pairs(DAdmin.Mutes or {}) do
        if isExpired(mute) then
            DAdmin.Mutes[steamid] = nil
            if DAdmin.History and DAdmin.History.Add then DAdmin.History.Add(steamid, "punishments", { type = "mute_expired", previous = mute, timestamp = now() }) end
            changed = true
        end
    end
    for steamid, gag in pairs(DAdmin.Gags or {}) do
        if isExpired(gag) then
            DAdmin.Gags[steamid] = nil
            if DAdmin.History and DAdmin.History.Add then DAdmin.History.Add(steamid, "punishments", { type = "gag_expired", previous = gag, timestamp = now() }) end
            changed = true
        end
    end
    if changed then DAdmin.Punishments.Save() end
end

DAdmin.Punishments.Load()

timer.Create("DAdmin_PunishmentPrune", 30, 0, DAdmin.Punishments.PruneExpired)

hook.Add("PlayerInitialSpawn", "DAdmin_BanEnforce", function(ply)
    timer.Simple(1, function()
        if not IsValid(ply) then return end
        DAdmin.Punishments.PruneExpired()
        local ban = DAdmin.Bans and DAdmin.Bans[ply:SteamID()]
        if ban then
            ply:Kick("[DAdmin] Banned: " .. tostring(ban.reason or "Banned"))
        end
    end)
end)

hook.Add("PlayerSay", "DAdmin_MuteEnforce", function(ply, text)
    if not IsValid(ply) then return end
    DAdmin.Punishments.PruneExpired()
    if DAdmin.Mutes and DAdmin.Mutes[ply:SteamID()] then
        DAdmin.Msg(ply, "You are muted.")
        return ""
    end
end)

hook.Add("PlayerCanHearPlayersVoice", "DAdmin_GagEnforce", function(listener, talker)
    if IsValid(talker) then
        DAdmin.Punishments.PruneExpired()
        if DAdmin.Gags and DAdmin.Gags[talker:SteamID()] then return false end
    end
end)
