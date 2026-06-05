if CLIENT then return end

DAdmin = DAdmin or {}
DAdmin.Config = DAdmin.Config or {}

util.AddNetworkString("DAdmin_UIState")
util.AddNetworkString("DAdmin_UIAction")

local DEFAULT_CONFIG = {
    server_name = "My GMod Server", prefix = "!", default_rank = "user", max_warns = "3",
    ban_on_warns = false, immunity_check = true, log_commands = true, log_chat = false, log_retention = "30",
    notify_kick = true, notify_ban = true, notify_report = true, notify_join = false,
    motd = "Welcome to the server! Please read the rules.",
    prefix_color = "4A90D9", chat_log_commands = false, chat_log_permissions = false, motd_on_join = true,
    playtime_enabled = true, playtime_hud_enabled = true, safezones_enabled = true, safezone_ui_enabled = true,
    chat_protection_enabled = false, chat_protection_block = true, chat_blocked_phrases = ""
}

local function copy(t) return table.Copy(t or {}) end
local function ensureConfig()
    DAdmin.Config = table.Merge(copy(DEFAULT_CONFIG), (DAdmin.Storage and DAdmin.Storage.Load and DAdmin.Storage.Load("config.json", {})) or DAdmin.Config or {})
end
local function saveConfig()
    if DAdmin.Storage and DAdmin.Storage.Save then DAdmin.Storage.Save("config.json", DAdmin.Config or {}) end
end
ensureConfig()

local rankColors = {
    owner = Color(136,85,204), superadmin = Color(204,68,68), admin = Color(204,170,68),
    moderator = Color(90,170,106), trusted = Color(74,144,217), user = Color(122,126,138)
}
local function rankColor(rank)
    return rankColors[string.lower(rank or "user")] or rankColors.user
end
local function titleCase(id)
    return string.upper(string.sub(id,1,1)) .. string.sub(id,2)
end

local function getGamemodeProfile()
    if DAdmin.Gamemode and DAdmin.Gamemode.GetProfile then return DAdmin.Gamemode.GetProfile() end
    return { id = "sandbox", name = "Sandbox", family = "sandbox", features = { jobs = false }, playerColumns = {
        { key = "name", label = "Name", width = 0.32 },
        { key = "rank", label = "Rank", width = 0.20 },
        { key = "health", label = "HP", width = 0.12 },
        { key = "armor", label = "Armor", width = 0.12 },
        { key = "ping", label = "Ping", width = 0.12 },
        { key = "time", label = "Time", width = 0.12 },
    } }
end

local function getTTTRole(p)
    if not IsValid(p) then return "Unknown" end
    if p.GetRoleString then return tostring(p:GetRoleString()) end
    if p.GetRole then
        local role = p:GetRole()
        if ROLE_TRAITOR and role == ROLE_TRAITOR then return "Traitor" end
        if ROLE_DETECTIVE and role == ROLE_DETECTIVE then return "Detective" end
        if ROLE_INNOCENT and role == ROLE_INNOCENT then return "Innocent" end
        return tostring(role)
    end
    return "Unknown"
end

local function addGamemodePlayerFields(row, p, profile)
    local features = (profile and profile.features) or {}
    row.team = team.GetName and team.GetName(p:Team()) or tostring(p:Team())
    if features.jobs then
        row.job = team.GetName and team.GetName(p:Team()) or "Unknown"
        if p.getDarkRPVar then
            local money = p:getDarkRPVar("money")
            local salary = p:getDarkRPVar("salary")
            row.wallet = money and DarkRP and DarkRP.formatMoney and DarkRP.formatMoney(money) or (money and tostring(money) or "-")
            row.salary = salary and DarkRP and DarkRP.formatMoney and DarkRP.formatMoney(salary) or (salary and tostring(salary) or "-")
            row.wanted = p:getDarkRPVar("wanted") and "Yes" or "No"
            row.arrested = p:getDarkRPVar("Arrested") and "Yes" or "No"
        end
    else
        row.job = nil
        row.wallet = nil
        row.salary = nil
        row.wanted = nil
        row.arrested = nil
    end
    if features.ttt then
        row.role = getTTTRole(p)
        row.karma = p.GetBaseKarma and math.floor(p:GetBaseKarma()) or (p.GetLiveKarma and math.floor(p:GetLiveKarma()) or "-")
    elseif features.murder then
        row.role = p.GetMurderer and (p:GetMurderer() and "Murderer" or "Bystander") or "-"
    elseif features.teams and not features.jobs then
        row.role = row.team
    else
        row.role = nil
        row.karma = nil
    end
end


local function getUserRank(plyOrSteamid)
    if DAdmin.GetUserRank then
        return DAdmin.GetUserRank(IsEntity(plyOrSteamid) and plyOrSteamid:SteamID() or plyOrSteamid)
    end
    return "user"
end

local function buildPlayers()
    local out = {}
    local profile = getGamemodeProfile()
    for _, p in ipairs(player.GetAll()) do
        local rank = getUserRank(p)
        local sid = p:SteamID()
        local allWarns = DAdmin.Warns and DAdmin.Warns.GetForSteamID and DAdmin.Warns.GetForSteamID(sid) or {}
        local warns = {}
        local startIdx = math.max(1, #allWarns - 19)
        for wi = startIdx, #allWarns do warns[#warns + 1] = allWarns[wi] end
        local row = {
            id = sid,
            entindex = p:EntIndex(),
            name = p:Nick(),
            steamid = sid,
            rank = titleCase(rank),
            health = math.max(p:Health(), 0),
            armor = math.max(p:Armor(), 0),
            ping = p:Ping(),
            time = "online",
            rankColor = rankColor(rank),
            warnings = warns
        }
        addGamemodePlayerFields(row, p, profile)
        out[#out + 1] = row
    end
    table.sort(out, function(a,b) return a.name < b.name end)
    return out
end

local function buildReports()
    local out = {}
    for _, r in ipairs(DAdmin.Reports and DAdmin.Reports.GetAll and DAdmin.Reports.GetAll() or {}) do
        local reporter = DAdmin.Players and DAdmin.Players.FindBySteamID and DAdmin.Players.FindBySteamID(r.reporterSteamID)
        local target = DAdmin.Players and DAdmin.Players.FindBySteamID and DAdmin.Players.FindBySteamID(r.targetSteamID)
        out[#out + 1] = {
            id = r.id,
            reporter = IsValid(reporter) and reporter:Nick() or (r.reporterName or r.reporterSteamID or "Unknown"),
            target = IsValid(target) and target:Nick() or (r.targetName or r.targetSteamID or "Unknown"),
            reporterSteamID = r.reporterSteamID,
            targetSteamID = r.targetSteamID,
            reason = r.reason or "",
            status = r.status or "open",
            priority = r.priority or "medium",
            time = os.date("%H:%M", r.timestamp or os.time()),
            claimedBy = r.claimedByName or (r.claimedBy and (DAdmin.Players.FindBySteamID and IsValid(DAdmin.Players.FindBySteamID(r.claimedBy)) and DAdmin.Players.FindBySteamID(r.claimedBy):Nick() or r.claimedBy) or nil),
            closedBy = r.closedByName or r.closedBy,
            resolution = r.resolution,
            caseID = r.caseID,
            sitID = r.sitID
        }
    end
    return out
end

local function buildRanks()
    local out = {}
    for id, info in pairs(DAdmin.Ranks or {}) do
        if istable(info) and tonumber(info.immunity) ~= nil then
            local members = 0
            for _, rank in pairs(DAdmin.Users or {}) do if rank == id then members = members + 1 end end
            out[#out + 1] = {
                id = id, label = info.label or titleCase(id), color = rankColor(id), immunity = tonumber(info.immunity) or 0,
                inherits = info.inherit, members = members,
                settings = copy(info.settings or {
                    target_same = false, access_menu = true, receive_alerts = true, immune_selectors = true
                })
            }
        end
    end
    table.sort(out, function(a,b) return (a.immunity or 0) > (b.immunity or 0) end)
    return out
end

local function buildLogs()
    local all = DAdmin.LoadLogs and DAdmin.LoadLogs() or DAdmin.GetLogs()
    local out = {}
    local startIdx = math.max(1, #all - 199)
    for i = startIdx, #all do
        local log = all[i]
        out[#out + 1] = {
            id = log.id or tostring(i), time = log.time or os.date("%H:%M:%S", log.timestamp or os.time()), admin = log.admin or "System",
            action = log.action or "event", target = log.target or "-", reason = log.reason or log.details or "", type = log.type or "admin"
        }
    end
    return out
end

local function trimArray(arr, maxLen)
    if not istable(arr) then return {} end
    if #arr <= maxLen then return arr end
    local out = {}
    for i = #arr - maxLen + 1, #arr do out[#out + 1] = arr[i] end
    return out
end

local function buildHistorySummaries()
    local out = {}
    local all = DAdmin.History and DAdmin.History.GetAll and DAdmin.History.GetAll() or {}
    local count = 0
    for steamid, record in pairs(all) do
        count = count + 1
        if count > 50 then break end
        local names = {}
        if istable(record.names) then
            for name in pairs(record.names) do
                names[#names + 1] = tostring(name)
            end
        end
        table.sort(names, function(a, b)
            return string.lower(tostring(a or "")) < string.lower(tostring(b or ""))
        end)
        out[#out + 1] = {
            steamid = tostring(steamid or ""),
            name = names[1] or tostring(steamid or ""),
            names = trimArray(names, 5),
            firstSeen = record.firstSeen,
            lastSeen = record.lastSeen,
            summary = record.summary or {},
            warnings = trimArray(record.warnings, 10),
            bans = trimArray(record.bans, 10),
            kicks = trimArray(record.kicks, 10),
            reports = trimArray(record.reports, 10),
            sits = trimArray(record.sits, 5),
            cases = trimArray(record.cases, 5),
            punishments = trimArray(record.punishments, 10),
            notes = trimArray(record.notes, 5)
        }
    end
    table.sort(out, function(a,b)
        return string.lower(tostring(a.name or "")) < string.lower(tostring(b.name or ""))
    end)
    return out
end

local function buildScreengrabs()
    local out = {}
    for steamid, entries in pairs(DAdmin.Screengrabs or {}) do
        if istable(entries) then
            out[steamid] = {}
            for i = 1, math.min(#entries, 10) do
                out[steamid][i] = copy(entries[i])
            end
        end
    end
    return out
end

local function buildCommands()
    local out = {}
    for name, cmd in pairs(DAdmin.GetCommands and DAdmin.GetCommands() or {}) do
        -- DAdmin.Commands also carries compatibility methods; only expose real command definitions.
        if istable(cmd) and isfunction(cmd.run) then
            local args = {}
            local hasTarget = false
            for _, a in ipairs(cmd.args or {}) do
                if istable(a) then
                    local n = a.name or a.type or "arg"
                    args[#args + 1] = (a.optional and "[" or "<") .. tostring(n) .. (a.optional and "]" or ">")
                    local t = string.lower(tostring(a.type or ""))
                    if t == "player" or t == "players" or t == "target" then hasTarget = true end
                else
                    args[#args + 1] = tostring(a)
                end
            end

            local category = string.lower(tostring(cmd.category or "admin"))
            out[#out + 1] = {
                name = tostring(name),
                cat = category == "movement" and "movement" or (category == "moderation" and "player" or "admin"),
                usage = "dadmin " .. tostring(name) .. (#args > 0 and (" " .. table.concat(args, " ")) or ""),
                args = args,
                perm = cmd.permission or name,
                desc = tostring(cmd.description or "No description."),
                hasTarget = hasTarget
            }
        end
    end
    table.sort(out, function(a,b) return tostring(a.name) < tostring(b.name) end)
    return out
end

local BASE_PERMISSION_CATEGORIES = {
    ["Access"] = {
        { id = "menu", label = "Open Admin Menu" },
        { id = "broadcast", label = "Broadcast Messages" },
        { id = "admin", label = "System Admin" },
        { id = "logs", label = "View / Manage Logs" },
    },
    ["Reports / Cases"] = {
        { id = "report", label = "Submit Reports" },
        { id = "reports", label = "Handle Reports" },
        { id = "reports.override", label = "Override Claims" },
        { id = "sits", label = "Manage Sits" },
        { id = "cases", label = "View Cases" },
        { id = "cases.close", label = "Close / Merge Cases" },
    },
    ["Guard / Anti-Cheat"] = {
        { id = "guard", label = "View Guard" },
        { id = "guard.admin", label = "Configure Guard" },
        { id = "screengrab", label = "Request Screengrabs" },
    },
    ["Ranks"] = {
        { id = "rank", label = "Rank Management" },
        { id = "permissions", label = "Permission Matrix" },
    }
}

local function permissionLabel(id)
    id = tostring(id or "")
    local last = string.match(id, "([^%.]+)$") or id
    last = string.Replace(last, "_", " ")
    return string.upper(string.sub(last, 1, 1)) .. string.sub(last, 2)
end

local function normalizePermCategory(cat)
    cat = string.lower(tostring(cat or "admin"))
    if cat == "player" or cat == "players" or cat == "moderation" then return "Player Commands" end
    if cat == "movement" then return "Movement" end
    if cat == "reports" or cat == "cases" or cat == "sits" then return "Reports / Cases" end
    if cat == "guard" or cat == "anticheat" or cat == "anti-cheat" then return "Guard / Anti-Cheat" end
    if cat == "rank" or cat == "ranks" or cat == "permissions" then return "Ranks" end
    if cat == "system" or cat == "config" or cat == "server" then return "System / Config" end
    return "Admin Tools"
end

local function buildPermissionCategories()
    local buckets, seen = {}, {}
    local function add(cat, id, label, usage)
        id = tostring(id or "")
        if id == "" or seen[id] then return end
        seen[id] = true
        cat = cat or "Admin Tools"
        buckets[cat] = buckets[cat] or {}
        buckets[cat][#buckets[cat] + 1] = {
            id = id,
            label = tostring(label or permissionLabel(id)),
            usage = usage
        }
    end

    for cat, perms in pairs(BASE_PERMISSION_CATEGORIES) do
        for _, perm in ipairs(perms) do add(cat, perm.id, perm.label, perm.usage) end
    end

    for name, cmd in pairs(DAdmin.GetCommands and DAdmin.GetCommands() or {}) do
        if istable(cmd) and isfunction(cmd.run) then
            local perm = tostring(cmd.permission or name)
            local args = {}
            for _, a in ipairs(cmd.args or {}) do
                if istable(a) then
                    local n = a.name or a.type or "arg"
                    args[#args + 1] = (a.optional and "[" or "<") .. tostring(n) .. (a.optional and "]" or ">")
                else
                    args[#args + 1] = tostring(a)
                end
            end
            add(normalizePermCategory(cmd.category), perm, cmd.description or permissionLabel(perm), "dadmin " .. tostring(name) .. (#args > 0 and (" " .. table.concat(args, " ")) or ""))
        end
    end

    local order = {
        "Access", "Player Commands", "Movement", "Reports / Cases",
        "Guard / Anti-Cheat", "Ranks", "Admin Tools", "System / Config"
    }

    local out = {}
    for _, cat in ipairs(order) do
        if buckets[cat] then
            table.sort(buckets[cat], function(a, b) return tostring(a.label) < tostring(b.label) end)
            out[#out + 1] = { name = cat, perms = buckets[cat] }
            buckets[cat] = nil
        end
    end

    for cat, perms in pairs(buckets) do
        table.sort(perms, function(a, b) return tostring(a.label) < tostring(b.label) end)
        out[#out + 1] = { name = cat, perms = perms }
    end

    table.sort(out, function(a, b)
        local ia, ib = 999, 999
        for i, name in ipairs(order) do
            if a.name == name then ia = i end
            if b.name == name then ib = i end
        end
        if ia == ib then return tostring(a.name) < tostring(b.name) end
        return ia < ib
    end)

    return out
end

local function buildPermMatrix()
    local matrix = {}
    for rank, info in pairs(DAdmin.Ranks or {}) do
        if istable(info) then matrix[rank] = copy(info.permissions or {}) end
    end
    return matrix
end

local function buildCurrentUser(ply)
    local out = {
        steamid = IsValid(ply) and ply:SteamID() or "",
        name = IsValid(ply) and ply:Nick() or "Console",
        rank = IsValid(ply) and getUserRank(ply) or "owner",
        permissions = {}
    }

    local seen = {}
    local function mark(perm)
        perm = string.lower(tostring(perm or ""))
        if perm == "" or seen[perm] then return end
        seen[perm] = true
        out.permissions[perm] = DAdmin.HasPermission and DAdmin.HasPermission(ply, perm) or false
    end

    for _, perm in ipairs(DAdmin.GetAllPermissions and DAdmin.GetAllPermissions() or {}) do
        mark(perm)
    end

    for _, cat in ipairs(buildPermissionCategories()) do
        for _, perm in ipairs(cat.perms or {}) do
            mark(perm.id)
        end
    end

    for _, perm in ipairs({
        "menu", "admin", "broadcast", "reports", "history", "rank",
        "permissions", "permissions.view", "permissions.manage",
        "logs", "logs.view", "safezones.view", "safezones.manage",
        "playtime.view", "playtime.manage", "guard", "guard.admin",
        "cases", "settings.features"
    }) do
        mark(perm)
    end

    return out
end

local function countBansToday()
    return DAdmin.Punishments and DAdmin.Punishments.CountBansToday and DAdmin.Punishments.CountBansToday() or 0
end

local function buildDashboard(players, reports, logs)
    local activeAdmins = 0
    for _, p in ipairs(players) do
        local r = string.lower(p.rank or "")
        if r ~= "user" then activeAdmins = activeAdmins + 1 end
    end
    local openReports = 0
    for _, r in ipairs(reports) do if r.status ~= "resolved" then openReports = openReports + 1 end end
    return {
        stats = {
            { label = "Gamemode", value = tostring(getGamemodeProfile().name or "Sandbox"), color = rankColor("trusted") },
            { label = "Players Online", value = tostring(#players) .. "/" .. game.MaxPlayers(), color = rankColor("trusted") },
            { label = "Active Admins", value = tostring(activeAdmins), color = rankColor("moderator") },
            { label = "Open Reports", value = tostring(openReports), color = rankColor("admin") },
            { label = "Uptime", value = "Live", color = rankColor("moderator") },
            { label = "Bans Today", value = tostring(countBansToday()), color = rankColor("superadmin") },
            { label = "Warns Today", value = tostring(DAdmin.Warns and DAdmin.Warns.CountToday and DAdmin.Warns.CountToday() or 0), color = rankColor("admin") },
        },
        actions = logs,
        server = { players = #players, maxPlayers = game.MaxPlayers(), map = game.GetMap(), ping = 0, version = "v2.3.0 RC1", gamemode = getGamemodeProfile().name, gamemodeID = getGamemodeProfile().id }
    }
end


local function buildIntel()
    if DAdmin.Intel and DAdmin.Intel.GetSnapshot then
        return DAdmin.Intel.GetSnapshot()
    end
    return { config = {}, profiles = {}, staff = {}, counts = {} }
end

local function buildStaffControl()
    return {
        active = DAdmin.StaffControl and DAdmin.StaffControl.GetActive and DAdmin.StaffControl.GetActive() or {},
        locks = DAdmin.StaffControl and DAdmin.StaffControl.GetLocks and DAdmin.StaffControl.GetLocks() or {}
    }
end

local function buildState(ply)
    local players, reports, logs = buildPlayers(), buildReports(), buildLogs()
    return {
        players = players, reports = reports, logs = logs, ranks = buildRanks(), commands = buildCommands(),
        histories = buildHistorySummaries(),
        gamemode = getGamemodeProfile(),
        guard = DAdmin.Guard and DAdmin.Guard.GetState and DAdmin.Guard.GetState() or { config = {}, modules = {}, alerts = {}, stats = {} },
        intelligence = buildIntel(), staffControl = buildStaffControl(),
        cases = trimArray(DAdmin.Cases and DAdmin.Cases.GetAll and DAdmin.Cases.GetAll() or {}, 50),
        activeSits = DAdmin.Sits and DAdmin.Sits.GetActive and DAdmin.Sits.GetActive() or {},
        bans = DAdmin.Bans or {}, mutes = DAdmin.Mutes or {}, gags = DAdmin.Gags or {},
        screengrabs = buildScreengrabs(),
        settings = copy(DAdmin.Config), permissionGroups = {
            {id="user",label="User",color=rankColor("user")}, {id="trusted",label="Trusted",color=rankColor("trusted")}, {id="moderator",label="Mod",color=rankColor("moderator")},
            {id="admin",label="Admin",color=rankColor("admin")}, {id="superadmin",label="SAdmin",color=rankColor("superadmin")}, {id="owner",label="Owner",color=rankColor("owner")}
        },
        permissionCategories = buildPermissionCategories(),
        permissionMatrix = buildPermMatrix(),
        currentUser = buildCurrentUser(ply),
        dashboard = buildDashboard(players, reports, logs)
    }
end

local function canUse(ply)
    return DAdmin.Security and DAdmin.Security.CanUseMenu and DAdmin.Security.CanUseMenu(ply)
        or (IsValid(ply) and (ply:IsAdmin() or ply:IsSuperAdmin() or (DAdmin.HasPermission and DAdmin.HasPermission(ply, "menu"))))
end

function DAdmin.SendUIState(ply)
    if not IsValid(ply) then return end
    local ok, state = xpcall(function()
        return buildState(ply)
    end, debug.traceback)
    if not ok then
        ErrorNoHalt("[DAdmin] Failed to build UI state:\n" .. tostring(state) .. "\n")
        return
    end
    state = DAdmin.Security and DAdmin.Security.SanitizeTable(state) or state
    local json = util.TableToJSON(state)
    if not json then
        ErrorNoHalt("[DAdmin] Failed to serialize UI state\n")
        return
    end
    local compressed = util.Compress(json)
    if not compressed then
        ErrorNoHalt("[DAdmin] Failed to compress UI state\n")
        return
    end
    local len = #compressed
    if len > 65000 then
        ErrorNoHalt("[DAdmin] UI state too large even after compression: " .. tostring(len) .. " bytes\n")
        return
    end
    net.Start("DAdmin_UIState")
    net.WriteUInt(len, 32)
    net.WriteData(compressed, len)
    net.Send(ply)
end

local function runUICommand(ply, payload)
    local cmd = tostring(payload.command or "")
    local args = istable(payload.args) and payload.args or {}
    return DAdmin.RunCommand and DAdmin.RunCommand(ply, cmd, args)
end


local actionPerms = {
    refresh = "menu",
    command = "menu",
    broadcast = "broadcast",
    report_claim = "reports",
    report_resolve = "reports",
    report_dismiss = "reports",
    report_reopen = "reports",
    report_priority = "reports",
    report_startsit = "reports",
    sit_end = "sits",
    setrank = "rank",
    history_note = "cases",
    storage_maintenance = "admin",
    save_settings = "admin",
    save_permissions = "rank",
    toggle_rank_setting = "rank",
    edit_rank = "rank",
    create_rank = "rank.create",
    delete_rank = "rank.delete",
    log_delete = "logs",
    clear_bans = "ban",
    clear_warns = "warn",
    reset_rank_assignments = "rank",
    clear_player_warns = "warn",
    warn_player = "warn",
    remove_warn = "warn",
    reset_settings = "admin",
    guard_config = "guard.admin",
    guard_dismiss = "guard",
    intel_config = "guard.admin",
    intel_reset = "guard.admin",
    case_claim = "cases",
    case_release = "cases",
    case_merge = "cases.close",
    case_split = "cases",
}

local function canAction(ply, action, payload)
    if not canUse(ply) then return false end
    if DAdmin.Security then
        local ok = DAdmin.Security.CheckNet(ply, "ui:" .. tostring(action), { burst = action == "refresh" and 4 or 8, window = 1, permission = actionPerms[action] })
        if not ok then return false end
    elseif actionPerms[action] and DAdmin.HasPermission and not DAdmin.HasPermission(ply, actionPerms[action]) then
        return false
    end

    if action == "command" and istable(payload) then
        local cmdName = tostring(payload.command or "")
        local cmd = DAdmin.GetCommand and DAdmin.GetCommand(cmdName)
        if istable(cmd) and cmd.permission and DAdmin.HasPermission and not DAdmin.HasPermission(ply, cmd.permission) then
            return false
        end
    end

    return true
end

net.Receive("DAdmin_UIAction", function(_, ply)
    local action = net.ReadString()
    local payload = net.ReadTable() or {}
    payload = DAdmin.Security and DAdmin.Security.SanitizeTable(payload) or payload
    if not canAction(ply, action, payload) then return end

    if action == "refresh" then
        DAdmin.SendUIState(ply)
        return
    elseif action == "command" then
        runUICommand(ply, payload)
    elseif action == "broadcast" then
        local msg = tostring(payload.message or "")
        if msg ~= "" then
            PrintMessage(HUD_PRINTTALK, "[DAdmin Broadcast] " .. msg)
            DAdmin.Log("broadcast", ply, "all", msg)
        end
    elseif action == "report_claim" then
        if DAdmin.Reports and DAdmin.Reports.Claim then DAdmin.Reports.Claim(ply, payload.id) end
    elseif action == "report_resolve" then
        if DAdmin.Reports and DAdmin.Reports.Resolve then DAdmin.Reports.Resolve(ply, payload.id, payload.resolution or "Resolved") end
    elseif action == "report_dismiss" then
        if DAdmin.Reports and DAdmin.Reports.Dismiss then DAdmin.Reports.Dismiss(ply, payload.id, payload.reason or "Dismissed") end
    elseif action == "report_reopen" then
        if DAdmin.Reports and DAdmin.Reports.Reopen then DAdmin.Reports.Reopen(ply, payload.id) end
    elseif action == "report_priority" then
        if DAdmin.Reports and DAdmin.Reports.SetPriority then DAdmin.Reports.SetPriority(ply, payload.id, payload.priority or "medium") end
    elseif action == "report_startsit" then
        local report = DAdmin.Reports and DAdmin.Reports.Get and DAdmin.Reports.Get(payload.id)
        local target = report and DAdmin.Players and DAdmin.Players.FindBySteamID and DAdmin.Players.FindBySteamID(report.targetSteamID)
        if IsValid(target) and DAdmin.Sits and DAdmin.Sits.Start then DAdmin.Sits.Start(ply, target, payload.id) end
    elseif action == "sit_end" then
        if DAdmin.Sits and DAdmin.Sits.End then DAdmin.Sits.End(ply, payload.id, payload.resolution or "Resolved") end
    elseif action == "setrank" then
        if payload.steamid and payload.rank and DAdmin.SetUserRank then
            DAdmin.SetUserRank(payload.steamid, string.lower(payload.rank))
            if DAdmin.InvalidatePermissionCache then DAdmin.InvalidatePermissionCache(payload.steamid) end
            DAdmin.Log("setrank", ply, payload.steamid, payload.rank)
            if DAdmin.ChatLogAction then DAdmin.ChatLogAction("setrank", ply, payload.steamid, payload.rank) end
        end
    elseif action == "history_note" then
        if DAdmin.History and DAdmin.History.AddNote and payload.steamid and payload.note then
            DAdmin.History.AddNote(ply, payload.steamid, payload.note)
            DAdmin.Log("history_note", ply, payload.steamid, payload.note)
        end
    elseif action == "storage_maintenance" then
        if DAdmin.Storage and DAdmin.Storage.Maintenance then
            DAdmin.Storage.Maintenance()
            DAdmin.Log("storage_maintenance", ply, "storage", "manual")
        end
    elseif action == "save_settings" then
        if istable(payload.settings) then
            DAdmin.Config = table.Merge(copy(DEFAULT_CONFIG), payload.settings)
            saveConfig()
            DAdmin.Log("settings", ply, "config", "saved")
            if DAdmin.ChatLogAction then DAdmin.ChatLogAction("settings", ply, "config", "saved") end
        end
    elseif action == "reset_settings" then
        DAdmin.Config = copy(DEFAULT_CONFIG)
        saveConfig()
        DAdmin.Log("settings", ply, "config", "reset to defaults")
    elseif action == "save_permissions" then
        if istable(payload.matrix) then
            for rank, perms in pairs(payload.matrix) do
                if DAdmin.Ranks[rank] and istable(perms) then
                    DAdmin.Ranks[rank].permissions = perms
                end
            end
            if DAdmin.SaveRanks then DAdmin.SaveRanks() end
            if DAdmin.InvalidatePermissionCache then DAdmin.InvalidatePermissionCache() end
            DAdmin.Log("permissions", ply, "ranks", "saved")
            if DAdmin.ChatLogAction then DAdmin.ChatLogAction("permissions", ply, "ranks", "saved") end
        end
    elseif action == "toggle_rank_setting" then
        local rank = tostring(payload.rank or "")
        local key = tostring(payload.key or "")
        if DAdmin.Ranks[rank] and key ~= "" then
            DAdmin.Ranks[rank].settings = DAdmin.Ranks[rank].settings or {}
            DAdmin.Ranks[rank].settings[key] = not not payload.value
            if DAdmin.SaveRanks then DAdmin.SaveRanks() end
            if DAdmin.InvalidatePermissionCache then DAdmin.InvalidatePermissionCache() end
            DAdmin.Log("rank", ply, rank, key .. "=" .. tostring(payload.value))
        end
    elseif action == "edit_rank" then
        local rank = tostring(payload.rank or "")
        local data = payload.data or {}
        if DAdmin.Ranks[rank] and istable(data) then
            DAdmin.Ranks[rank].label = tostring(data.label or DAdmin.Ranks[rank].label or titleCase(rank))
            DAdmin.Ranks[rank].immunity = tonumber(data.immunity) or DAdmin.Ranks[rank].immunity or 0
            if isstring(data.inherits) then DAdmin.Ranks[rank].inherit = data.inherits ~= "" and data.inherits or nil end
            if DAdmin.SaveRanks then DAdmin.SaveRanks() end
            if DAdmin.InvalidatePermissionCache then DAdmin.InvalidatePermissionCache() end
            DAdmin.Log("rank", ply, rank, "edited")
        end
elseif action == "create_rank" then
    local id = string.lower(string.Trim(tostring(payload.id or "")))
    id = string.gsub(id, "[^%w_%-]", "")
    if id ~= "" and not DAdmin.Ranks[id] then
        local inherit = tostring(payload.inherit or "user")
        if inherit == "" or not DAdmin.Ranks[inherit] then inherit = "user" end
        DAdmin.RegisterRank(id, {
            label = tostring(payload.label or id),
            immunity = tonumber(payload.immunity or 0) or 0,
            inherit = inherit,
            permissions = {}
        })
        if DAdmin.SaveRanks then DAdmin.SaveRanks() end
        DAdmin.Log("rank", ply, id, "created")
    end
elseif action == "delete_rank" then
    local id = string.lower(tostring(payload.id or ""))
    if id ~= "" and id ~= "owner" and id ~= "superadmin" and id ~= "admin" and id ~= "user" and DAdmin.Ranks[id] then
        DAdmin.Ranks[id] = nil
        for steamid, rank in pairs(DAdmin.Users or {}) do
            if rank == id then DAdmin.Users[steamid] = DAdmin.Config.default_rank or "user" end
        end
        if DAdmin.SaveRanks then DAdmin.SaveRanks() end
        if DAdmin.SaveUsers then DAdmin.SaveUsers() end
        if DAdmin.InvalidatePermissionCache then DAdmin.InvalidatePermissionCache() end
        DAdmin.Log("rank", ply, id, "deleted")
    end
    elseif action == "log_delete" then
        local id = tostring(payload.id or "")
        DAdmin.LoadLogs()
        for i, log in ipairs(DAdmin.Logs or {}) do
            if tostring(log.id) == id then table.remove(DAdmin.Logs, i) break end
        end
        DAdmin.SaveLogs()
    elseif action == "clear_bans" then
        DAdmin.Bans = {}
        if DAdmin.Storage and DAdmin.Storage.Save then DAdmin.Storage.Save("bans.json", DAdmin.Bans) end
    elseif action == "clear_warns" then
        if DAdmin.Warns then
            DAdmin.Warns.Data = {}
            if DAdmin.Warns.Save then DAdmin.Warns.Save() end
        end
    elseif action == "reset_rank_assignments" then
        DAdmin.Users = {}
        if DAdmin.Users and DAdmin.Users.Save then DAdmin.Users.Save() end
    elseif action == "clear_player_warns" then
        if payload.steamid and DAdmin.Warns then
            if DAdmin.Warns.ClearForPlayer then
                DAdmin.Warns.ClearForPlayer(payload.steamid)
            elseif DAdmin.Warns.Data then
                DAdmin.Warns.Data[payload.steamid] = nil
                if DAdmin.Warns.Save then DAdmin.Warns.Save() end
            end
            DAdmin.Log("clear_warns", ply, payload.steamid, "player warns cleared")
            DAdmin.Msg(ply, "Cleared all warnings for " .. tostring(payload.steamid))
            local target = player.GetBySteamID(payload.steamid)
            if IsValid(target) then
                DAdmin.Msg(target, "Your warnings have been cleared by " .. ply:Nick())
            end
        end
    elseif action == "warn_player" then
        if payload.steamid and payload.reason then
            local target = player.GetBySteamID(payload.steamid)
            if DAdmin.Warns and DAdmin.Warns.Add then
                if IsValid(target) then
                    DAdmin.Warns.Add(ply, target, payload.reason)
                    DAdmin.Msg(ply, "Warned " .. target:Nick() .. ": " .. tostring(payload.reason))
                    DAdmin.Msg(target, "You have been warned by " .. ply:Nick() .. ": " .. tostring(payload.reason))
                else
                    -- Player offline, store warn by steamid directly
                    DAdmin.Warns.Data = DAdmin.Warns.Data or {}
                    DAdmin.Warns.Data[payload.steamid] = DAdmin.Warns.Data[payload.steamid] or {}
                    table.insert(DAdmin.Warns.Data[payload.steamid], {
                        id = tostring(os.time()) .. "_" .. math.random(1000, 9999),
                        admin = ply:Nick(),
                        adminSteamID = ply:SteamID(),
                        reason = payload.reason,
                        time = os.date("%Y-%m-%d %H:%M:%S"),
                        timestamp = os.time(),
                    })
                    if DAdmin.Warns.Save then DAdmin.Warns.Save() end
                    DAdmin.Msg(ply, "Warned (offline) " .. tostring(payload.steamid) .. ": " .. tostring(payload.reason))
                end
                DAdmin.Log("warn", ply, IsValid(target) and target:Nick() or payload.steamid, payload.reason)
            end
        end
    elseif action == "remove_warn" then
        if payload.steamid and payload.warnID then
            if DAdmin.Warns and DAdmin.Warns.Remove then
                DAdmin.Warns.Remove(ply, payload.steamid, payload.warnID)
            elseif DAdmin.Warns and DAdmin.Warns.Data and DAdmin.Warns.Data[payload.steamid] then
                for i, w in ipairs(DAdmin.Warns.Data[payload.steamid]) do
                    if w.id == payload.warnID then
                        table.remove(DAdmin.Warns.Data[payload.steamid], i)
                        break
                    end
                end
                if DAdmin.Warns.Save then DAdmin.Warns.Save() end
            end
            DAdmin.Msg(ply, "Removed warning " .. tostring(payload.warnID), 0)
            DAdmin.Log("remove_warn", ply, payload.steamid, "removed warn " .. tostring(payload.warnID))
        end
    elseif action == "intel_config" then
        if DAdmin.Intel and DAdmin.Intel.SetConfig then
            DAdmin.Intel.SetConfig(payload.config or {})
            DAdmin.Log("intel_config", ply, "intelligence", "updated")
        end
    elseif action == "intel_reset" then
        if DAdmin.Intel and DAdmin.Intel.ResetProfile and payload.steamid then
            DAdmin.Intel.ResetProfile(ply, payload.steamid)
        end
    elseif action == "case_claim" then
        if DAdmin.StaffControl and DAdmin.StaffControl.ClaimCase then
            DAdmin.StaffControl.ClaimCase(ply, payload.caseID, payload.force)
        end
    elseif action == "case_release" then
        if DAdmin.StaffControl and DAdmin.StaffControl.ReleaseCase then
            DAdmin.StaffControl.ReleaseCase(ply, payload.caseID)
        end
    elseif action == "case_merge" then
        if DAdmin.Cases and DAdmin.Cases.Merge then
            DAdmin.Cases.Merge(ply, payload.fromCaseID, payload.intoCaseID)
        end
    elseif action == "case_split" then
        if DAdmin.Cases and DAdmin.Cases.Split then
            DAdmin.Cases.Split(ply, payload.caseID, payload.reason or "Split case")
        end
    elseif action == "guard_config" then
        if DAdmin.Guard and DAdmin.Guard.SetConfig and istable(payload.config) then
            DAdmin.Guard.SetConfig(payload.config)
            DAdmin.Log("guard", ply, "config", "updated")
        end
    elseif action == "guard_dismiss" then
        if DAdmin.Guard and DAdmin.Guard.DismissAlert then
            DAdmin.Guard.DismissAlert(payload.alertID)
            DAdmin.Log("guard", ply, "alert", "dismissed: " .. tostring(payload.alertID))
        end
    elseif action == "evidence_add" then
        if payload.caseID and DAdmin.Cases and DAdmin.Cases.AddLink then
            DAdmin.Cases.AddLink(payload.caseID, "evidence", tostring(os.time()), ply, payload.content or "")
            DAdmin.Log("evidence", ply, payload.caseID, "added")
        end
    elseif action == "evidence_remove" then
        if payload.caseID and payload.evidenceID and DAdmin.Cases then
            DAdmin.Log("evidence", ply, payload.caseID, "removed: " .. tostring(payload.evidenceID))
        end
    elseif action == "command" then
        if payload.command and DAdmin.RunCommand then
            DAdmin.RunCommand(ply, payload.command, payload.args or {})
        end
    end

    timer.Simple(0.05, function()
        if IsValid(ply) then DAdmin.SendUIState(ply) end
    end)
end)
