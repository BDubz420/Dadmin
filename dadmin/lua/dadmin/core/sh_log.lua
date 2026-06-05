DAdmin = DAdmin or {}
DAdmin.Logs = DAdmin.Logs or {}

local LOG_FILE = "logs.json"
local ACTION_TYPES = {
    kick = "punishment", ban = "ban", unban = "ban", mute = "punishment", unmute = "punishment",
    gag = "punishment", ungag = "punishment", slay = "punishment", warn = "punishment",
    goto = "command", bring = "command", ["return"] = "command", freeze = "command", unfreeze = "command",
    noclip = "admin", god = "admin", ungod = "admin", setrank = "admin", report = "admin",
    kill = "kill", death = "death", damage = "damage", suicide = "death",
    arrest = "command", unarrest = "command",
    connect = "connect", disconnect = "connect", spawn = "connect",
    chat = "chat", say = "chat", say_team = "chat",
    clear_warns = "admin", clear_bans = "admin", reset_settings = "admin",
    settings = "admin", permissions = "admin", broadcast = "admin",
}

local function fmtActor(v)
    if IsEntity(v) and IsValid(v) then return v:Nick(), v:SteamID() end
    if istable(v) and v.Nick then return v:Nick(), v.SteamID and v:SteamID() or "CONSOLE" end
    if isstring(v) then return v, nil end
    return tostring(v or "System"), nil
end

if SERVER then
    function DAdmin.LoadLogs()
        DAdmin.Logs = (DAdmin.Storage and DAdmin.Storage.Load and DAdmin.Storage.Load(LOG_FILE, {})) or DAdmin.Logs or {}
        return DAdmin.Logs
    end

    function DAdmin.SaveLogs()
        if DAdmin.Storage and DAdmin.Storage.Save then
            DAdmin.Storage.Save(LOG_FILE, DAdmin.Logs or {})
        end
    end

    function DAdmin.Log(action, admin, target, details)
        DAdmin.Logs = DAdmin.Logs or {}
        local adminName, adminSteam = fmtActor(admin)
        local targetName, targetSteam = fmtActor(target)
        local entry = {
            id = tostring(os.time()) .. tostring(math.random(1000, 9999)),
            timestamp = os.time(),
            time = os.date("%H:%M:%S"),
            admin = adminName,
            admin_steamid = adminSteam,
            action = tostring(action or "event"),
            target = targetName,
            target_steamid = targetSteam,
            reason = tostring(details or ""),
            details = tostring(details or ""),
            type = ACTION_TYPES[tostring(action or "")] or "admin"
        }
        table.insert(DAdmin.Logs, 1, entry)
        if #DAdmin.Logs > 1500 then table.remove(DAdmin.Logs, #DAdmin.Logs) end

        if DAdmin.History and DAdmin.History.Add then
            if entry.target_steamid then
                DAdmin.History.Add(entry.target_steamid, "logs", table.Copy(entry))
            end
            if entry.admin_steamid then
                DAdmin.History.Add(entry.admin_steamid, "logs", table.Copy(entry))
            end
        end

        if DAdmin.Cases and entry.target_steamid then
            local case = DAdmin.Cases.FindOpenForPlayer and DAdmin.Cases.FindOpenForPlayer(entry.target_steamid)
            if case and DAdmin.Cases.AddLink then
                DAdmin.Cases.AddLink(case.id, "logs", entry.id, admin or "System", entry.action .. ": " .. entry.details)
            end
        end

        DAdmin.SaveLogs()
        if DAdmin.BroadcastLogUpdate then DAdmin.BroadcastLogUpdate() end
        return entry
    end
else
    function DAdmin.LoadLogs() return DAdmin.Logs or {} end
end

function DAdmin.GetLogs()
    return DAdmin.Logs or {}
end
