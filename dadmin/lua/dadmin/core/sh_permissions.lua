-- DAdmin Permission Registry / Resolver
DAdmin = DAdmin or {}
DAdmin.Permissions = DAdmin.Permissions or {}
DAdmin.PermissionCache = DAdmin.PermissionCache or {}

function DAdmin.RegisterPermission(name, meta)
    if not isstring(name) or name == "" then return false end
    DAdmin.Permissions[string.lower(name)] = istable(meta) and meta or true
    return true
end

function DAdmin.GetAllPermissions()
    local out = {}
    for perm in pairs(DAdmin.Permissions or {}) do out[#out + 1] = perm end
    table.sort(out)
    return out
end

local function permissionInList(list, perm)
    if not istable(list) then return false end
    perm = string.lower(tostring(perm or ""))

    if list["*"] == true or list["*"] == 1 then return true end
    if list[perm] == true or list[perm] == 1 then return true end

    for _, value in ipairs(list) do
        value = string.lower(tostring(value))
        if value == "*" or value == perm then return true end
    end

    return false
end

function DAdmin.RankHasPermission(rankName, perm, seen)
    if not perm then return false end
    rankName = string.lower(tostring(rankName or "user"))
    seen = seen or {}
    if seen[rankName] then return false end
    seen[rankName] = true

    local rank = DAdmin.GetRank and DAdmin.GetRank(rankName)
    if not istable(rank) then return false end

    if permissionInList(rank.permissions, perm) then return true end
    if permissionInList(rank.permissions, "admin") and perm == "menu" then return true end

    local parent = rank.inherit or rank.inherits
    if parent then
        return DAdmin.RankHasPermission(parent, perm, seen)
    end

    return false
end

function DAdmin.HasPermission(ply, perm)
    if not perm or perm == "" then return true end
    perm = string.lower(tostring(perm))

    -- Server console is trusted.
    if DAdmin.IsConsole and DAdmin.IsConsole(ply) then return true end

    local steamid = DAdmin.GetPlayerSteamID and DAdmin.GetPlayerSteamID(ply)
    if not steamid then return false end

    local cache = DAdmin.PermissionCache[steamid]
    if cache and cache[perm] ~= nil then return cache[perm] end

    local rankSubject = ply
    if not (IsValid and IsValid(rankSubject) and rankSubject:IsPlayer()) then
        rankSubject = steamid
    end

    local rankName = DAdmin.GetUserRank and DAdmin.GetUserRank(rankSubject) or "user"
    local allowed = DAdmin.RankHasPermission(rankName, perm)

    DAdmin.PermissionCache[steamid] = DAdmin.PermissionCache[steamid] or {}
    DAdmin.PermissionCache[steamid][perm] = allowed
    return allowed
end

function DAdmin.DebugPermissions(ply)
    local rankName = DAdmin.GetUserRank and DAdmin.GetUserRank(ply) or "user"
    local out = { rank = rankName, permissions = {} }
    for _, perm in ipairs(DAdmin.GetAllPermissions()) do
        out.permissions[perm] = DAdmin.HasPermission(ply, perm)
    end
    return out
end

DADMIN = DAdmin
DADMIN.Permissions = DAdmin.Permissions


local DEFAULT_PERMISSIONS = {
    "menu", "admin", "permissions", "permissions.view", "permissions.manage",
    "settings.features", "logs", "rank", "rankedit", "guard", "guard.admin",
    "reports", "reports.override", "cases", "cases.close", "servertools",
    "broadcast", "cleanup", "maprestart", "override_immunity"
}

for _, perm in ipairs(DEFAULT_PERMISSIONS) do
    DAdmin.RegisterPermission(perm)
end
