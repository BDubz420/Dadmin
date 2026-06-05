if CLIENT then return end

local function canCarryPlayers(ply)
    return IsValid(ply)
        and DAdmin
        and DAdmin.HasPermission
        and DAdmin.HasPermission(ply, "physgun_freeze")
end

local function setHoldingState(ent, enabled)
    if not IsValid(ent) or not ent:IsPlayer() then return end
    if enabled then
        ent.DAdminPhysgunHeld = true
        ent.DAdminPhysgunHeldPos = ent:GetPos()
        if DAdmin.SetSpawnRestricted then DAdmin.SetSpawnRestricted(ent, "physgun_hold", true) end
        ent:SetMoveType(MOVETYPE_NONE)
    else
        ent.DAdminPhysgunHeld = nil
        if DAdmin.SetSpawnRestricted then DAdmin.SetSpawnRestricted(ent, "physgun_hold", false) end
        if ent:GetMoveType() == MOVETYPE_NONE then
            ent:SetMoveType(MOVETYPE_WALK)
        end
    end
end

hook.Add("PhysgunPickup", "DAdmin_PhysgunPickupPlayers", function(ply, ent)
    if not (IsValid(ent) and ent:IsPlayer()) then return end
    if not canCarryPlayers(ply) then return end
    if ent:InVehicle() then ent:ExitVehicle() end
    setHoldingState(ent, true)
    return true
end)

hook.Add("PhysgunDrop", "DAdmin_PhysgunFreezePlayers", function(ply, ent)
    if not (IsValid(ply) and IsValid(ent) and ent:IsPlayer()) then return end
    if not canCarryPlayers(ply) then return end

    setHoldingState(ent, false)
    ent:SetVelocity(-ent:GetVelocity())

    if ply:KeyDown(IN_ATTACK2) or ply:KeyDown(IN_RELOAD) then
        if DAdmin.SetSpawnRestricted then DAdmin.SetSpawnRestricted(ent, "physgun_freeze", true) end
        if DAdmin.SetPlayerFrozenState then
            DAdmin.SetPlayerFrozenState(ent, "physgun_freeze", true)
        else
            ent:SetNWBool("DAdminFrozen", true)
            ent:Freeze(true)
        end
        ent.DAdminPhysgunFrozen = true
        if DAdmin.Msg then
            DAdmin.Msg(ply, "Froze " .. ent:Nick() .. " with the physgun.")
            DAdmin.Msg(ent, "You were frozen by " .. ply:Nick() .. ".")
        end
        if DAdmin.MegaLogs then
            DAdmin.MegaLogs.Add("commands", "physgun_freeze", ply, ent, "Frozen with physgun")
        elseif DAdmin.Log then
            DAdmin.Log("physgun_freeze", ply, ent)
        end
    elseif ent.DAdminPhysgunFrozen then
        if DAdmin.SetPlayerFrozenState then
            DAdmin.SetPlayerFrozenState(ent, "physgun_freeze", false)
        else
            ent:SetNWBool("DAdminFrozen", false)
            ent:Freeze(false)
        end
        if DAdmin.SetSpawnRestricted then DAdmin.SetSpawnRestricted(ent, "physgun_freeze", false) end
        ent.DAdminPhysgunFrozen = nil
        if DAdmin.Msg then
            DAdmin.Msg(ply, "Released " .. ent:Nick() .. " from physgun freeze.")
            DAdmin.Msg(ent, "You were unfrozen by " .. ply:Nick() .. ".")
        end
    end
end)
