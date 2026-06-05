if SERVER then return end
local UI = DAdmin.UI
local C = UI.Colors

function DAdmin.BuildSettingsPanel(parent)
    parent:Clear()
    local settings = table.Copy(DAdmin.Port.GetSettings())
    local shell = vgui.Create("DScrollPanel", parent)
    shell:Dock(FILL)

    local cols = vgui.Create("DPanel", shell)
    cols:Dock(TOP)
    cols:SetTall(560)
    cols.Paint = nil

    local left = vgui.Create("DPanel", cols) left:Dock(LEFT) left:SetWide(parent:GetWide() / 2 - 3) left.Paint = nil
    local right = vgui.Create("DPanel", cols) right:Dock(FILL) right:DockMargin(5, 0, 0, 0) right.Paint = nil

    local function addTextRow(host, label, key, width)
        local p = vgui.Create("DPanel", host) p:Dock(TOP) p:SetTall(24) p.Paint = function(_, w, h)
            draw.SimpleText(label, "DAdmin.Small", 8, h / 2, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
        local e = vgui.Create("DTextEntry", p) e:Dock(RIGHT) e:DockMargin(0, 3, 8, 3) e:SetWide(width or 150)
        e:SetText(tostring(settings[key] or "")) UI.StyleTextEntry(e)
        e.OnChange = function(self) settings[key] = self:GetValue() end
    end

    local function addToggleRow(host, label, key)
        local p = vgui.Create("DPanel", host) p:Dock(TOP) p:SetTall(24) p.Paint = function(_, w, h)
            draw.SimpleText(label, "DAdmin.Small", 8, h / 2, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
        local isOn = settings[key] and true or false
        local b = vgui.Create("DButton", p) b:Dock(RIGHT) b:DockMargin(0, 4, 8, 4) b:SetSize(42, 15)
        b:SetText(isOn and "ON" or "OFF")
        UI.StyleButton(b, isOn and "primary" or nil)
        b.DoClick = function()
            settings[key] = not settings[key]
            local newOn = settings[key] and true or false
            b:SetText(newOn and "ON" or "OFF")
            b._variant = newOn and "primary" or nil
        end
    end

    local function addColorRow(host, label, key)
        local p = vgui.Create("DPanel", host) p:Dock(TOP) p:SetTall(24) p.Paint = function(_, w, h)
            draw.SimpleText(label, "DAdmin.Small", 8, h / 2, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
        local preview = vgui.Create("DPanel", p) preview:Dock(RIGHT) preview:DockMargin(0, 5, 8, 5) preview:SetWide(14)
        local hex = settings[key] or "4A90D9"
        local r2, g2, b2 = tonumber("0x" .. string.sub(hex, 1, 2)) or 74, tonumber("0x" .. string.sub(hex, 3, 4)) or 144, tonumber("0x" .. string.sub(hex, 5, 6)) or 217
        preview.Paint = function(_, w, h)
            surface.SetDrawColor(r2, g2, b2, 255) surface.DrawRect(0, 0, w, h)
            surface.SetDrawColor(C.border) surface.DrawOutlinedRect(0, 0, w, h, 1)
        end
        local e = vgui.Create("DTextEntry", p) e:Dock(RIGHT) e:DockMargin(0, 3, 4, 3) e:SetWide(65) e:SetText(hex) UI.StyleTextEntry(e)
        e.OnChange = function(self)
            local val = self:GetValue()
            settings[key] = val
            local rr, gg, bb = tonumber("0x" .. string.sub(val, 1, 2)), tonumber("0x" .. string.sub(val, 3, 4)), tonumber("0x" .. string.sub(val, 5, 6))
            if rr and gg and bb then r2, g2, b2 = rr, gg, bb end
        end
    end

    -- General
    local general, gb = UI.MakeSection(left, "General", TOP) general:SetTall(195)
    addTextRow(gb, "Server Name", "server_name", 150)
    addTextRow(gb, "Chat Prefix", "prefix", 40)
    addColorRow(gb, "Prefix Color (hex)", "prefix_color")
    addTextRow(gb, "Default Rank", "default_rank", 80)
    addTextRow(gb, "Max Warnings", "max_warns", 40)
    addToggleRow(gb, "Ban on max warns", "ban_on_warns")
    addToggleRow(gb, "Immunity check", "immunity_check")

    -- Logging
    local logging, lb = UI.MakeSection(left, "Logging", TOP, {0, 5, 0, 0}) logging:SetTall(142)
    addToggleRow(lb, "Log all commands", "log_commands")
    addToggleRow(lb, "Log chat messages", "log_chat")
    addToggleRow(lb, "Chat action log (commands)", "chat_log_commands")
    addToggleRow(lb, "Chat action log (permissions)", "chat_log_permissions")
    addTextRow(lb, "Log retention (days)", "log_retention", 40)

    -- MOTD
    local motd, mb = UI.MakeSection(left, "MOTD", FILL, {0, 5, 0, 0})
    local txt = vgui.Create("DTextEntry", mb) txt:Dock(FILL) txt:DockMargin(6, 6, 6, 6) txt:SetMultiline(true)
    txt:SetText(settings.motd or "") UI.StyleTextEntry(txt)
    txt.OnChange = function(self) settings.motd = self:GetValue() end

    -- Feature Toggles
    local features, fb = UI.MakeSection(right, "Feature Toggles", TOP) features:SetTall(170)
    addToggleRow(fb, "Enable playtime tracking", "playtime_enabled")
    addToggleRow(fb, "Enable playtime HUD", "playtime_hud_enabled")
    addToggleRow(fb, "Enable safezones", "safezones_enabled")
    addToggleRow(fb, "Enable safezone HUD", "safezone_ui_enabled")
    addToggleRow(fb, "Enable chat protection", "chat_protection_enabled")
    addToggleRow(fb, "Block matched chat", "chat_protection_block")

    local chatFilter, cfb = UI.MakeSection(right, "Chat Filter", TOP, {0, 5, 0, 0}) chatFilter:SetTall(170)
    local filterHelp = vgui.Create("DLabel", cfb)
    filterHelp:Dock(TOP)
    filterHelp:DockMargin(8, 6, 8, 0)
    filterHelp:SetFont("DAdmin.Small")
    filterHelp:SetTextColor(C.textDim)
    filterHelp:SetWrap(true)
    filterHelp:SetAutoStretchVertical(true)
    filterHelp:SetText("One blocked phrase per line. Messages matching a listed phrase will be blocked when chat protection is enabled.")
    local blocked = vgui.Create("DTextEntry", cfb)
    blocked:Dock(FILL)
    blocked:DockMargin(8, 6, 8, 8)
    blocked:SetMultiline(true)
    blocked:SetText(tostring(settings.chat_blocked_phrases or ""))
    UI.StyleTextEntry(blocked)
    blocked.OnChange = function(self) settings.chat_blocked_phrases = self:GetValue() end

    -- Notifications
    local notes, nb = UI.MakeSection(right, "Notifications", TOP, {0, 5, 0, 0}) notes:SetTall(140)
    addToggleRow(nb, "Admin notify on kick", "notify_kick")
    addToggleRow(nb, "Admin notify on ban", "notify_ban")
    addToggleRow(nb, "Admin notify on report", "notify_report")
    addToggleRow(nb, "Announce admin joins", "notify_join")
    addToggleRow(nb, "Show MOTD on join", "motd_on_join")

    -- About
    local about, ab = UI.MakeSection(right, "About DAdmin", TOP, {0, 5, 0, 0}) about:SetTall(130)
    for _, row in ipairs({
        {"Version", "v2.2.0", C.blue}, {"Author", "BDubzilla / port integration", C.text},
        {"Framework", "GMod Lua", C.text}, {"License", "MIT", C.green}, {"Build", os.date("%Y%m%d"), C.textDim}
    }) do
        local p = vgui.Create("DPanel", ab) p:Dock(TOP) p:SetTall(22) p.Paint = function(_, w, h)
            draw.SimpleText(row[1], "DAdmin.Small", 8, h / 2, C.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText(row[2], "DAdmin.Small", w - 8, h / 2, row[3], TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end
    end

    -- Danger Zone with confirmation dialogs
    local danger, db = UI.MakeSection(right, "Danger Zone", TOP, {0, 5, 0, 0}) danger:SetTall(116)
    local function dangerButton(txt, action)
        local b = vgui.Create("DButton", db) b:Dock(TOP) b:DockMargin(8, 4, 8, 0) b:SetTall(22) b:SetText(txt)
        UI.StyleButton(b, "danger")
        b.DoClick = function()
            local confirm = vgui.Create("EditablePanel")
            confirm:SetSize(300, 120) confirm:Center() confirm:MakePopup()
            confirm.Paint = function(_, w, h) UI.PaintPanel(w, h) end
            local hdr = vgui.Create("DPanel", confirm) hdr:Dock(TOP) hdr:SetTall(22)
            hdr.Paint = function(_, w, h) UI.PaintHeader(w, h, "Confirm Action") end
            local lbl = vgui.Create("DLabel", confirm) lbl:Dock(TOP) lbl:DockMargin(10, 10, 10, 0)
            lbl:SetFont("DAdmin.Normal") lbl:SetTextColor(C.red) lbl:SetWrap(true) lbl:SetTall(30)
            lbl:SetText("Are you sure you want to " .. txt .. "? This cannot be undone.")
            local btns = vgui.Create("DPanel", confirm) btns:Dock(BOTTOM) btns:SetTall(30) btns.Paint = nil
            local yes = vgui.Create("DButton", btns) yes:Dock(RIGHT) yes:DockMargin(0, 4, 8, 4) yes:SetWide(80)
            yes:SetText("Yes, do it") UI.StyleButton(yes, "danger")
            yes.DoClick = function() DAdmin.Port.UIAction(action, {}) confirm:Remove() end
            local no = vgui.Create("DButton", btns) no:Dock(RIGHT) no:DockMargin(0, 4, 4, 4) no:SetWide(60)
            no:SetText("Cancel") UI.StyleButton(no)
            no.DoClick = function() confirm:Remove() end
        end
    end
    dangerButton("Clear all bans", "clear_bans")
    dangerButton("Clear all warnings", "clear_warns")
    dangerButton("Reset rank assignments", "reset_rank_assignments")

    -- Save/Reset buttons
    local buttons = vgui.Create("DPanel", right) buttons:Dock(BOTTOM) buttons:SetTall(26) buttons.Paint = nil
    local save = vgui.Create("DButton", buttons) save:Dock(RIGHT) save:SetWide(90) save:SetText("Save Settings")
    UI.StyleButton(save, "primary")
    save.DoClick = function() DAdmin.Port.UIAction("save_settings", { settings = settings }) end
    local reset = vgui.Create("DButton", buttons) reset:Dock(RIGHT) reset:DockMargin(0, 0, 6, 0) reset:SetWide(92)
    reset:SetText("Reset Defaults") UI.StyleButton(reset)
    reset.DoClick = function()
        local confirm = vgui.Create("EditablePanel")
        confirm:SetSize(280, 110) confirm:Center() confirm:MakePopup()
        confirm.Paint = function(_, w, h) UI.PaintPanel(w, h) end
        local hdr = vgui.Create("DPanel", confirm) hdr:Dock(TOP) hdr:SetTall(22)
        hdr.Paint = function(_, w, h) UI.PaintHeader(w, h, "Reset to Defaults?") end
        local lbl = vgui.Create("DLabel", confirm) lbl:Dock(TOP) lbl:DockMargin(10, 10, 10, 0)
        lbl:SetFont("DAdmin.Normal") lbl:SetTextColor(C.yellow) lbl:SetText("This will reset ALL settings to defaults.")
        local btns2 = vgui.Create("DPanel", confirm) btns2:Dock(BOTTOM) btns2:SetTall(30) btns2.Paint = nil
        local yes = vgui.Create("DButton", btns2) yes:Dock(RIGHT) yes:DockMargin(0, 4, 8, 4) yes:SetWide(60) yes:SetText("Reset")
        UI.StyleButton(yes, "danger") yes.DoClick = function() DAdmin.Port.UIAction("reset_settings", {}) confirm:Remove() end
        local no = vgui.Create("DButton", btns2) no:Dock(RIGHT) no:DockMargin(0, 4, 4, 4) no:SetWide(60) no:SetText("Cancel")
        UI.StyleButton(no) no.DoClick = function() confirm:Remove() end
    end
end
