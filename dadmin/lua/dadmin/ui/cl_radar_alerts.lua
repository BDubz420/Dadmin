if SERVER then return end

DAdmin = DAdmin or {}
DAdmin.UI = DAdmin.UI or {}
DAdmin.RadarAlerts = DAdmin.RadarAlerts or {}

local UI = DAdmin.UI
local alerts = DAdmin.RadarAlerts

function DAdmin.BuildRadarAlertsPanel(parent)
    parent:Clear()
    local C = UI.Colors
    local feed = alerts.feed or {}

    local shell = vgui.Create("DPanel", parent)
    shell:Dock(FILL)
    shell.Paint = nil

    local left = vgui.Create("DPanel", shell)
    left:Dock(LEFT)
    left:SetWide(210)
    left.Paint = nil

    local center = vgui.Create("DPanel", shell)
    center:Dock(FILL)
    center:DockMargin(5, 0, 5, 0)
    center.Paint = nil

    local right = vgui.Create("DPanel", shell)
    right:Dock(RIGHT)
    right:SetWide(200)
    right.Paint = nil

    local cfgSection, cfgBody = UI.MakeSection(left, "Alert Config", FILL)

    local alertTypes = {
        { label = "Aimbot", key = "aimbot", severity = "high" },
        { label = "Speedhack", key = "speedhack", severity = "high" },
        { label = "ESP / Wallhack", key = "esp", severity = "medium" },
        { label = "Noclip Abuse", key = "noclip_abuse", severity = "medium" },
        { label = "Spinbot", key = "spinbot", severity = "high" },
        { label = "Bhop Hack", key = "bhop", severity = "low" },
        { label = "Prop Spam", key = "propspam", severity = "medium" },
        { label = "Crash Attempt", key = "crash", severity = "high" },
        { label = "Lua Exploit", key = "lua_exploit", severity = "high" },
    }

    alerts.config = alerts.config or {}
    for _, at in ipairs(alertTypes) do
        alerts.config[at.key] = alerts.config[at.key] ~= false
    end

    local sevColors = { high = C.red, medium = C.yellow, low = C.textDim }

    for _, at in ipairs(alertTypes) do
        local row = vgui.Create("DPanel", cfgBody)
        row:Dock(TOP)
        row:SetTall(24)
        row:DockMargin(6, 3, 6, 0)
        row.Paint = function(_, w, h)
            draw.SimpleText(at.label, "DAdmin.Small", 0, h / 2, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            local sc = sevColors[at.severity] or C.text
            draw.SimpleText(at.severity, "DAdmin.Small", w - 50, h / 2, sc, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end

        local toggle = vgui.Create("DButton", row)
        toggle:Dock(RIGHT)
        toggle:SetWide(36)
        toggle:SetText(alerts.config[at.key] and "ON" or "OFF")
        UI.StyleButton(toggle, alerts.config[at.key] and "primary" or nil)
        toggle.DoClick = function()
            alerts.config[at.key] = not alerts.config[at.key]
            toggle:SetText(alerts.config[at.key] and "ON" or "OFF")
            toggle._variant = alerts.config[at.key] and "primary" or nil
        end
    end

    local saveBtn = vgui.Create("DButton", cfgBody)
    saveBtn:Dock(BOTTOM)
    saveBtn:DockMargin(6, 0, 6, 6)
    saveBtn:SetTall(22)
    saveBtn:SetText("Save Config")
    UI.StyleButton(saveBtn, "primary")
    saveBtn.DoClick = function()
        DAdmin.Port.UIAction("guard_config", { config = alerts.config })
    end

    local feedSection, feedBody = UI.MakeSection(center, "Live Detection Feed (" .. tostring(#feed) .. ")", FILL)
    local feedList = vgui.Create("DScrollPanel", feedBody)
    feedList:Dock(FILL)

    local selected

    if #feed == 0 then
        local lbl = vgui.Create("DLabel", feedBody)
        lbl:Dock(TOP)
        lbl:DockMargin(10, 10, 10, 0)
        lbl:SetFont("DAdmin.Normal")
        lbl:SetTextColor(C.textDark)
        lbl:SetText("No detections recorded yet.")
    end

    local function showDetail(alert)
        right:Clear()
        local detailSection, detailBody = UI.MakeSection(right, "Alert Detail", FILL)

        if not alert then
            local lbl = vgui.Create("DLabel", detailBody)
            lbl:Dock(TOP)
            lbl:DockMargin(10, 10, 10, 0)
            lbl:SetFont("DAdmin.Normal")
            lbl:SetTextColor(C.textDark)
            lbl:SetText("Select an alert to view details.")
            return
        end

        for _, pair in ipairs({
            {"Player", alert.playerName or "Unknown"},
            {"SteamID", alert.steamid or "N/A"},
            {"Type", alert.type or "Unknown"},
            {"Severity", alert.severity or "Unknown"},
            {"Time", alert.time or "Unknown"},
            {"Confidence", tostring(alert.confidence or 0) .. "%"},
        }) do
            local row = vgui.Create("DPanel", detailBody)
            row:Dock(TOP)
            row:DockMargin(6, 2, 6, 0)
            row:SetTall(18)
            row.Paint = function(_, w, h)
                draw.SimpleText(pair[1], "DAdmin.Small", 0, h / 2, C.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                draw.SimpleText(pair[2], "DAdmin.Small", w, h / 2, C.text, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
            end
        end

        if alert.details then
            local desc = vgui.Create("DLabel", detailBody)
            desc:Dock(TOP)
            desc:DockMargin(6, 8, 6, 0)
            desc:SetTall(60)
            desc:SetWrap(true)
            desc:SetFont("DAdmin.Normal")
            desc:SetTextColor(C.text)
            desc:SetText(alert.details)
        end

        local function actionBtn(txt, variant, fn)
            local b = vgui.Create("DButton", detailBody)
            b:Dock(TOP)
            b:DockMargin(6, 4, 6, 0)
            b:SetTall(22)
            b:SetText(txt)
            UI.StyleButton(b, variant)
            b.DoClick = fn
        end

        actionBtn("Goto Player", nil, function()
            if alert.steamid then
                DAdmin.Port.UIAction("command", { command = "goto", args = { alert.steamid } })
            end
        end)
        actionBtn("Spectate Player", nil, function()
            if alert.steamid then
                DAdmin.Port.UIAction("command", { command = "spectate", args = { alert.steamid } })
            end
        end)
        actionBtn("Ban Player", "danger", function()
            if alert.steamid then
                DAdmin.Port.UIAction("command", { command = "ban", args = { alert.steamid, "0", "Anti-cheat: " .. (alert.type or "detection") } })
            end
        end)
        actionBtn("Dismiss Alert", nil, function()
            DAdmin.Port.UIAction("guard_dismiss", { alertID = alert.id })
            DAdmin.BuildRadarAlertsPanel(parent)
        end)
    end

    for i, alert in ipairs(feed) do
        local row = feedList:Add("DButton")
        row:Dock(TOP)
        row:DockMargin(0, 0, 0, 2)
        row:SetTall(30)
        row:SetText("")
        local sc = sevColors[alert.severity] or C.text
        row.Paint = function(self, w, h)
            surface.SetDrawColor(selected == alert and C.select or (self:IsHovered() and Color(24, 28, 40) or C.bg2))
            surface.DrawRect(0, 0, w, h)
            surface.SetDrawColor(C.borderDark)
            surface.DrawLine(0, h - 1, w, h - 1)
            draw.SimpleText(alert.time or "", "DAdmin.Small", 6, h / 2, C.textDark, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText(alert.playerName or "?", "DAdmin.Small", 60, h / 2, C.blue, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText(alert.type or "?", "DAdmin.Title", 170, h / 2, sc, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText(tostring(alert.confidence or 0) .. "%", "DAdmin.Small", w - 6, h / 2, sc, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end
        row.DoClick = function()
            selected = alert
            showDetail(alert)
        end
    end

    showDetail(nil)
end

net.Receive("DAdmin_RequestRadarAlerts", function()
    DAdmin.RadarAlerts.feed = net.ReadTable() or {}
    if DAdmin.CurrentTab == "guard" then
        DAdmin.RefreshCurrentTab()
    end
end)
