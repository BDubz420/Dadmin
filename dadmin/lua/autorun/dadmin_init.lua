DAdmin = DAdmin or {}

local shared_files = {
    "dadmin/config/sh_config.lua",
    "dadmin/core/sh_core.lua",
    "dadmin/core/sh_boot.lua",
    "dadmin/core/sh_commands.lua",
    "dadmin/core/sh_args.lua",
    "dadmin/core/sh_log.lua",
    "dadmin/core/sh_permissions.lua",
    "dadmin/core/sh_ranks.lua",
    "dadmin/core/sh_resolver.lua",
    "dadmin/core/sh_targets.lua",
    "dadmin/core/sh_gamemode.lua",
    "dadmin/core/sh_feature_config.lua",
    "dadmin/ranks/sh_ranks.lua",
    "dadmin/commands/sh_commands.lua",
}

local server_files = {
    "dadmin/core/sv_storage.lua",
    "dadmin/core/sv_default_setup.lua",
    "dadmin/core/sv_security.lua",
    "dadmin/core/sv_guard.lua",
    "dadmin/core/sv_intelligence.lua",
    "dadmin/core/sv_staff_control.lua",
    "dadmin/core/sv_command_runner.lua",
    "dadmin/core/sv_console.lua",
    "dadmin/core/sv_history.lua",
    "dadmin/core/sv_cases.lua",
    "dadmin/core/sv_reports.lua",
    "dadmin/core/sv_radar.lua",
    "dadmin/core/sv_warns.lua",
    "dadmin/core/sv_ui_bridge.lua",
    "dadmin/modules/settings/sv_feature_settings.lua",
    "dadmin/modules/logs/sv_megalogs.lua",
    "dadmin/modules/playtime/sv_playtime.lua",
    "dadmin/modules/safezones/sv_safezones.lua",
    "dadmin/core/sv_sits.lua",
    "dadmin/core/sv_physgun_freeze.lua",
    "dadmin/ranks/sv_ranks.lua",
    "dadmin/modules/ranks/sv_rank_commands.lua",
    "dadmin/services/sv_players.lua",
    "dadmin/services/sv_punishments.lua",
    "dadmin/services/sv_server.lua",
    "dadmin/commands/sv_commands.lua",
    "dadmin/commands/sv_player_commands.lua",
    "dadmin/commands/sv_movement_commands.lua",
    "dadmin/commands/sv_admin_commands.lua",
    "dadmin/commands/sv_jail.lua",
    "dadmin/commands/sv_screengrab.lua",
    "dadmin/commands/sv_menu.lua",
    "dadmin/net/sv_net.lua",
    "dadmin/core/sv_chat.lua",
    "dadmin/core/sv_game_events.lua",
}

local client_files = {
    "dadmin/core/cl_port_data.lua",
    "dadmin/net/cl_net.lua",
    "dadmin/ui/cl_net.lua",
    "dadmin/ui/cl_theme.lua",
    "dadmin/ui/cl_menu_builder.lua",
    "dadmin/ui/cl_dashboard_panel.lua",
    "dadmin/ui/cl_players_panel.lua",
    "dadmin/ui/cl_reports_panel.lua",
    "dadmin/ui/cl_cases_panel.lua",
    "dadmin/ui/cl_player_history.lua",
    "dadmin/ui/cl_ranks_panel.lua",
    "dadmin/ui/cl_logs_panel.lua",
    "dadmin/ui/cl_commands_panel.lua",
    "dadmin/ui/cl_permissions_panel.lua",
    "dadmin/ui/cl_admin_settings_panel.lua",
    "dadmin/modules/ui/cl_feature_panels.lua",
    "dadmin/modules/playtime/cl_playtime.lua",
    "dadmin/modules/safezones/cl_safezones.lua",
    "dadmin/ui/cl_radar_alerts.lua",
    "dadmin/ui/cl_guard_panel.lua",
    "dadmin/ui/cl_control_panel.lua",
    "dadmin/ui/cl_command_palette.lua",
    "dadmin/ui/cl_evidence_viewer.lua",
    "dadmin/ui/cl_permission_graph.lua",
    "dadmin/ui/cl_player_manager.lua",
    "dadmin/ui/cl_spectate_overlay.lua",
    "dadmin/ui/cl_screengrab_viewer.lua",
    "dadmin/commands/cl_screengrab.lua",
}

if SERVER then
    for _, path in ipairs(shared_files) do
        AddCSLuaFile(path)
        include(path)
    end

    for _, path in ipairs(client_files) do
        AddCSLuaFile(path)
    end

    for _, path in ipairs(server_files) do
        include(path)
    end

    concommand.Add("dadmin_menu", function(ply)
        if not IsValid(ply) then return end
        net.Start("dadmin_open_menu")
        net.Send(ply)
    end)

    return
end

for _, path in ipairs(shared_files) do
    include(path)
end

for _, path in ipairs(client_files) do
    include(path)
end

local function dadmin_open(defaultTab)
    if DAdmin and DAdmin.OpenMenu then
        DAdmin.OpenMenu(defaultTab)
    else
        print("[DAdmin] OpenMenu missing on client")
    end
end

concommand.Add("dadmin_menu", function()
    dadmin_open()
end)

concommand.Add("dmenu", function()
    dadmin_open()
end)

hook.Add("OnPlayerChat", "DAdmin_Port_ChatOpen", function(ply, text)
    if ply ~= LocalPlayer() or not isstring(text) then return end
    local lowered = string.lower(string.Trim(text))
    if lowered == "!dadmin" or lowered == "/dadmin" or lowered == "!menu" then
        dadmin_open()
        return true
    end
end)
