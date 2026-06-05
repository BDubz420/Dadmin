-- DAdmin Target Parser
DAdmin = DAdmin or {}
DAdmin.Targets = DAdmin.Targets or {}

function DAdmin.Targets.Parse(admin, input)
    if not input then return {} end
    if IsEntity and IsEntity(input) and IsValid(input) and input:IsPlayer() then return {input} end
    if type(input) == "string" then
        if input == "@me" then return {admin} end
        if input == "@all" then return player.GetAll() end
        if input == "@admins" then
            local admins = {}
            for _, ply in ipairs(player.GetAll()) do
                if DAdmin.HasPermission(ply, "admin") then table.insert(admins, ply) end
            end
            return admins
        end
        if DAdmin.Players and DAdmin.Players.FindBySteamID then
            local bySteam = DAdmin.Players.FindBySteamID(input)
            if bySteam then return {bySteam} end
        end
        if DAdmin.Players and DAdmin.Players.FindByName then
            return DAdmin.Players.FindByName(input)
        end
        local lowered = string.lower(input)
        local matches = {}
        for _, ply in ipairs(player.GetAll()) do
            if string.find(string.lower(ply:Nick()), lowered, 1, true) or ply:SteamID() == input or ply:SteamID64() == input then
                matches[#matches + 1] = ply
            end
        end
        return matches
    end
    return {}
end

-- Support report workflow targeting
function DAdmin.GetPlayerBySteamID(steamid)
    for _, ply in ipairs(player.GetAll()) do
        if ply:SteamID() == steamid then return ply end
    end
    return nil
end

function DAdmin.CreateSitRoom(admin, target)
    -- Create temporary sit room using props/invisible walls
    -- Prevent escape, remove when sit ends
    -- Implementation stub
end

function DAdmin.RemoveSitRoom(admin, target)
    -- Remove sit room
    -- Implementation stub
end

function DAdmin.ResolveTargets(admin, arg)
    if type(arg) == "table" then return arg end
    if not isstring(arg) then return {} end
    local targets = {}
    if arg == "@all" then
        for _, ply in ipairs(player.GetAll()) do table.insert(targets, ply) end
    elseif arg == "@admins" then
        for _, ply in ipairs(player.GetAll()) do
            if DAdmin.HasPermission(ply, "admin") then table.insert(targets, ply) end
        end
    elseif arg == "@aim" then
        local tr = admin:GetEyeTrace()
        if IsValid(tr.Entity) and tr.Entity:IsPlayer() then table.insert(targets, tr.Entity) end
    elseif arg == "@near" then
        for _, ply in ipairs(player.GetAll()) do
            if ply ~= admin and admin:GetPos():Distance(ply:GetPos()) <= 500 then table.insert(targets, ply) end
        end
    elseif arg:sub(1,6) == "@rank:" then
        local rank = arg:sub(7)
        for _, ply in ipairs(player.GetAll()) do
            if DAdmin.GetUserRank(ply) == rank then table.insert(targets, ply) end
        end
    else
        for _, ply in ipairs(player.GetAll()) do
            if ply:Nick():lower() == arg:lower() or ply:SteamID() == arg then table.insert(targets, ply) end
        end
    end
    if #targets > 0 then
        DAdmin.Log("targeting", admin:Nick() .. " targeted " .. #targets .. " players using " .. arg)
    end
    return targets
end
