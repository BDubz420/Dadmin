-- DAdmin Default Rank and Permission Setup
DAdmin = DAdmin or {}

if DAdmin.EnsureDefaultRanks then DAdmin.EnsureDefaultRanks() end
if DAdmin.SaveRanks then DAdmin.SaveRanks() end

local defaults = {
    "menu", "admin", "kick", "ban", "unban", "mute", "gag", "freeze",
    "goto", "bring", "return", "jail", "unjail", "noclip", "god",
    "strip", "respawn", "screengrab", "reports", "logs", "cases",
    "rank", "rankedit", "permissions", "servertools", "cleanup", "maprestart", "warn", "unwarn", "report", "reports.override", "broadcast", "sits", "override_immunity", "guard", "guard.admin", "cases.close"
}

for _, perm in ipairs(defaults) do
    if DAdmin.RegisterPermission then DAdmin.RegisterPermission(perm) end
end

print("[DAdmin] Default ranks and permissions verified")
