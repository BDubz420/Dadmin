if CLIENT then return end
DAdmin = DAdmin or {}

util.AddNetworkString("DAdmin_FeatureSettings_Request")
util.AddNetworkString("DAdmin_FeatureSettings_Send")
util.AddNetworkString("DAdmin_FeatureSettings_Save")
util.AddNetworkString("DAdmin_PermissionMatrix_Request")
util.AddNetworkString("DAdmin_PermissionMatrix_Send")
util.AddNetworkString("DAdmin_PermissionMatrix_Set")

local function saveConfig()
    if DAdmin.Storage and DAdmin.Storage.Save then DAdmin.Storage.Save("config.json", DAdmin.Config or {}) end
end

local function can(ply, perm)
    if DAdmin.Security and DAdmin.Security.CanUseMenu and not DAdmin.Security.CanUseMenu(ply) then return false end
    return DAdmin.HasPermission and DAdmin.HasPermission(ply, perm)
end

net.Receive("DAdmin_FeatureSettings_Request", function(_, ply)
    if not can(ply, "settings.features") and not can(ply, "menu") then return end
    net.Start("DAdmin_FeatureSettings_Send")
    net.WriteTable(DAdmin.GetFeatureConfig and DAdmin.GetFeatureConfig() or DAdmin.Config or {})
    net.Send(ply)
end)

net.Receive("DAdmin_FeatureSettings_Save", function(_, ply)
    if not can(ply, "settings.features") then return end
    local incoming = net.ReadTable() or {}
    for k,v in pairs(incoming) do
        if not isfunction(v) then DAdmin.Config[k] = v end
    end
    saveConfig()
    if DAdmin.MegaLogs then DAdmin.MegaLogs.Add("settings", "save_features", ply, "DAdmin", "Updated feature settings") end
end)

local function permissionsForRank(rank)
    local r = DAdmin.GetRank and DAdmin.GetRank(rank) or nil
    local out = {}
    if istable(r) and istable(r.permissions) then
        for k,v in pairs(r.permissions) do
            if isnumber(k) then out[string.lower(tostring(v))]=true else out[string.lower(tostring(k))]=v and true or false end
        end
    end
    return out
end

local function sendMatrix(ply)
    local ranks = {}
    for id, r in pairs(DAdmin.Ranks or {}) do
        if istable(r) then
            ranks[#ranks+1] = { id=tostring(id), name=r.label or r.name or tostring(id), inherit=r.inherit or r.inherits or "" }
        end
    end
    table.sort(ranks, function(a,b) return a.id < b.id end)
    local permSet = {}
    for _, p in ipairs(DAdmin.GetAllPermissions and DAdmin.GetAllPermissions() or {}) do
        permSet[string.lower(tostring(p))] = true
    end
    for _, rankData in pairs(DAdmin.Ranks or {}) do
        if istable(rankData) and istable(rankData.permissions) then
            for k, v in pairs(rankData.permissions) do
                if isnumber(k) then
                    permSet[string.lower(tostring(v))] = true
                elseif v then
                    permSet[string.lower(tostring(k))] = true
                end
            end
        end
    end
    local perms = {}
    for p in pairs(permSet) do perms[#perms+1] = p end
    table.sort(perms)
    local matrix = {}
    for _, r in ipairs(ranks) do matrix[r.id] = permissionsForRank(r.id) end
    net.Start("DAdmin_PermissionMatrix_Send")
    net.WriteTable({ranks=ranks, permissions=perms, matrix=matrix})
    net.Send(ply)
end

net.Receive("DAdmin_PermissionMatrix_Request", function(_, ply)
    if not (can(ply, "permissions.view") or can(ply, "permissions")) then return end
    sendMatrix(ply)
end)

net.Receive("DAdmin_PermissionMatrix_Set", function(_, ply)
    if not (can(ply, "permissions.manage") or can(ply, "permissions")) then return end
    local rank = string.lower(net.ReadString() or "")
    local perm = string.lower(net.ReadString() or "")
    local enabled = net.ReadBool()
    local r = DAdmin.GetRank and DAdmin.GetRank(rank)
    if not istable(r) then return end
    r.permissions = r.permissions or {}
    r.permissions[perm] = enabled or nil
    if DAdmin.SaveRanks then DAdmin.SaveRanks() elseif DAdmin.Storage and DAdmin.Storage.Save then DAdmin.Storage.Save("ranks.json", DAdmin.Ranks or {}) end
    if DAdmin.InvalidatePermissionCache then DAdmin.InvalidatePermissionCache() end
    if DAdmin.BroadcastRankUpdate then DAdmin.BroadcastRankUpdate() end
    if DAdmin.MegaLogs then DAdmin.MegaLogs.Add("permissions", enabled and "grant" or "revoke", ply, rank, perm) end
    sendMatrix(ply)
end)
