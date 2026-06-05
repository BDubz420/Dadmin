-- DAdmin Player Service
DAdmin = DAdmin or {}
DAdmin.Players = DAdmin.Players or {}

function DAdmin.Players.FindBySteamID(steamid)
    for _, ply in ipairs(player.GetAll()) do
        if ply:SteamID() == steamid then return ply end
    end
    return nil
end

function DAdmin.Players.FindByName(name)
    local found = {}
    for _, ply in ipairs(player.GetAll()) do
        if string.find(string.lower(ply:Nick()), string.lower(name), 1, true) then
            table.insert(found, ply)
        end
    end
    return found
end

function DAdmin.Players.GetAll()
    return player.GetAll()
end

function DAdmin.Players.ResolveTarget(admin, target)
    if not target then return {} end
    if IsValid(target) and target:IsPlayer() then return {target} end
    if isnumber(target) then
        local byId = Player(target)
        return IsValid(byId) and { byId } or {}
    end
    if type(target) == "string" then
        target = string.Trim(target)
        local lowered = string.lower(target)
        if lowered == "@me" or lowered == "^" then return IsValid(admin) and {admin} or {} end
        if lowered == "@all" or lowered == "*" then return player.GetAll() end
        if lowered == "@admins" then
            local admins = {}
            for _, ply in ipairs(player.GetAll()) do
                if DAdmin.HasPermission(ply, "admin") then table.insert(admins, ply) end
            end
            return admins
        end
        local bySteam = DAdmin.Players.FindBySteamID(target)
        if bySteam then return {bySteam} end
        local uid = tonumber(target)
        if uid then
            for _, ply in ipairs(player.GetAll()) do
                if ply:UserID() == uid or ply:EntIndex() == uid then return {ply} end
            end
        end
        return DAdmin.Players.FindByName(target)
    end
    return {}
end
