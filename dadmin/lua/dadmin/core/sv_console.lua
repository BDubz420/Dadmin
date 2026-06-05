-- DAdmin Console Command System
concommand.Add("dadmin", function(ply, cmd, args)
    if not DAdmin or not DAdmin.Commands then
        print("[DAdmin] Command system not initialized")
        return
    end
    local command = args[1]
    if not command then
        print("[DAdmin] Usage: dadmin <command>")
        return
    end
    table.remove(args, 1)
    DAdmin.RunCommand(ply, command, args)
end,
function(cmd, stringargs)
    local suggestions = {}
    if not DAdmin or not DAdmin.Commands then return suggestions end
    local ply = LocalPlayer and LocalPlayer() or nil
    local args = string.Explode(" ", stringargs)
    local partialCmd = args[1] or ""
    local partialArg = args[2] or ""

    local function argName(arg)
        if istable(arg) then return arg.name or arg.type or "arg" end
        return tostring(arg or "arg")
    end

    if partialCmd == "" then
        for name, data in pairs(DAdmin.Commands) do
            if istable(data) and (not data.permission or (DAdmin.HasPermission and DAdmin.HasPermission(ply, data.permission))) then
                local hint = "dadmin " .. name
                if data.args then
                    for _, a in ipairs(data.args) do
                        hint = hint .. " <" .. argName(a) .. ">"
                    end
                end
                table.insert(suggestions, hint)
            end
        end
        return suggestions
    end

    local cmdData = DAdmin.Commands[partialCmd]
    if istable(cmdData) then
        if not cmdData.permission or (DAdmin.HasPermission and DAdmin.HasPermission(ply, cmdData.permission)) then
            local hint = "dadmin " .. partialCmd
            if cmdData.args then
                for _, a in ipairs(cmdData.args) do
                    hint = hint .. " <" .. argName(a) .. ">"
                end
            end
            table.insert(suggestions, hint)
            if cmdData.args and cmdData.args[1] then
                local firstType = istable(cmdData.args[1]) and string.lower(cmdData.args[1].type or "") or ""
                if (firstType == "player" or firstType == "target") and partialArg ~= "" then
                    for _, plyEnt in ipairs(player.GetAll()) do
                        if string.lower(plyEnt:Nick()):find(string.lower(partialArg), 1, true) == 1 then
                            table.insert(suggestions, "dadmin " .. partialCmd .. " " .. plyEnt:Nick())
                        end
                    end
                end
            end
        end
        return suggestions
    end

    for name, data in pairs(DAdmin.Commands) do
        if istable(data) and string.StartWith(name, partialCmd) and (not data.permission or (DAdmin.HasPermission and DAdmin.HasPermission(ply, data.permission))) then
            local hint = "dadmin " .. name
            if data.args then
                for _, a in ipairs(data.args) do
                    hint = hint .. " <" .. argName(a) .. ">"
                end
            end
            table.insert(suggestions, hint)
        end
    end
    return suggestions
end)
