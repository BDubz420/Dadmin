if SERVER then return end

DAdmin = DAdmin or {}
DAdmin.Port = DAdmin.Port or {}
local P = DAdmin.Port

P.State = P.State or {
    dashboard = { stats = {}, actions = {}, server = { players = 0, maxPlayers = 0, map = game.GetMap(), ping = 0, version = "v2.2.0" } },
    players = {}, reports = {}, ranks = {}, logs = {}, commands = {}, settings = {}, gamemode = {},
    permissionGroups = {}, permissionCategories = {}, permissionMatrix = {}, cases = {}, histories = {}, activeSits = {}, bans = {}, mutes = {}, gags = {}, intelligence = {}, staffControl = {}, currentUser = {}, guard = { config = {}, modules = {}, alerts = {}, stats = {} }
}

function P.SetState(state)
    if istable(state) then P.State = state end
end
function P.GetState() return P.State or {} end
function P.GetServer() return (P.State.dashboard and P.State.dashboard.server) or {} end
function P.GetDashboardStats() return (P.State.dashboard and P.State.dashboard.stats) or {} end
function P.GetRecentActions() return (P.State.dashboard and P.State.dashboard.actions) or {} end
function P.GetPlayers() return P.State.players or {} end
function P.GetReports() return P.State.reports or {} end
function P.GetRanks() return P.State.ranks or {} end
function P.GetLogs() return P.State.logs or {} end
function P.GetCommands() return P.State.commands or {} end
function P.GetSettings() return P.State.settings or {} end
function P.GetPermissionGroups() return P.State.permissionGroups or {} end
function P.GetPermissionCategories() return P.State.permissionCategories or {} end
function P.GetPermissionMatrix() return P.State.permissionMatrix or {} end
function P.GetCases() return P.State.cases or {} end
function P.GetHistories() return P.State.histories or {} end
function P.GetActiveSits() return P.State.activeSits or {} end
function P.GetBans() return P.State.bans or {} end
function P.GetMutes() return P.State.mutes or {} end
function P.GetGags() return P.State.gags or {} end
function P.GetScreengrabs() return P.State.screengrabs or {} end
function P.GetCurrentUser() return P.State.currentUser or {} end
function P.HasPermission(perm)
    perm = string.lower(tostring(perm or ""))
    if perm == "" then return true end

    local user = P.GetCurrentUser()
    local perms = user.permissions or {}
    if perms["*"] == true then return true end
    if perms[perm] == true then return true end
    if perm == "menu" then
        return perms.admin == true or perms.menu == true
    end

    return false
end

function P.Refresh()
    net.Start("DAdmin_UIAction")
    net.WriteString("refresh")
    net.WriteTable({})
    net.SendToServer()
end

function P.UIAction(action, payload)
    net.Start("DAdmin_UIAction")
    net.WriteString(action)
    net.WriteTable(payload or {})
    net.SendToServer()
end

function P.RunCommand(commandName, target, extra)
    local args = {}
    if target and target ~= "" then args[#args + 1] = target end
    if extra and extra ~= "" then args[#args + 1] = extra end
    P.UIAction("command", { command = commandName, args = args })
end

function P.GetIntelligence() return P.State.intelligence or {} end
function P.GetStaffControl() return P.State.staffControl or {} end

function P.GetGamemode() return P.State.gamemode or { id = "sandbox", name = "Sandbox", features = { jobs = false }, playerColumns = {} } end
function P.HasGamemodeFeature(feature)
    local gm = P.GetGamemode()
    return gm.features and gm.features[feature] == true
end
function P.GetPlayerColumns()
    local gm = P.GetGamemode()
    return gm.playerColumns or {}
end

function P.GetGuard() return P.State.guard or { config = {}, modules = {}, alerts = {}, stats = {} } end
