--[[
    DAdmin owner-editable static configuration.
    Runtime settings still save in data/dadmin/config.json, but these values keep
    storage/database defaults and module defaults out of the Settings tab.
]]

DAdmin = DAdmin or {}
DAdmin.StaticConfig = DAdmin.StaticConfig or {}

DAdmin.StaticConfig.Storage = {
    -- "json" is the active/default backend. SQLite support is prepared behind this toggle.
    backend = "json",
    sqlite_enabled = false,
    database_enabled = false,
    database_driver = "sqlite",
    sqlite_file = "dadmin.sqlite",
}

DAdmin.StaticConfig.PlayTime = {
    enabled = true,
    hud_enabled = true,
    hud_color = "4A90D9",
    hud_accent = "90AAE9",
    save_interval = 60,
}

DAdmin.StaticConfig.SafeZones = {
    enabled = true,
    ui_enabled = true,
    ui_color = "4A90D9",
    default_height = 160,
    default_settings = {
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
    }
}

DAdmin.StaticConfig.Logs = {
    enabled = true,
    storage_backend = "json",
    max_entries = 25000,
    full_history = true,
}

DAdmin.StaticConfig.Notifications = {
    warn = true,
    rank = true,
    bring = true,
    spectate = false,
    safezone = true,
    playtime = false,
    logs = false,
}


DAdmin.StaticConfig.Guard = {
    enabled = true,
    notify_staff = true,
    autoban = false,
    autoban_threshold = 95,
    alert_cooldown = 6,
    max_alerts = 500,
    modules = {
        speedhack = true,
        spinbot = true,
        bhop = true,
        noclip_abuse = true,
        propspam = true,
        toolspam = true,
        chatspam = true,
        crash = true,
        lua_exploit = true,
        aimbot = true,
        esp = false
    }
}
