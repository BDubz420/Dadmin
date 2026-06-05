if CLIENT then return end
DAdmin = DAdmin or {}
DAdmin.PlayTime = DAdmin.PlayTime or { Data = {} }
DAdmin.PlayTime.File = "playtime.json"

util.AddNetworkString("DAdmin_PlayTime_Request")
util.AddNetworkString("DAdmin_PlayTime_Send")
util.AddNetworkString("DAdmin_PlayTime_Admin")

local function cfg() return DAdmin.GetFeatureConfig and DAdmin.GetFeatureConfig() or {} end
local function now() return os.time() end
local function sid64(ply) return IsValid(ply) and ply:SteamID64() or nil end

DAdmin.PlayTime.Data = DAdmin.Storage and DAdmin.Storage.Load and DAdmin.Storage.Load(DAdmin.PlayTime.File, {}) or {}

local saveQueued = false
local function save()
    if saveQueued then return end
    saveQueued = true
    timer.Simple(2, function()
        saveQueued = false
        if DAdmin.Storage and DAdmin.Storage.Save then
            DAdmin.Storage.Save(DAdmin.PlayTime.File, DAdmin.PlayTime.Data or {})
        end
    end)
end

function DAdmin.PlayTime.GetRecord(id)
    id = tostring(id or "")
    if id == "" then id = "unknown" end
    DAdmin.PlayTime.Data[id] = DAdmin.PlayTime.Data[id] or {
        total = 0,
        last_name = "Unknown",
        first_join = now(),
        last_seen = now(),
        steamid64 = id
    }
    return DAdmin.PlayTime.Data[id]
end

local function findPlayerBy64(id)
    id = tostring(id or "")
    for _, ply in ipairs(player.GetAll()) do
        if ply:SteamID64() == id then return ply end
    end
end

function DAdmin.PlayTime.GetTotal(plyOrId)
    local ply = IsEntity(plyOrId) and plyOrId or findPlayerBy64(plyOrId)
    local id = IsValid(ply) and ply:SteamID64() or tostring(plyOrId or "")
    local rec = DAdmin.PlayTime.GetRecord(id)
    local total = tonumber(rec.total or 0) or 0
    if IsValid(ply) and ply.DAdminPlayTimeJoin then
        total = total + math.max(0, now() - ply.DAdminPlayTimeJoin)
    end
    return total
end

function DAdmin.PlayTime.Format(seconds)
    seconds = math.max(0, tonumber(seconds or 0) or 0)
    local d = math.floor(seconds / 86400)
    local h = math.floor((seconds % 86400) / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = math.floor(seconds % 60)
    if d > 0 then return string.format("%dd %02dh %02dm", d, h, m) end
    if h > 0 then return string.format("%02dh %02dm", h, m) end
    return string.format("%02dm %02ds", m, s)
end

local function snapshot(ply)
    if cfg().playtime_enabled == false or not IsValid(ply) then return end
    local id = sid64(ply)
    local rec = DAdmin.PlayTime.GetRecord(id)
    rec.last_name = ply:Nick()
    rec.steamid = ply:SteamID()
    rec.steamid64 = id
    rec.last_seen = now()
    if not rec.first_join then rec.first_join = now() end
    if ply.DAdminPlayTimeJoin then
        rec.total = (tonumber(rec.total or 0) or 0) + math.max(0, now() - ply.DAdminPlayTimeJoin)
        ply.DAdminPlayTimeJoin = now()
    end
    save()
end

hook.Add("PlayerInitialSpawn", "DAdminPlayTimeStart", function(ply)
    if cfg().playtime_enabled == false then return end
    ply.DAdminPlayTimeJoin = now()
    local rec = DAdmin.PlayTime.GetRecord(ply:SteamID64())
    rec.last_name = ply:Nick()
    rec.steamid = ply:SteamID()
    rec.steamid64 = ply:SteamID64()
    rec.first_join = rec.first_join or now()
    rec.last_seen = now()
    save()
end)

hook.Add("PlayerDisconnected", "DAdminPlayTimeSave", snapshot)

timer.Create("DAdminPlayTimeSave", 60, 0, function()
    if cfg().playtime_enabled == false then return end
    for _, ply in ipairs(player.GetAll()) do snapshot(ply) end
end)

local function buildBlock(target)
    if not IsValid(target) then return nil end
    local id = target:SteamID64()
    local rec = DAdmin.PlayTime.GetRecord(id)
    local total = DAdmin.PlayTime.GetTotal(target)
    local session = target.DAdminPlayTimeJoin and math.max(0, now() - target.DAdminPlayTimeJoin) or 0
    return {
        name = target:Nick(),
        steamid = target:SteamID(),
        steamid64 = id,
        total = total,
        total_text = DAdmin.PlayTime.Format(total),
        session = session,
        session_text = DAdmin.PlayTime.Format(session),
        first_join = rec.first_join,
        last_seen = rec.last_seen
    }
end

local function sendTo(ply, target)
    if cfg().playtime_enabled == false then
        net.Start("DAdmin_PlayTime_Send")
        net.WriteTable({ enabled = false })
        net.Send(ply)
        return
    end
    local records = {}
    for sid, rec in pairs(DAdmin.PlayTime.Data or {}) do
        records[#records + 1] = {
            steamid64 = sid,
            name = rec.last_name or sid,
            total = tonumber(rec.total or 0) or 0,
            total_text = DAdmin.PlayTime.Format(rec.total or 0),
            last_seen = rec.last_seen or 0
        }
    end

    table.sort(records, function(a,b)
        return (a.total or 0) > (b.total or 0)
    end)

    local data = {
        enabled = cfg().playtime_enabled ~= false,
        hud = cfg().playtime_hud_enabled ~= false,
        color = cfg().playtime_hud_color or "4A90D9",
        accent = cfg().playtime_hud_accent or "90AAE9",
        server_time = now(),
        records = records,
        local_player = buildBlock(ply),
        target = IsValid(target) and target ~= ply and buildBlock(target) or nil
    }
    net.Start("DAdmin_PlayTime_Send")
    net.WriteTable(data)
    net.Send(ply)
end

net.Receive("DAdmin_PlayTime_Request", function(_, ply)
    local ent = Entity(net.ReadUInt(16) or 0)
    sendTo(ply, IsValid(ent) and ent:IsPlayer() and ent or nil)
end)

net.Receive("DAdmin_PlayTime_Admin", function(_, ply)
    if not (DAdmin.HasPermission and DAdmin.HasPermission(ply, "playtime.manage")) then return end
    local mode = string.lower(net.ReadString() or "")
    local id = tostring(net.ReadString() or "")
    local seconds = tonumber(net.ReadString() or "0") or 0
    if id == "" then return end
    local rec = DAdmin.PlayTime.GetRecord(id)
    if mode == "set" then
        rec.total = math.max(0, seconds)
    elseif mode == "add" then
        rec.total = math.max(0, (tonumber(rec.total or 0) or 0) + seconds)
    elseif mode == "reset" then
        rec.total = 0
    end
    rec.last_seen = now()
    save()
    if DAdmin.MegaLogs then DAdmin.MegaLogs.Add("playtime", mode, ply, id, tostring(seconds)) end
    sendTo(ply, ply)
end)
