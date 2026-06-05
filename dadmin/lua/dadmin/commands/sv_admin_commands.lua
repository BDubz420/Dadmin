-- DAdmin Admin Utility Commands
DAdmin = DAdmin or {}

local function feedback(admin, msg, symbol)
    symbol = symbol or ""
    if IsValid(admin) then DAdmin.Msg(admin, symbol .. " " .. msg) else print("[DAdmin] " .. symbol .. " " .. msg) end
end

DAdmin.RegisterCommand("noclip", {
    permission = "noclip",
    description = "Toggle noclip mode",
    category = "Admin",
    args = {
        { name = "target", type = "player" }
    },
    run = function(admin, targets)
        for _, ply in ipairs(targets) do
            ply:SetMoveType(MOVETYPE_NOCLIP)
            feedback(admin, "✓ " .. ply:Nick() .. " set to noclip", "✓")
            DAdmin.Log("noclip", admin, ply)
        end
    end
})

DAdmin.RegisterCommand("god", {
    permission = "god",
    description = "Enable god mode",
    category = "Admin",
    args = {
        { name = "target", type = "player" }
    },
    run = function(admin, targets)
        for _, ply in ipairs(targets) do
            ply:GodEnable()
            feedback(admin, "✓ " .. ply:Nick() .. " is now god", "✓")
            DAdmin.Log("god", admin, ply)
        end
    end
})

DAdmin.RegisterCommand("ungod", {
    permission = "god",
    description = "Disable god mode",
    category = "Admin",
    args = {
        { name = "target", type = "player" }
    },
    run = function(admin, targets)
        for _, ply in ipairs(targets) do
            ply:GodDisable()
            feedback(admin, "✓ " .. ply:Nick() .. " is no longer god", "✓")
            DAdmin.Log("ungod", admin, ply)
        end
    end
})

DAdmin.RegisterCommand("strip", {
    permission = "strip",
    description = "Strip weapons",
    category = "Admin",
    args = {
        { name = "target", type = "player" }
    },
    run = function(admin, targets)
        for _, ply in ipairs(targets) do
            ply:StripWeapons()
            feedback(admin, "✓ " .. ply:Nick() .. " weapons stripped", "✓")
            DAdmin.Log("strip", admin, ply)
        end
    end
})

DAdmin.RegisterCommand("respawn", {
    permission = "respawn",
    description = "Respawn a player",
    category = "Admin",
    args = {
        { name = "target", type = "player" }
    },
    run = function(admin, targets)
        for _, ply in ipairs(targets) do
            ply:Spawn()
            feedback(admin, "✓ " .. ply:Nick() .. " respawned", "✓")
            DAdmin.Log("respawn", admin, ply)
        end
    end
})

util.AddNetworkString("DAdmin_SpectateStart")
util.AddNetworkString("DAdmin_SpectateStop")

DAdmin.SpectateTargets = DAdmin.SpectateTargets or {}

DAdmin.RegisterCommand("spectate", {
    permission = "spectate",
    description = "Spectate a player",
    category = "Admin",
    args = {
        { name = "target", type = "player" }
    },
    run = function(admin, targets)
        if not IsValid(admin) then return end
        local target = targets[1]
        if not IsValid(target) then feedback(admin, "Invalid target") return end
        if target == admin then feedback(admin, "Cannot spectate yourself") return end

        DAdmin.SpectateTargets[admin] = target
        admin._dadminPreSpectatePos = admin:GetPos()
        admin._dadminPreSpectateAng = admin:EyeAngles()

        admin:Spectate(OBS_MODE_IN_EYE)
        admin:SpectateEntity(target)
        admin:StripWeapons()

        net.Start("DAdmin_SpectateStart")
        net.WriteEntity(target)
        net.Send(admin)

        feedback(admin, "Now spectating " .. target:Nick())
        DAdmin.Log("spectate", admin, target)
    end
})

DAdmin.RegisterCommand("unspectate", {
    permission = "spectate",
    description = "Stop spectating",
    category = "Admin",
    args = {},
    run = function(admin)
        if not IsValid(admin) then return end
        admin:UnSpectate()
        admin:Spawn()

        if admin._dadminPreSpectatePos then
            admin:SetPos(admin._dadminPreSpectatePos)
            admin:SetEyeAngles(admin._dadminPreSpectateAng or Angle(0, 0, 0))
            admin._dadminPreSpectatePos = nil
            admin._dadminPreSpectateAng = nil
        end

        DAdmin.SpectateTargets[admin] = nil

        net.Start("DAdmin_SpectateStop")
        net.Send(admin)

        feedback(admin, "Stopped spectating")
        DAdmin.Log("unspectate", admin, nil)
    end
})
