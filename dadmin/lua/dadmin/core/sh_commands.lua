-- DAdmin Command Registry
DAdmin = DAdmin or {}
DAdmin.Commands = DAdmin.Commands or {}
DAdmin.CommandAliases = DAdmin.CommandAliases or {}

local function normaliseArgs(args)
    if not istable(args) then return {} end
    local out = {}
    for i, arg in ipairs(args) do
        if isstring(arg) then
            out[i] = { name = arg, type = arg == "target" and "player" or arg }
        elseif istable(arg) then
            out[i] = arg
        end
    end
    return out
end

function DAdmin.RegisterCommand(name, data)
    if not isstring(name) or name == "" then return false, "invalid command name" end
    if not istable(data) then return false, "invalid command data" end

    name = string.lower(string.Trim(name))
    local run = data.run or data.execute
    if not isfunction(run) then return false, "command missing run/execute" end

    local existing = DAdmin.Commands[name]
    local command = table.Copy(data)
    command.name = name
    command.run = run
    command.execute = run
    command.args = normaliseArgs(command.args or command.arguments)
    command.arguments = command.args
    command.permission = command.permission or name
    command.category = command.category or "General"
    command.description = command.description or "No description."

    DAdmin.Commands[name] = command

    if existing then
        print("[DAdmin] Replaced command: " .. name)
    else
        print("[DAdmin] Registered command: " .. name)
    end

    if istable(command.aliases) then
        for _, alias in ipairs(command.aliases) do
            if isstring(alias) and alias ~= "" then
                DAdmin.CommandAliases[string.lower(alias)] = name
            end
        end
    end

    if DAdmin.RegisterPermission and command.permission then
        DAdmin.RegisterPermission(command.permission)
    end

    return true
end

function DAdmin.GetCommand(name)
    if not name then return nil end
    name = string.lower(tostring(name))
    name = DAdmin.CommandAliases[name] or name
    return DAdmin.Commands[name]
end

function DAdmin.GetCommands()
    local out = {}
    for name, cmd in pairs(DAdmin.Commands or {}) do
        if istable(cmd) and isfunction(cmd.run or cmd.execute) then
            out[name] = cmd
        end
    end
    return out
end

function DAdmin.GetCommandList()
    local list = {}
    for _, cmd in pairs(DAdmin.Commands or {}) do
        if istable(cmd) and isfunction(cmd.run or cmd.execute) then
            list[#list + 1] = cmd
        end
    end
    table.SortByMember(list, "name", false)
    return list
end

-- Compatibility wrapper for old DADMIN.Commands:Register calls.
DADMIN = DAdmin
DADMIN.Commands = DAdmin.Commands
function DADMIN.Commands:Register(name, data)
    return DAdmin.RegisterCommand(name, data)
end

function DADMIN.Commands:Run(ply, name, ...)
    local cmd = DAdmin.GetCommand(name)
    if not cmd then return false, "Command not found" end
    if cmd.permission and DAdmin.HasPermission and not DAdmin.HasPermission(ply, cmd.permission) then
        return false, "No permission"
    end
    return cmd.run(ply, ...)
end
