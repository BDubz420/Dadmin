-- DAdmin Argument Type System
DAdmin = DAdmin or {}
DAdmin.ArgTypes = DAdmin.ArgTypes or {}

function DAdmin.RegisterArgType(name, fn)
    if not name or not isfunction(fn) then return end
    DAdmin.ArgTypes[name] = fn
end

function DAdmin.GetArgType(name)
    return DAdmin.ArgTypes[name]
end

-- Default types
DAdmin.RegisterArgType("player", function(admin, value)
    return DAdmin.Targets.Parse(admin, value)
end)

DAdmin.RegisterArgType("number", function(_, value)
    return tonumber(value)
end)

DAdmin.RegisterArgType("time", function(_, value)
    -- Simple time parser: 1h, 30m, 10s
    local t = tonumber(value)
    if t then return t end
    local total = 0
    for num, unit in string.gmatch(value, "(%d+)([hms])") do
        num = tonumber(num)
        if unit == "h" then total = total + num * 3600
        elseif unit == "m" then total = total + num * 60
        elseif unit == "s" then total = total + num
        end
    end
    return total > 0 and total or nil
end)

DAdmin.RegisterArgType("string", function(_, value)
    return tostring(value)
end)

DAdmin.RegisterArgType("boolean", function(_, value)
    return value == "true" or value == "1"
end)

DAdmin.RegisterArgType("steamid", function(_, value)
    return tostring(value)
end)

-- Argument parser
function DAdmin.ParseCommandArgs(admin, cmdDef, rawArgs)
    local parsed = {}
    for i, argDef in ipairs(cmdDef.args or {}) do
        local argType = DAdmin.GetArgType(argDef.type)
        if argType then
            parsed[i] = argType(admin, rawArgs[i])
        else
            parsed[i] = rawArgs[i]
        end
    end
    return unpack(parsed)
end
