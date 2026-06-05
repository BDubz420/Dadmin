DAdmin.RegisterCommand("menu", {
    permission = nil,
    description = "Open the DAdmin menu",
    category = "utility",
    run = function(sender)
        if not IsValid(sender) then return end
        net.Start("dadmin_open_menu")
        net.Send(sender)
    end
})

DAdmin.RegisterCommand("dmenu", {
    permission = nil,
    description = "Open the DAdmin menu",
    category = "utility",
    run = function(sender)
        if not IsValid(sender) then return end
        net.Start("dadmin_open_menu")
        net.Send(sender)
    end
})

concommand.Add("menu", function(ply)
    if not IsValid(ply) then return end
    net.Start("dadmin_open_menu")
    net.Send(ply)
end)
