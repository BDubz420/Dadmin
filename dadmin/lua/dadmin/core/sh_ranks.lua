-- DAdmin Rank Registry
DAdmin = DAdmin or {}
DAdmin.Ranks = DAdmin.Ranks or {}
DAdmin.Users = DAdmin.Users or {}

local DEFAULT_RANKS = {
    user = {
        label = "User",
        immunity = 0,
        inherit = nil,
        permissions = {}
    },
    moderator = {
        label = "Moderator",
        immunity = 100,
        inherit = "user",
        permissions = {"menu", "admin", "kick", "mute", "gag", "freeze", "goto", "bring", "return", "jail", "unjail", "spectate", "reports", "sits", "warn", "report"}
    },
    admin = {
        label = "Admin",
        immunity = 500,
        inherit = "moderator",
        permissions = {"ban", "unban", "noclip", "god", "strip", "respawn", "screengrab", "physgun_freeze", "logs", "cases", "servertools", "broadcast", "reports.override", "guard"}
    },
    superadmin = {
        label = "Super Admin",
        immunity = 800,
        inherit = "admin",
        permissions = {"rank", "rankedit", "permissions", "cleanup", "maprestart", "override_immunity", "guard.admin", "cases.close"}
    },
    owner = {
        label = "Owner",
        immunity = 1000,
        inherit = "superadmin",
        permissions = {"*"}
    }
}

local function normalisePermissions(perms)
    local out = {}
    if istable(perms) then
        for key, value in pairs(perms) do
            if isnumber(key) then
                out[#out + 1] = string.lower(tostring(value))
            elseif value then
                out[#out + 1] = string.lower(tostring(key))
            end
        end
    end
    table.sort(out)
    return out
end

function DAdmin.NormalizeRank(name, def)
    def = istable(def) and table.Copy(def) or {}
    name = string.lower(tostring(name or def.name or "user"))
    def.name = name
    def.label = def.label or def.title or name
    def.immunity = tonumber(def.immunity or def.priority or 0) or 0
    def.priority = def.immunity
    def.inherit = def.inherit or def.inherits
    def.permissions = normalisePermissions(def.permissions)
    def.members = istable(def.members) and def.members or {}
    return def
end

function DAdmin.EnsureDefaultRanks()
    for name, def in pairs(DEFAULT_RANKS) do
        if not istable(DAdmin.Ranks[name]) then
            DAdmin.Ranks[name] = DAdmin.NormalizeRank(name, def)
        else
            DAdmin.Ranks[name] = DAdmin.NormalizeRank(name, DAdmin.Ranks[name])
            if not DAdmin.Ranks[name].label then DAdmin.Ranks[name].label = def.label end
        end
    end
end

function DAdmin.RegisterRank(name, def)
    if not isstring(name) or name == "" then return false end
    DAdmin.Ranks[string.lower(name)] = DAdmin.NormalizeRank(name, def)
    if DAdmin.SaveRanks then DAdmin.SaveRanks() end
    if DAdmin.InvalidatePermissionCache then DAdmin.InvalidatePermissionCache() end
    return true
end

function DAdmin.GetRank(name)
    if istable(name) then name = DAdmin.GetUserRank(name) end
    name = string.lower(tostring(name or "user"))
    return DAdmin.Ranks[name] or DAdmin.Ranks.user
end

function DAdmin.GetAllRanks()
    return DAdmin.Ranks or {}
end

local function resolveExternalRank(ply)
    if not (IsValid and IsValid(ply)) then return nil end

    if ply.DAdminRank and DAdmin.Ranks[string.lower(tostring(ply.DAdminRank))] then
        return string.lower(tostring(ply.DAdminRank))
    end

    local group = ply.GetUserGroup and string.lower(tostring(ply:GetUserGroup() or "")) or ""
    if group ~= "" then
        if DAdmin.Ranks[group] then return group end
        if (group == "superadmin" or group == "founder" or group == "owner") and DAdmin.Ranks.superadmin then
            return "superadmin"
        end
        if (group == "admin" or group == "administrator" or group == "senioradmin" or group == "headadmin") and DAdmin.Ranks.admin then
            return "admin"
        end
        if (group == "moderator" or group == "mod" or group == "trialmod" or group == "operator") and DAdmin.Ranks.moderator then
            return "moderator"
        end
    end

    if ply:IsSuperAdmin() and DAdmin.Ranks.superadmin then return "superadmin" end
    if ply:IsAdmin() and DAdmin.Ranks.admin then return "admin" end

    return nil
end

function DAdmin.GetUserRank(plyOrSteamID)
    local steamid = DAdmin.GetPlayerSteamID and DAdmin.GetPlayerSteamID(plyOrSteamID)
    local assignedRank = nil
    if steamid and DAdmin.Users and DAdmin.Users[steamid] then
        assignedRank = string.lower(tostring(DAdmin.Users[steamid]))
        if assignedRank ~= "" and assignedRank ~= "user" and assignedRank ~= string.lower(tostring(DAdmin.Config and DAdmin.Config.default_rank or "user")) then
            return assignedRank
        end
    end

    local externalRank = resolveExternalRank(plyOrSteamID)
    if externalRank then
        return externalRank
    end

    if assignedRank then
        return assignedRank
    end

    return "user"
end

function DAdmin.GetPlayerRank(ply)
    return DAdmin.GetRank(DAdmin.GetUserRank(ply))
end

function DAdmin.SetUserRank(plyOrSteamID, rankName)
    local steamid = DAdmin.GetPlayerSteamID and DAdmin.GetPlayerSteamID(plyOrSteamID)
    rankName = string.lower(tostring(rankName or "user"))
    if not steamid or not DAdmin.Ranks[rankName] then return false end

    DAdmin.Users[steamid] = rankName
    local rankPlayer = IsEntity and IsEntity(plyOrSteamID) and plyOrSteamID or (player and player.GetBySteamID and player.GetBySteamID(steamid))
    if IsValid and IsValid(rankPlayer) then
        rankPlayer.DAdminRank = rankName
        if rankPlayer.SetUserGroup then pcall(function() rankPlayer:SetUserGroup(rankName) end) end
        if FAdmin and FAdmin.Access and FAdmin.Access.SetUserGroup then pcall(function() FAdmin.Access.SetUserGroup(rankPlayer, rankName) end) end
    end
    if DAdmin.SaveUsers then DAdmin.SaveUsers() end
    if DAdmin.InvalidatePermissionCache then DAdmin.InvalidatePermissionCache(steamid) end
    return true
end

function DAdmin.CanTarget(actor, target)
    if DAdmin.IsConsole and DAdmin.IsConsole(actor) then return true end
    local a = DAdmin.GetPlayerRank(actor)
    local t = DAdmin.GetPlayerRank(target)
    return (a and a.immunity or 0) > (t and t.immunity or 0)
end

DAdmin.EnsureDefaultRanks()

if SERVER then
    hook.Add("PlayerInitialSpawn", "DAdmin_LoadPlayerRank", function(ply)
        local rank = DAdmin.GetUserRank(ply)
        ply.DAdminRank = rank
        if DAdmin.InvalidatePermissionCache then
            DAdmin.InvalidatePermissionCache(ply)
        end
    end)

    hook.Add("PlayerInitialSpawn", "DAdmin_OwnerBootstrap", function(ply)
        timer.Simple(1, function()
            if not IsValid(ply) then return end
            if DAdmin.OwnerBootstrapped then return end

            local hasOwner = false
            for steamid, rank in pairs(DAdmin.Users or {}) do
                if rank == "owner" then hasOwner = true break end
            end

            if not hasOwner then
                DAdmin.SetUserRank(ply, "owner")
                DAdmin.OwnerBootstrapped = true
                print("[DAdmin] First known player assigned owner rank: " .. ply:Nick())
            end
        end)
    end)
end

DADMIN = DAdmin
DADMIN.Ranks = DAdmin.Ranks
