-- DAdmin Server Service
DAdmin = DAdmin or {}
DAdmin.Server = DAdmin.Server or {}

function DAdmin.Server.ChangeMap(map)
    RunConsoleCommand("changelevel", map)
    DAdmin.Log("changemap", map)
end

function DAdmin.Server.SetCvar(name, value)
    RunConsoleCommand(name, value)
    DAdmin.Log("setcvar", name, value)
end

function DAdmin.Server.RunCommand(cmd)
    RunConsoleCommand(cmd)
    DAdmin.Log("runcommand", cmd)
end
