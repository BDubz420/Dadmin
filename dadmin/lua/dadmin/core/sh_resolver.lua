DAdmin = DAdmin or {}

function DAdmin.ResolvePlayer(name)
    if not name or name == "" then return nil end
    name = string.lower(tostring(name))

    for _, ply in ipairs(player.GetAll()) do
        if string.lower(ply:SteamID()) == name or (ply.SteamID64 and ply:SteamID64() == name) then
            return ply
        end
    end

    for _, ply in ipairs(player.GetAll()) do
        if string.lower(ply:Nick()) == name then return ply end
    end

    local bestMatch, bestLen = nil, math.huge
    for _, ply in ipairs(player.GetAll()) do
        local nick = string.lower(ply:Nick())
        local idx = string.find(nick, name, 1, true)
        if idx and #nick < bestLen then
            bestMatch = ply
            bestLen = #nick
        end
    end

    return bestMatch
end

function DAdmin.ResolvePermission(ply, perm)
    return DAdmin.HasPermission and DAdmin.HasPermission(ply, perm) or false
end
