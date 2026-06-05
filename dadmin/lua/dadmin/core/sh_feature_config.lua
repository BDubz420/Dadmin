DAdmin = DAdmin or {}
DAdmin.FeatureConfig = DAdmin.FeatureConfig or {}

local S = DAdmin.StaticConfig or {}
local ST = S.Storage or {}
local PT = S.PlayTime or {}
local SZ = S.SafeZones or {}
local LG = S.Logs or {}
local NT = S.Notifications or {}

DAdmin.FeatureConfig.Default = {
    storage_backend = ST.backend or "json",
    sqlite_enabled = ST.sqlite_enabled == true,
    database_enabled = ST.database_enabled == true,
    database_driver = ST.database_driver or "sqlite",
    sqlite_file = ST.sqlite_file or "dadmin.sqlite",

    playtime_enabled = PT.enabled ~= false,
    playtime_hud_enabled = PT.hud_enabled ~= false,
    playtime_hud_color = PT.hud_color or "4A90D9",
    playtime_hud_accent = PT.hud_accent or "90AAE9",
    playtime_save_interval = tonumber(PT.save_interval or 60) or 60,

    logs_enabled = LG.enabled ~= false,
    logs_max_entries = tonumber(LG.max_entries or 25000) or 25000,
    logs_storage_backend = LG.storage_backend or "json",
    logs_full_history = LG.full_history ~= false,

    safezones_enabled = SZ.enabled ~= false,
    safezone_ui_enabled = SZ.ui_enabled ~= false,
    safezone_ui_color = SZ.ui_color or "4A90D9",
    safezone_default_height = tonumber(SZ.default_height or 160) or 160,
    safezone_default_settings = table.Copy(SZ.default_settings or {
        god = true,
        block_damage = true,
        strip_weapons = false,
        prevent_fire = true,
        prevent_props = true,
        prevent_sents = true,
        prevent_vehicles = true,
        prevent_npcs = true,
        freeze_props = false,
        no_collide_props = false,
        prevent_physgun = false,
        show_ui = true,
        hud_color = "4A90D9"
    }),

    notify_warn = NT.warn ~= false,
    notify_rank = NT.rank ~= false,
    notify_bring = NT.bring ~= false,
    notify_spectate = NT.spectate == true,
    notify_safezone = NT.safezone ~= false,
    notify_playtime = NT.playtime == true,
    notify_logs = NT.logs == true
}

local function deepCopy(v, seen)
    if not istable(v) then return v end
    seen = seen or {}
    if seen[v] then return seen[v] end
    local out = {}
    seen[v] = out
    for k, val in pairs(v) do out[deepCopy(k, seen)] = deepCopy(val, seen) end
    return out
end

local function deepMerge(base, extra)
    base = deepCopy(base or {})
    if not istable(extra) then return base end
    for k, v in pairs(extra) do
        if istable(v) and istable(base[k]) then base[k] = deepMerge(base[k], v) else base[k] = deepCopy(v) end
    end
    return base
end

function DAdmin.GetFeatureConfig()
    return deepMerge(DAdmin.FeatureConfig.Default, DAdmin.Config or {})
end

function DAdmin.HexColor(hex, fallback)
    fallback = fallback or Color(74,144,217)
    hex = tostring(hex or "")
    if #hex < 6 then return fallback end
    return Color(tonumber("0x"..string.sub(hex,1,2)) or fallback.r, tonumber("0x"..string.sub(hex,3,4)) or fallback.g, tonumber("0x"..string.sub(hex,5,6)) or fallback.b, 255)
end

for _, perm in ipairs({
    "tab.dashboard","tab.players","tab.reports","tab.history","tab.ranks","tab.logs","tab.commands","tab.permissions","tab.guard","tab.control","tab.settings","tab.safezones","tab.playtime",
    "safezones.view","safezones.create","safezones.edit","safezones.delete","safezones.manage",
    "playtime.view","playtime.manage","playtime.reset","playtime.set","playtime.toggle",
    "logs.view","logs.export","logs.clear","logs.full",
    "permissions.view","permissions.manage","permissions.rank",
    "settings.features","settings.storage","settings.notifications",
    "rank.create","rank.delete","rank.edit",
    "command.freezeprop","command.startsit","command.endsit"
}) do
    if DAdmin.RegisterPermission then DAdmin.RegisterPermission(perm, { title = perm }) end
end
