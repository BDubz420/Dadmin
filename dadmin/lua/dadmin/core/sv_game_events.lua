if CLIENT then return end

DAdmin = DAdmin or {}

hook.Add("PlayerDeath", "DAdmin_LogDeath", function(victim, inflictor, attacker)
    if not DAdmin.Log then return end
    if not IsValid(victim) then return end
    local weapon = IsValid(inflictor) and inflictor:GetClass() or "world"
    if IsValid(attacker) and attacker:IsPlayer() and attacker ~= victim then
        DAdmin.Log("kill", attacker, victim, "Killed with " .. weapon)
    elseif attacker == victim then
        DAdmin.Log("suicide", victim, victim, "Suicide")
    else
        DAdmin.Log("death", "World", victim, "Killed by " .. tostring(weapon))
    end
end)

hook.Add("PlayerInitialSpawn", "DAdmin_LogConnect", function(ply)
    if not DAdmin.Log then return end
    timer.Simple(1, function()
        if IsValid(ply) then
            DAdmin.Log("connect", ply, ply, "Connected from " .. (ply:IPAddress() or "unknown"))
        end
    end)
end)

hook.Add("PlayerDisconnected", "DAdmin_LogDisconnect", function(ply)
    if not DAdmin.Log then return end
    DAdmin.Log("disconnect", ply, ply, "Disconnected")
end)

hook.Add("PlayerSpawn", "DAdmin_LogSpawn", function(ply)
    if not DAdmin.Log then return end
    if ply._dadminSpawned then return end
    ply._dadminSpawned = true
    timer.Simple(0.5, function()
        if IsValid(ply) then ply._dadminSpawned = nil end
    end)
end)

hook.Add("PlayerSay", "DAdmin_LogChat", function(ply, text, teamChat)
    if not DAdmin.Log then return end
    local settings = DAdmin.Settings or {}
    if not settings.log_chat then return end
    local action = teamChat and "say_team" or "say"
    DAdmin.Log(action, ply, nil, text)
end)

if DarkRP then
    hook.Add("playerArrested", "DAdmin_LogArrest", function(criminal, time, actor)
        if not DAdmin.Log then return end
        DAdmin.Log("arrest", actor or "System", criminal, "Arrested for " .. tostring(time or 0) .. "s")
    end)

    hook.Add("playerUnArrested", "DAdmin_LogUnarrest", function(criminal, actor)
        if not DAdmin.Log then return end
        DAdmin.Log("unarrest", actor or "System", criminal, "Unarrested")
    end)
end

hook.Add("PlayerHurt", "DAdmin_LogDamage", function(victim, attacker, healthRemaining, damageTaken)
    if not DAdmin.Log then return end
    local settings = DAdmin.Settings or {}
    if not settings.log_damage then return end
    if not IsValid(victim) or not IsValid(attacker) or not attacker:IsPlayer() then return end
    if attacker == victim then return end
    DAdmin.Log("damage", attacker, victim, tostring(damageTaken) .. " dmg (" .. tostring(healthRemaining) .. " hp left)")
end)
