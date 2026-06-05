DAdmin = DAdmin or {}

util.AddNetworkString("DAdmin_RequestPlayers")
util.AddNetworkString("DAdmin_RequestLogs")
util.AddNetworkString("DAdmin_RequestRanks")
util.AddNetworkString("DAdmin_RequestReports")
util.AddNetworkString("DAdmin_RequestCases")
util.AddNetworkString("DAdmin_RequestDashboard")
util.AddNetworkString("DAdmin_RequestRadarAlerts")
util.AddNetworkString("DAdmin_RunCommand")
util.AddNetworkString("dadmin_log_update")
util.AddNetworkString("dadmin_case_update")
util.AddNetworkString("dadmin_player_update")
util.AddNetworkString("dadmin_rank_update")
util.AddNetworkString("dadmin_report_update")
util.AddNetworkString("dadmin_open_menu")
util.AddNetworkString("dadmin_request_open_menu")

local function hasMenu(ply)
    if DAdmin.Security and DAdmin.Security.CanUseMenu then
        return DAdmin.Security.CanUseMenu(ply)
    end
    return IsValid(ply) and (ply:IsAdmin() or ply:IsSuperAdmin())
end

net.Receive("dadmin_request_open_menu", function(_, ply)
    local tab = string.sub(tostring(net.ReadString() or ""), 1, 32)
    if not hasMenu(ply) then return end
    net.Start("dadmin_open_menu")
    net.WriteString(tab)
    net.Send(ply)
end)

local function check(ply, key, perm, burst, window)
    if DAdmin.Security then
        return DAdmin.Security.CheckNet(ply, key, { permission = perm or "menu", burst = burst or 5, window = window or 1 })
    end
    return hasMenu(ply)
end

local function sendTable(name, ply, data)
    if not IsValid(ply) then return end
    net.Start(name)
    net.WriteTable(DAdmin.Security and DAdmin.Security.SanitizeTable(data or {}) or (data or {}))
    net.Send(ply)
end

net.Receive("DAdmin_RequestRadarAlerts", function(_, ply)
    if not check(ply, "request:radar", "admin", 4, 1) then return end
    sendTable("DAdmin_RequestRadarAlerts", ply, DAdmin.Radar and DAdmin.Radar.GetRecentAlerts and DAdmin.Radar.GetRecentAlerts(10) or {})
end)

net.Receive("DAdmin_RequestPlayers", function(_, ply)
    if not check(ply, "request:players", "menu", 6, 1) then return end
    local players = {}
    for _, p in ipairs(player.GetAll()) do
        players[#players + 1] = {
            name = p:Nick(),
            steamid = p:SteamID(),
            rank = DAdmin.GetUserRank and DAdmin.GetUserRank(p) or "user",
            ping = p:Ping()
        }
    end
    sendTable("DAdmin_RequestPlayers", ply, players)
end)

net.Receive("DAdmin_RequestLogs", function(_, ply)
    if not check(ply, "request:logs", "logs", 4, 1) then return end
    sendTable("DAdmin_RequestLogs", ply, DAdmin.LoadLogs and DAdmin.LoadLogs() or DAdmin.Logs or {})
end)

net.Receive("DAdmin_RequestRanks", function(_, ply)
    if not check(ply, "request:ranks", "rank", 4, 1) then return end
    sendTable("DAdmin_RequestRanks", ply, DAdmin.Ranks or {})
end)

net.Receive("DAdmin_RequestReports", function(_, ply)
    if not check(ply, "request:reports", "reports", 6, 1) then return end
    sendTable("DAdmin_RequestReports", ply, DAdmin.Reports and DAdmin.Reports.GetAll and DAdmin.Reports.GetAll() or {})
end)

net.Receive("DAdmin_RequestCases", function(_, ply)
    if not check(ply, "request:cases", "cases", 4, 1) then return end
    sendTable("DAdmin_RequestCases", ply, DAdmin.Cases and DAdmin.Cases.GetAll and DAdmin.Cases.GetAll() or {})
end)

net.Receive("DAdmin_RequestDashboard", function(_, ply)
    if not check(ply, "request:dashboard", "menu", 6, 1) then return end
    sendTable("DAdmin_RequestDashboard", ply, {
        players = #player.GetAll(),
        reports = DAdmin.Reports and DAdmin.Reports.GetAll and DAdmin.Reports.GetAll() or {},
        metrics = DAdmin.Metrics or {}
    })
end)

net.Receive("DAdmin_RunCommand", function(_, ply)
    if not check(ply, "runcommand", "menu", 4, 1) then return end
    local cmd = string.lower(string.sub(tostring(net.ReadString() or ""), 1, 64))
    local args = net.ReadTable() or {}
    args = DAdmin.Security and DAdmin.Security.SanitizeTable(args) or args
    local cmdData = DAdmin.GetCommand and DAdmin.GetCommand(cmd)
    if not istable(cmdData) or not isfunction(cmdData.run) then return end
    if cmdData.permission and DAdmin.HasPermission and not DAdmin.HasPermission(ply, cmdData.permission) then return end
    DAdmin.RunCommand(ply, cmd, args)
end)

local refreshQueued = false
local function broadcastRefresh()
    if refreshQueued then return end
    refreshQueued = true
    timer.Simple(0.15, function()
        refreshQueued = false
        if not DAdmin.SendUIState then return end
        for _, ply in ipairs(player.GetAll()) do
            if hasMenu(ply) then DAdmin.SendUIState(ply) end
        end
    end)
end

function DAdmin.BroadcastLogUpdate()
    net.Start("dadmin_log_update")
    net.Broadcast()
    broadcastRefresh()
end

function DAdmin.BroadcastCaseUpdate()
    net.Start("dadmin_case_update")
    net.Broadcast()
    broadcastRefresh()
end

function DAdmin.BroadcastPlayerUpdate()
    net.Start("dadmin_player_update")
    net.Broadcast()
    broadcastRefresh()
end

function DAdmin.BroadcastRankUpdate()
    net.Start("dadmin_rank_update")
    net.Broadcast()
    if DAdmin.InvalidatePermissionCache then DAdmin.InvalidatePermissionCache() end
    broadcastRefresh()
end

function DAdmin.BroadcastReportUpdate()
    net.Start("dadmin_report_update")
    net.Broadcast()
    broadcastRefresh()
end
