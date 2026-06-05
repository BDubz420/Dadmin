-- DAdmin Warning System
-- Phase 4: persistent warnings with history and optional auto-action hooks.
if CLIENT then return end

DAdmin = DAdmin or {}
DAdmin.Warns = DAdmin.Warns or {}

local WARN_FILE = "warns.json"

function DAdmin.Warns.Load()
    DAdmin.Warns.Data = (DAdmin.Storage and DAdmin.Storage.Load and DAdmin.Storage.Load(WARN_FILE, {})) or {}
    return DAdmin.Warns.Data
end

function DAdmin.Warns.Save()
    if DAdmin.Storage and DAdmin.Storage.Save then
        DAdmin.Storage.Save(WARN_FILE, DAdmin.Warns.Data or {})
    end
end

function DAdmin.Warns.GetForSteamID(steamid)
    DAdmin.Warns.Data = DAdmin.Warns.Data or {}
    return DAdmin.Warns.Data[tostring(steamid or "")] or {}
end

function DAdmin.Warns.Add(admin, target, reason)
    if not IsValid(target) then return false, "invalid target" end
    if DAdmin.HasPermission and not DAdmin.HasPermission(admin, "warn") then return false, "permission denied" end

    local steamid = target:SteamID()
    DAdmin.Warns.Data = DAdmin.Warns.Data or {}
    DAdmin.Warns.Data[steamid] = DAdmin.Warns.Data[steamid] or {}

    local entry = {
        id = "warn_" .. tostring(os.time()) .. "_" .. tostring(math.random(1000,9999)),
        timestamp = os.time(),
        admin = IsValid(admin) and admin:Nick() or "Console",
        adminSteamID = IsValid(admin) and admin:SteamID() or "CONSOLE",
        target = target:Nick(),
        targetSteamID = steamid,
        reason = tostring(reason or "No reason")
    }

    table.insert(DAdmin.Warns.Data[steamid], 1, entry)
    DAdmin.Warns.Save()

    if DAdmin.History and DAdmin.History.Add then
        DAdmin.History.Add(steamid, "warnings", entry)
    end

    if DAdmin.Cases then
        local case = DAdmin.Cases.FindOpenForPlayer and DAdmin.Cases.FindOpenForPlayer(steamid)
        if not case and DAdmin.Cases.Create then
            case = DAdmin.Cases.Create(steamid, nil, entry.adminSteamID, "Warning: " .. entry.reason)
        end
        if case and DAdmin.Cases.AttachWarning then
            entry.caseID = case.id
            DAdmin.Cases.AttachWarning(case.id, table.Copy(entry), admin)
            DAdmin.Warns.Save()
        end
    end

    if DAdmin.Log then DAdmin.Log("warn", admin, target, entry.reason) end
    DAdmin.Msg(target, "You were warned: " .. entry.reason)

    return true, entry
end

function DAdmin.Warns.Remove(admin, steamid, warnID)
    steamid = tostring(steamid or "")
    warnID = tostring(warnID or "")
    local list = DAdmin.Warns.GetForSteamID(steamid)

    for i, warn in ipairs(list) do
        if tostring(warn.id) == warnID or tostring(i) == warnID then
            table.remove(list, i)
            DAdmin.Warns.Save()
            if DAdmin.Log then DAdmin.Log("unwarn", admin, steamid, warnID) end
            return true
        end
    end

    return false
end

function DAdmin.Warns.ClearForPlayer(steamid)
    steamid = tostring(steamid or "")
    DAdmin.Warns.Data = DAdmin.Warns.Data or {}
    DAdmin.Warns.Data[steamid] = nil
    DAdmin.Warns.Save()
end

function DAdmin.Warns.CountToday()
    local start = os.time({year = tonumber(os.date("%Y")), month = tonumber(os.date("%m")), day = tonumber(os.date("%d")), hour = 0})
    local count = 0
    for _, entries in pairs(DAdmin.Warns.Data or {}) do
        for _, warn in ipairs(entries) do
            if (warn.timestamp or 0) >= start then count = count + 1 end
        end
    end
    return count
end

DAdmin.Warns.Load()

DAdmin.RegisterCommand("warn", {
    permission = "warn",
    description = "Warn a player",
    category = "Moderation",
    args = {
        { name = "target", type = "player" },
        { name = "reason", type = "string", optional = true }
    },
    run = function(admin, targets, reason)
        for _, ply in ipairs(targets or {}) do
            local ok, err = DAdmin.Warns.Add(admin, ply, reason or "No reason")
            DAdmin.Msg(admin, ok and ("Warned " .. ply:Nick()) or ("Could not warn: " .. tostring(err)))
        end
    end
})

DAdmin.RegisterCommand("warnings", {
    permission = "warn",
    description = "Show warning count for a player",
    category = "Moderation",
    args = {
        { name = "target", type = "player" }
    },
    run = function(admin, targets)
        for _, ply in ipairs(targets or {}) do
            local warns = DAdmin.Warns.GetForSteamID(ply:SteamID())
            DAdmin.Msg(admin, ply:Nick() .. " has " .. tostring(#warns) .. " warning(s).")
        end
    end
})
