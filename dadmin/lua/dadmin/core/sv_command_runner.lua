DAdmin = DAdmin or {}
DAdmin.Commands = DAdmin.Commands or {}

local function parseTime(raw)
    if raw == nil or raw == "" then return 0 end
    if isnumber(raw) then return math.max(0, raw) end
    raw = string.lower(tostring(raw))
    if raw == "0" or raw == "perm" or raw == "perma" or raw == "permanent" then return 0 end

    local total = 0
    local matched = false
    for n, unit in string.gmatch(raw, "(%d+)([smhdw])") do
        matched = true
        n = tonumber(n) or 0
        total = total + n * (({ s = 1, m = 60, h = 3600, d = 86400, w = 604800 })[unit] or 1)
    end
    if matched then return math.max(0, total) end

    local n, unit = string.match(raw, "^(%d+)([smhdw]?)$")
    n = tonumber(n)
    if not n then return nil end
    local mult = ({ s = 1, m = 60, h = 3600, d = 86400, w = 604800 })[unit] or 1
    return math.max(0, n * mult)
end

local function usage(cmd)
    local parts = { "dadmin", cmd.name or "command" }
    for _, arg in ipairs(cmd.args or {}) do
        local name = istable(arg) and (arg.name or arg.type or "arg") or tostring(arg)
        parts[#parts + 1] = (istable(arg) and arg.optional) and "[" .. name .. "]" or "<" .. name .. ">"
    end
    return table.concat(parts, " ")
end

local function normalizeRawArgs(cmd, rawArgs)
    rawArgs = rawArgs or {}
    if not istable(rawArgs) then return { tostring(rawArgs) } end

    -- Already sequential from chat/console.
    if #rawArgs > 0 then return rawArgs end

    -- UI often sends named arguments. Convert to command arg order.
    local out = {}
    for i, argDef in ipairs(cmd.args or {}) do
        local name = istable(argDef) and (argDef.name or argDef.type) or tostring(argDef)
        out[i] = rawArgs[name]
    end
    return out
end

local function parseArg(admin, argDef, raw)
    argDef = istable(argDef) and argDef or { type = tostring(argDef or "string") }
    local argType = string.lower(tostring(argDef.type or argDef.name or "string"))

    if (raw == nil or raw == "") and argDef.optional then
        return true, nil
    end

    if argType == "player" or argType == "target" or argType == "players" then
        local targets = DAdmin.Players and DAdmin.Players.ResolveTarget and DAdmin.Players.ResolveTarget(admin, raw) or {}
        if not istable(targets) or #targets < 1 then
            return false, "No valid target found."
        end

        -- Basic immunity check. Owners/console can target everyone.
        if IsValid(admin) and DAdmin.GetUserRank and DAdmin.GetRank then
            local adminRank = DAdmin.GetRank(DAdmin.GetUserRank(admin))
            local adminImm = istable(adminRank) and tonumber(adminRank.immunity or 0) or 0
            for _, target in ipairs(targets) do
                if IsValid(target) and target ~= admin then
                    local targetRank = DAdmin.GetRank(DAdmin.GetUserRank(target))
                    local targetImm = istable(targetRank) and tonumber(targetRank.immunity or 0) or 0
                    if targetImm >= adminImm and not (DAdmin.HasPermission and DAdmin.HasPermission(admin, "override_immunity")) then
                        return false, "Target has equal or higher immunity: " .. target:Nick()
                    end
                end
            end
        end

        return true, targets
    elseif argType == "time" then
        local t = parseTime(raw)
        if t == nil then return false, "Invalid time value." end
        return true, t
    elseif argType == "number" then
        local n = tonumber(raw)
        if not n then return false, "Invalid number value." end
        return true, n
    elseif argType == "steamid" then
        local s = tostring(raw or "")
        if not string.match(s, "^STEAM_%d:%d:%d+$") and not string.match(s, "^%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d$") then
            return false, "Invalid SteamID."
        end
        return true, s
    elseif argType == "boolean" or argType == "bool" then
        local s = string.lower(tostring(raw or ""))
        return true, s == "true" or s == "1" or s == "yes" or s == "on"
    elseif argType == "string" or argType == "reason" then
        return true, string.sub(tostring(raw or ""), 1, 512)
    end

    return true, raw
end

function DAdmin.RunCommand(admin, cmdName, rawArgs)
    cmdName = string.lower(tostring(cmdName or ""))
    rawArgs = rawArgs or {}

    if IsValid(admin) and DAdmin.Security and not DAdmin.Security.RateLimit(admin, "command:" .. cmdName, 5, 1.5) then
        DAdmin.Msg(admin, "Command rate limit hit.")
        return false, "rate limited"
    end

    local cmd = DAdmin.GetCommand and DAdmin.GetCommand(cmdName) or DAdmin.Commands[cmdName]
    if not istable(cmd) or not isfunction(cmd.run) then
        DAdmin.Msg(admin, "Unknown command: " .. tostring(cmdName))
        return false, "unknown command"
    end

    if cmd.permission and not DAdmin.HasPermission(admin, cmd.permission) then
        if cmdName ~= "menu" and cmdName ~= "dmenu" then
            DAdmin.Msg(admin, "Permission denied for: " .. tostring(cmdName))
        end
        return false, "permission denied"
    end

    rawArgs = normalizeRawArgs(cmd, DAdmin.Security and DAdmin.Security.SanitizeTable(rawArgs) or rawArgs)

    local parsed = {}
    local defs = cmd.args or {}
    for i, argDef in ipairs(defs) do
        local raw = rawArgs[i]
        local argType = istable(argDef) and string.lower(tostring(argDef.type or argDef.name or "")) or tostring(argDef)

        -- Reason/string arguments at the end consume the rest of the chat input.
        if (argType == "string" or argType == "reason") and i == #defs and #rawArgs >= i then
            local rest = {}
            for j = i, #rawArgs do rest[#rest + 1] = tostring(rawArgs[j]) end
            raw = table.concat(rest, " ")
        end

        if (raw == nil or raw == "") and not (istable(argDef) and argDef.optional) then
            DAdmin.Msg(admin, "Usage: " .. usage(cmd))
            return false, "missing argument"
        end

        local ok, value = parseArg(admin, argDef, raw)
        if not ok then
            DAdmin.Msg(admin, value)
            return false, value
        end
        parsed[i] = value
    end

    -- Self-target protection for dangerous commands
    local selfBlockCmds = { ban = true, screengrab = true, kick = true }
    if selfBlockCmds[cmdName] and IsValid(admin) then
        for _, v in ipairs(parsed) do
            if istable(v) then
                for _, t in ipairs(v) do
                    if IsValid(t) and t == admin then
                        DAdmin.Msg(admin, "You cannot target yourself with " .. cmdName .. ".")
                        return false, "self target"
                    end
                end
            elseif IsValid(v) and v == admin then
                DAdmin.Msg(admin, "You cannot target yourself with " .. cmdName .. ".")
                return false, "self target"
            end
        end
    end

    local ok, result = xpcall(function()
        return cmd.run(admin, unpack(parsed))
    end, debug.traceback)

    if not ok then
        DAdmin.Msg(admin, "Command error. Check server console.")
        ErrorNoHalt("[DAdmin] Command '" .. tostring(cmdName) .. "' failed:\n" .. tostring(result) .. "\n")
        return false, result
    end

    if DAdmin.Log and not string.StartWith(cmdName, "menu") then
        local argText = {}
        for _, v in ipairs(rawArgs) do argText[#argText + 1] = tostring(v) end
        DAdmin.Log("command", admin, nil, cmdName .. (#argText > 0 and (" " .. table.concat(argText, " ")) or ""))
    end

    return result ~= false, result
end
