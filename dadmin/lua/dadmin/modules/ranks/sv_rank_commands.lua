-- DAdmin Rank Commands
DAdmin = DAdmin or {}

local function say(admin, msg)
    if IsValid(admin) then DAdmin.Msg(admin, msg) else print("[DAdmin] " .. msg) end
end

function DAdmin.CreateRank(name)
    if not isstring(name) or name == "" then return false end
    if DAdmin.Ranks[string.lower(name)] then return false end
    return DAdmin.RegisterRank(name, { immunity = 0, permissions = {}, inherit = "user" })
end

function DAdmin.DeleteRank(name)
    name = string.lower(tostring(name or ""))
    if name == "owner" or name == "superadmin" or name == "admin" or name == "moderator" or name == "user" then return false end
    if not DAdmin.Ranks[name] then return false end
    DAdmin.Ranks[name] = nil
    if DAdmin.SaveRanks then DAdmin.SaveRanks() end
    if DAdmin.InvalidatePermissionCache then DAdmin.InvalidatePermissionCache() end
    return true
end

function DAdmin.SetRankImmunity(name, value)
    local rank = DAdmin.GetRank(name)
    if not rank then return false end
    rank.immunity = tonumber(value) or 0
    rank.priority = rank.immunity
    if DAdmin.SaveRanks then DAdmin.SaveRanks() end
    if DAdmin.InvalidatePermissionCache then DAdmin.InvalidatePermissionCache() end
    return true
end

function DAdmin.SetRankInheritance(rankName, parent)
    local rank = DAdmin.GetRank(rankName)
    if not rank or (parent and not DAdmin.GetRank(parent)) then return false end
    rank.inherit = parent
    rank.inherits = parent
    if DAdmin.SaveRanks then DAdmin.SaveRanks() end
    if DAdmin.InvalidatePermissionCache then DAdmin.InvalidatePermissionCache() end
    return true
end

local function hasPerm(list, perm)
    for _, p in ipairs(list or {}) do if p == perm then return true end end
    return false
end

function DAdmin.AddRankPermission(rankName, perm)
    local rank = DAdmin.GetRank(rankName)
    if not rank or not perm then return false end
    perm = string.lower(tostring(perm))
    rank.permissions = rank.permissions or {}
    if not hasPerm(rank.permissions, perm) then rank.permissions[#rank.permissions + 1] = perm end
    table.sort(rank.permissions)
    if DAdmin.RegisterPermission then DAdmin.RegisterPermission(perm) end
    if DAdmin.SaveRanks then DAdmin.SaveRanks() end
    if DAdmin.InvalidatePermissionCache then DAdmin.InvalidatePermissionCache() end
    return true
end

function DAdmin.RemoveRankPermission(rankName, perm)
    local rank = DAdmin.GetRank(rankName)
    if not rank or not perm then return false end
    perm = string.lower(tostring(perm))
    for i = #rank.permissions, 1, -1 do
        if rank.permissions[i] == perm then table.remove(rank.permissions, i) end
    end
    if DAdmin.SaveRanks then DAdmin.SaveRanks() end
    if DAdmin.InvalidatePermissionCache then DAdmin.InvalidatePermissionCache() end
    return true
end

DAdmin.RegisterCommand("createrank", {
    permission = "rank",
    description = "Create a new rank",
    category = "Ranks",
    args = {{name = "name", type = "string"}},
    run = function(admin, name)
        say(admin, DAdmin.CreateRank(name) and ("Rank '" .. name .. "' created.") or "Failed to create rank.")
    end
})

DAdmin.RegisterCommand("deleterank", {
    permission = "rank",
    description = "Delete a custom rank",
    category = "Ranks",
    args = {{name = "name", type = "string"}},
    run = function(admin, name)
        say(admin, DAdmin.DeleteRank(name) and ("Rank '" .. name .. "' deleted.") or "Failed to delete rank.")
    end
})

DAdmin.RegisterCommand("setrankimmunity", {
    permission = "rank",
    description = "Set rank immunity",
    category = "Ranks",
    args = {{name = "name", type = "string"}, {name = "value", type = "number"}},
    run = function(admin, name, value)
        say(admin, DAdmin.SetRankImmunity(name, value) and ("Rank '" .. name .. "' immunity set to " .. tostring(value) .. ".") or "Failed to set immunity.")
    end
})

DAdmin.RegisterCommand("inherit", {
    permission = "rank",
    description = "Set rank inheritance",
    category = "Ranks",
    args = {{name = "rank", type = "string"}, {name = "parent", type = "string"}},
    run = function(admin, rank, parent)
        say(admin, DAdmin.SetRankInheritance(rank, parent) and ("Rank '" .. rank .. "' now inherits from '" .. parent .. "'.") or "Failed to set inheritance.")
    end
})

DAdmin.RegisterCommand("addperm", {
    permission = "rank",
    description = "Add permission to rank",
    category = "Ranks",
    args = {{name = "rank", type = "string"}, {name = "perm", type = "string"}},
    run = function(admin, rank, perm)
        say(admin, DAdmin.AddRankPermission(rank, perm) and ("Permission '" .. perm .. "' added to rank '" .. rank .. "'.") or "Failed to add permission.")
    end
})

DAdmin.RegisterCommand("removeperm", {
    permission = "rank",
    description = "Remove permission from rank",
    category = "Ranks",
    args = {{name = "rank", type = "string"}, {name = "perm", type = "string"}},
    run = function(admin, rank, perm)
        say(admin, DAdmin.RemoveRankPermission(rank, perm) and ("Permission '" .. perm .. "' removed from rank '" .. rank .. "'.") or "Failed to remove permission.")
    end
})

DAdmin.RegisterCommand("setuser", {
    permission = "rank",
    description = "Set user rank",
    category = "Ranks",
    args = {{name = "target", type = "player"}, {name = "rank", type = "string"}},
    run = function(admin, targets, rank)
        for _, target in ipairs(targets or {}) do
            say(admin, DAdmin.SetUserRank(target, rank) and (target:Nick() .. " set to rank '" .. rank .. "'.") or ("Failed to rank " .. target:Nick() .. "."))
        end
    end
})
