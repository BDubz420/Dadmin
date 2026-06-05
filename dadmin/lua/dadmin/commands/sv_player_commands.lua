-- DAdmin Player Moderation Commands
DAdmin = DAdmin or {}

local function feedback(admin, msg, symbol)
    symbol = symbol or ""
    if IsValid(admin) then DAdmin.Msg(admin, symbol .. " " .. msg) else print("[DAdmin] " .. symbol .. " " .. msg) end
end

DAdmin.RegisterCommand("kick", {
    permission = "kick",
    description = "Kick a player from the server",
    category = "Moderation",
    args = {
        { name = "target", type = "player" },
        { name = "reason", type = "string", optional = true }
    },
    run = function(admin, targets, reason)
        for _, ply in ipairs(targets) do
            DAdmin.Punishments.Kick(admin, ply, reason or "No reason")
            feedback(admin, "✓ Player " .. ply:Nick() .. " kicked", "✓")
            DAdmin.Log("kick", admin, ply, reason)
        end
    end
})

DAdmin.RegisterCommand("ban", {
    permission = "ban",
    description = "Ban a player from the server",
    category = "Moderation",
    args = {
        { name = "target", type = "player" },
        { name = "length", type = "time" },
        { name = "reason", type = "string", optional = true }
    },
    run = function(admin, targets, length, reason)
        for _, ply in ipairs(targets) do
            DAdmin.Punishments.Ban(admin, ply, length, reason or "No reason")
            feedback(admin, "✓ Player " .. ply:Nick() .. " banned", "✓")
            DAdmin.Log("ban", admin, ply, reason)
        end
    end
})

DAdmin.RegisterCommand("unban", {
    permission = "ban",
    description = "Unban a player",
    category = "Moderation",
    args = {
        { name = "steamid", type = "steamid" }
    },
    run = function(admin, steamid)
        DAdmin.Punishments.Unban(admin, steamid)
        feedback(admin, "✓ Player " .. steamid .. " unbanned", "✓")
        DAdmin.Log("unban", admin, steamid)
    end
})

DAdmin.RegisterCommand("mute", {
    permission = "mute",
    description = "Mute a player",
    category = "Moderation",
    args = {
        { name = "target", type = "player" },
        { name = "length", type = "time", optional = true }
    },
    run = function(admin, targets, length)
        for _, ply in ipairs(targets) do
            DAdmin.Punishments.Mute(admin, ply, length)
            feedback(admin, "✓ Player " .. ply:Nick() .. " muted", "✓")
            DAdmin.Log("mute", admin, ply, length)
        end
    end
})

DAdmin.RegisterCommand("unmute", {
    permission = "mute",
    description = "Unmute a player",
    category = "Moderation",
    args = {
        { name = "target", type = "player" }
    },
    run = function(admin, targets)
        for _, ply in ipairs(targets) do
            DAdmin.Punishments.Unmute(admin, ply)
            feedback(admin, "✓ Player " .. ply:Nick() .. " unmuted", "✓")
        end
    end
})

DAdmin.RegisterCommand("gag", {
    permission = "gag",
    description = "Gag a player",
    category = "Moderation",
    args = {
        { name = "target", type = "player" },
        { name = "length", type = "time", optional = true }
    },
    run = function(admin, targets, length)
        for _, ply in ipairs(targets) do
            DAdmin.Punishments.Gag(admin, ply, length)
            feedback(admin, "✓ Player " .. ply:Nick() .. " gagged", "✓")
            DAdmin.Log("gag", admin, ply, length)
        end
    end
})

DAdmin.RegisterCommand("ungag", {
    permission = "gag",
    description = "Ungag a player",
    category = "Moderation",
    args = {
        { name = "target", type = "player" }
    },
    run = function(admin, targets)
        for _, ply in ipairs(targets) do
            DAdmin.Punishments.Ungag(admin, ply)
            feedback(admin, "✓ Player " .. ply:Nick() .. " ungagged", "✓")
        end
    end
})

DAdmin.RegisterCommand("freeze", {
    permission = "freeze",
    description = "Freeze a player",
    category = "Moderation",
    args = {
        { name = "target", type = "player" }
    },
    run = function(admin, targets)
        for _, ply in ipairs(targets) do
            if DAdmin.SetSpawnRestricted then DAdmin.SetSpawnRestricted(ply, "command_freeze", true) end
            if DAdmin.SetPlayerFrozenState then
                DAdmin.SetPlayerFrozenState(ply, "command_freeze", true)
            else
                ply:SetNWBool("DAdminFrozen", true)
                ply:Freeze(true)
            end
            feedback(admin, "✓ Player " .. ply:Nick() .. " frozen", "✓")
            DAdmin.Log("freeze", admin, ply)
        end
    end
})

DAdmin.RegisterCommand("unfreeze", {
    permission = "freeze",
    description = "Unfreeze a player",
    category = "Moderation",
    args = {
        { name = "target", type = "player" }
    },
    run = function(admin, targets)
        for _, ply in ipairs(targets) do
            if DAdmin.SetPlayerFrozenState then
                DAdmin.SetPlayerFrozenState(ply, "command_freeze", false)
            else
                ply:SetNWBool("DAdminFrozen", false)
                ply:Freeze(false)
            end
            if DAdmin.SetSpawnRestricted then DAdmin.SetSpawnRestricted(ply, "command_freeze", false) end
            feedback(admin, "✓ Player " .. ply:Nick() .. " unfrozen", "✓")
            DAdmin.Log("unfreeze", admin, ply)
        end
    end
})

DAdmin.RegisterCommand("slay", {
    permission = "slay",
    description = "Slay a player",
    category = "Moderation",
    args = {
        { name = "target", type = "player" }
    },
    run = function(admin, targets)
        for _, ply in ipairs(targets) do
            ply:Kill()
            feedback(admin, "✓ Player " .. ply:Nick() .. " slain", "✓")
            DAdmin.Log("slay", admin, ply)
        end
    end
})

DAdmin.RegisterCommand("ignite", {
    permission = "ignite",
    description = "Ignite a player",
    category = "Moderation",
    args = {
        { name = "target", type = "player" },
        { name = "length", type = "time", optional = true }
    },
    run = function(admin, targets, length)
        for _, ply in ipairs(targets) do
            ply:Ignite(length or 10)
            feedback(admin, "✓ Player " .. ply:Nick() .. " ignited", "✓")
            DAdmin.Log("ignite", admin, ply, length)
        end
    end
})
