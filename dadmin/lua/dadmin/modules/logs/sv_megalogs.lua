if CLIENT then return end
DAdmin = DAdmin or {}
DAdmin.MegaLogs = DAdmin.MegaLogs or {}
DAdmin.MegaLogs.Categories = {
    commands="Commands", punishments="Punishments", chat="Chat", connections="Connections",
    damage="Damage", deaths="Deaths", props="Props", tools="Tools", darkrp="DarkRP",
    reports="Reports", cases="Cases", ranks="Ranks", permissions="Permissions", settings="Settings",
    safezones="Safezones", playtime="Playtime", guard="Guard", system="System"
}
DAdmin.MegaLogs.File = "large_logs.json"

util.AddNetworkString("DAdmin_MegaLogs_Request")
util.AddNetworkString("DAdmin_MegaLogs_Send")
util.AddNetworkString("DAdmin_MegaLogs_Clear")

local function cfg()
    return DAdmin.GetFeatureConfig and DAdmin.GetFeatureConfig() or {}
end

local saveQueued = false
local function save()
    if saveQueued then return end
    saveQueued = true
    timer.Simple(1, function()
        saveQueued = false
        if DAdmin.Storage and DAdmin.Storage.Save then DAdmin.Storage.Save(DAdmin.MegaLogs.File, DAdmin.MegaLogs.Data or {}) end
    end)
end

DAdmin.MegaLogs.Data = DAdmin.Storage and DAdmin.Storage.Load and DAdmin.Storage.Load(DAdmin.MegaLogs.File, {}) or {}

local function actorName(v)
    if IsEntity(v) and IsValid(v) then
        local okIsPlayer, isPlayerEntity = pcall(function()
            return v.IsPlayer and v:IsPlayer()
        end)
        if okIsPlayer and isPlayerEntity then
            local okNick, nick = pcall(function() return v:Nick() end)
            local okSteamID, steamid = pcall(function() return v:SteamID() end)
            local okSteamID64, steamid64 = pcall(function() return v:SteamID64() end)
            return okNick and tostring(nick or "Player") or "Player",
                okSteamID and tostring(steamid or "PLAYER") or "PLAYER",
                okSteamID64 and tostring(steamid64 or "PLAYER") or "PLAYER"
        end
        local okClass, class = pcall(function()
            return v.GetClass and v:GetClass() or tostring(v)
        end)
        local okEntIndex, entIndex = pcall(function()
            return v.EntIndex and v:EntIndex() or -1
        end)
        class = okClass and tostring(class or "entity") or "entity"
        entIndex = okEntIndex and tonumber(entIndex or -1) or -1
        local label = class .. " [#" .. tostring(entIndex) .. "]"
        return label, label, label
    end
    if isstring(v) then return v, v, v end
    return tostring(v or "System"), "CONSOLE", "CONSOLE"
end

function DAdmin.MegaLogs.Add(category, action, actor, target, details, data)
    if cfg().logs_enabled == false then return end
    category = tostring(category or "system")
    if not DAdmin.MegaLogs.Categories[category] then category = "system" end
    local an, asid, asid64 = actorName(actor)
    local tn, tsid, tsid64 = actorName(target)
    local entry = {
        id = tostring(os.time()) .. "-" .. tostring(math.random(100000,999999)),
        category = category,
        action = tostring(action or "event"),
        actor = an, actor_steamid = asid, actor_steamid64 = asid64,
        target = tn, target_steamid = tsid, target_steamid64 = tsid64,
        details = tostring(details or ""),
        data = data or {},
        timestamp = os.time(),
        time = os.date("%Y-%m-%d %H:%M:%S")
    }
    DAdmin.MegaLogs.Data[category] = DAdmin.MegaLogs.Data[category] or {}
    table.insert(DAdmin.MegaLogs.Data[category], 1, entry)
    local max = tonumber(cfg().logs_max_entries or 25000) or 25000
    while #DAdmin.MegaLogs.Data[category] > max do table.remove(DAdmin.MegaLogs.Data[category]) end
    save()
    if DAdmin.Log and category ~= "system" then
        -- keep legacy log panel populated too, without double-recursing on old admin category
        pcall(function() DAdmin.Log(action or category, actor or "System", target or "System", details or "") end)
    end
    return entry
end

local function can(ply, perm)
    return DAdmin.HasPermission and DAdmin.HasPermission(ply, perm or "logs.view")
end

net.Receive("DAdmin_MegaLogs_Request", function(_, ply)
    if not can(ply, "logs.view") then return end
    local cat = net.ReadString()
    local search = string.lower(net.ReadString() or "")
    local limit = math.Clamp(net.ReadUInt(16) or 250, 1, 1000)
    local src = (cat == "all" or cat == "") and DAdmin.MegaLogs.Data or {[cat] = DAdmin.MegaLogs.Data[cat] or {}}
    local out = { categories = DAdmin.MegaLogs.Categories, entries = {} }
    for c, list in pairs(src) do
        for _, e in ipairs(list or {}) do
            if #out.entries >= limit then break end
            local hay = string.lower(table.concat({e.category or "", e.action or "", e.actor or "", e.target or "", e.details or ""}, " "))
            if search == "" or string.find(hay, search, 1, true) then out.entries[#out.entries+1] = e end
        end
    end
    table.sort(out.entries, function(a,b) return (a.timestamp or 0) > (b.timestamp or 0) end)
    net.Start("DAdmin_MegaLogs_Send") net.WriteTable(out) net.Send(ply)
end)

net.Receive("DAdmin_MegaLogs_Clear", function(_, ply)
    if not can(ply, "logs.clear") then return end
    local cat = net.ReadString()
    if cat == "all" then DAdmin.MegaLogs.Data = {} else DAdmin.MegaLogs.Data[cat] = {} end
    DAdmin.MegaLogs.Add("logs", "clear", ply, "Logs", cat)
    save()
end)

hook.Add("PlayerSay", "DAdminMegaLogsChat", function(ply, text, teamChat)
    DAdmin.MegaLogs.Add("chat", teamChat and "team_chat" or "chat", ply, ply, text)
end)
hook.Add("PlayerInitialSpawn", "DAdminMegaLogsConnect", function(ply)
    DAdmin.MegaLogs.Add("connections", "join", ply, ply, "Player joined")
end)
hook.Add("PlayerDisconnected", "DAdminMegaLogsDisconnect", function(ply)
    DAdmin.MegaLogs.Add("connections", "leave", ply, ply, "Player disconnected")
end)
hook.Add("EntityTakeDamage", "DAdminMegaLogsDamage", function(ent, dmg)
    local att = dmg:GetAttacker()
    if IsValid(ent) and ent:IsPlayer() then DAdmin.MegaLogs.Add("damage", "damage", att, ent, tostring(math.floor(dmg:GetDamage())) .. " damage") end
end)
hook.Add("PlayerDeath", "DAdminMegaLogsDeath", function(victim, inf, attacker)
    DAdmin.MegaLogs.Add("deaths", "death", attacker, victim, "Player died")
end)
hook.Add("PlayerSpawnedProp", "DAdminMegaLogsProp", function(ply, model, ent)
    DAdmin.MegaLogs.Add("props", "spawn_prop", ply, ent, tostring(model or "prop"))
end)
hook.Add("CanTool", "DAdminMegaLogsTool", function(ply, tr, tool)
    DAdmin.MegaLogs.Add("tools", "tool", ply, IsValid(tr.Entity) and tr.Entity or "World", tostring(tool or "unknown"))
end)
