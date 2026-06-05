-- Compatibility shim: canonical command registry lives in dadmin/core/sh_commands.lua.
DAdmin = DAdmin or {}
DADMIN = DAdmin
DADMIN.Commands = DAdmin.Commands or {}

function DADMIN.Commands:Register(name, data)
    return DAdmin.RegisterCommand and DAdmin.RegisterCommand(name, data)
end

function DADMIN.Commands:Run(ply, name, ...)
    local cmd = DAdmin.GetCommand and DAdmin.GetCommand(name)
    if not cmd then return false, "Command not found" end
    if cmd.permission and DAdmin.HasPermission and not DAdmin.HasPermission(ply, cmd.permission) then
        return false, "No permission"
    end
    return cmd.run(ply, ...)
end
