-- DAdmin Movement Commands
DAdmin = DAdmin or {}
DAdmin.ReturnPositions = DAdmin.ReturnPositions or {}

local function feedback(admin, msg, symbol)
    symbol = symbol or ""
    if IsValid(admin) then DAdmin.Msg(admin, symbol .. " " .. msg) else print("[DAdmin] " .. symbol .. " " .. msg) end
end

DAdmin.RegisterCommand("goto", {
    permission = "goto",
    description = "Teleport to a player",
    category = "Movement",
    args = {
        { name = "target", type = "player" }
    },
    run = function(admin, targets)
        if not IsValid(admin) then feedback(admin, "✗ Invalid admin", "✗") return end
        for _, ply in ipairs(targets) do
            DAdmin.ReturnPositions[admin] = admin:GetPos()
            admin:SetPos(ply:GetPos())
            feedback(admin, "✓ Teleported to " .. ply:Nick(), "✓")
            DAdmin.Log("goto", admin, ply)
        end
    end
})

DAdmin.RegisterCommand("bring", {
    permission = "bring",
    description = "Teleport a player to you",
    category = "Movement",
    args = {
        { name = "target", type = "player" }
    },
    run = function(admin, targets)
        if not IsValid(admin) then feedback(admin, "✗ Invalid admin", "✗") return end
        for _, ply in ipairs(targets) do
            DAdmin.ReturnPositions[ply] = ply:GetPos()
            ply:SetPos(admin:GetPos())
            feedback(admin, "✓ Brought " .. ply:Nick(), "✓")
            DAdmin.Log("bring", admin, ply)
        end
    end
})

DAdmin.RegisterCommand("return", {
    permission = "return",
    description = "Return a player to their previous position",
    category = "Movement",
    args = {
        { name = "target", type = "player" }
    },
    run = function(admin, targets)
        for _, ply in ipairs(targets) do
            local pos = DAdmin.ReturnPositions[ply]
            if pos then
                ply:SetPos(pos)
                feedback(admin, "✓ Returned " .. ply:Nick(), "✓")
                DAdmin.Log("return", admin, ply)
            else
                feedback(admin, "⚠ No saved position for " .. ply:Nick(), "⚠")
            end
        end
    end
})
