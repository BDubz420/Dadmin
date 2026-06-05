-- DAdmin Jail System Commands
DAdmin = DAdmin or {}

local function feedback(admin, msg, symbol)
    symbol = symbol or ""
    if IsValid(admin) then DAdmin.Msg(admin, symbol .. " " .. msg) else print("[DAdmin] " .. symbol .. " " .. msg) end
end

DAdmin.JailPositions = DAdmin.JailPositions or {}
DAdmin.JailBoxes = DAdmin.JailBoxes or {}

DAdmin.RegisterCommand("jail", {
    permission = "jail",
    description = "Jail a player",
    category = "Moderation",
    args = {
        { name = "target", type = "player" }
    },
    run = function(admin, targets)
        for _, ply in ipairs(targets) do
            ply:StripWeapons()
            ply:Freeze(true)
            local pos = admin:GetPos() + Vector(100,0,0)
            ply:SetPos(pos)
            -- Spawn jail box (placeholder)
            feedback(admin, "✓ " .. ply:Nick() .. " jailed", "✓")
            DAdmin.Log("jail", admin, ply)
        end
    end
})

DAdmin.RegisterCommand("unjail", {
    permission = "jail",
    description = "Unjail a player",
    category = "Moderation",
    args = {
        { name = "target", type = "player" }
    },
    run = function(admin, targets)
        for _, ply in ipairs(targets) do
            ply:Freeze(false)
            -- Remove jail box (placeholder)
            feedback(admin, "✓ " .. ply:Nick() .. " unjailed", "✓")
            DAdmin.Log("unjail", admin, ply)
        end
    end
})
