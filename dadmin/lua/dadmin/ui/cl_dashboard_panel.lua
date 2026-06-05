if SERVER then return end
local UI = DAdmin.UI
local C = UI.Colors

local function countWhere(list, fn)
    local total = 0
    for _, item in ipairs(list or {}) do
        if fn(item) then total = total + 1 end
    end
    return total
end

local function quickButton(parent, text, variant, fn)
    local b = vgui.Create("DButton", parent)
    b:Dock(TOP)
    b:DockMargin(0, 4, 0, 0)
    b:SetTall(24)
    b:SetText(text)
    UI.StyleButton(b, variant)
    b.DoClick = fn
    return b
end

local function actionColor(action)
    local map = {
        kick = C.yellow,
        warn = C.yellow,
        ban = C.red,
        mute = C.yellow,
        gag = C.yellow,
        setrank = C.blue,
        screengrab = C.purple,
        report_created = C.yellow,
        report_resolved = C.green,
        case_closed = C.green
    }
    return map[tostring(action or "")] or C.text
end

function DAdmin.BuildDashboardPanel(parent)
    parent:Clear()

    local state = DAdmin.Port.GetState()
    local reports = DAdmin.Port.GetReports()
    local players = DAdmin.Port.GetPlayers()
    local logs = DAdmin.Port.GetRecentActions()
    local alerts = (DAdmin.Port.GetGuard() or {}).alerts or {}
    local activeSits = DAdmin.Port.GetActiveSits() or {}
    local staff = (DAdmin.Port.GetStaffControl() or {}).active or {}

    local openReports = countWhere(reports, function(r) return tostring(r.status or "open") == "open" end)
    local claimedReports = countWhere(reports, function(r) return tostring(r.status or "") == "claimed" end)
    local highAlerts = countWhere(alerts, function(a)
        local sev = string.lower(tostring(a.severity or ""))
        return sev == "high" or sev == "critical"
    end)
    local activeSitCount = countWhere(activeSits, function(s) return tostring(s.status or "active") == "active" end)

    local shell = vgui.Create("DPanel", parent)
    shell:Dock(FILL)
    shell.Paint = nil

    local top = vgui.Create("DPanel", shell)
    top:Dock(TOP)
    top:SetTall(88)
    top.Paint = nil

    local cards = {
        { title = "Open Reports", value = openReports, subtitle = claimedReports .. " claimed", color = C.yellow, tab = "reports" },
        { title = "Guard Alerts", value = #alerts, subtitle = highAlerts .. " high severity", color = C.red, tab = "guard" },
        { title = "Active Sits", value = activeSitCount, subtitle = #reports .. " total reports", color = C.blue, tab = "reports" },
        { title = "Online Staff", value = #staff, subtitle = #players .. " players online", color = C.green, tab = "control" },
    }

    for _, card in ipairs(cards) do
        local pnl = vgui.Create("DButton", top)
        pnl:Dock(LEFT)
        pnl:DockMargin(0, 0, 6, 0)
        pnl:SetWide(185)
        pnl:SetText("")
        pnl.Paint = function(_, w, h)
            UI.PaintInfoCard(nil, w, h, card.color, card.title, card.value, card.subtitle)
        end
        pnl.DoClick = function()
            if card.tab then DAdmin.SwitchTab(card.tab) end
        end
    end

    local left = vgui.Create("DPanel", shell)
    left:Dock(LEFT)
    left:SetWide(270)
    left:DockMargin(0, 6, 6, 0)
    left.Paint = nil

    local center = vgui.Create("DPanel", shell)
    center:Dock(FILL)
    center:DockMargin(0, 6, 0, 0)
    center.Paint = nil

    local right = vgui.Create("DPanel", shell)
    right:Dock(RIGHT)
    right:SetWide(255)
    right:DockMargin(6, 6, 0, 0)
    right.Paint = nil

    local queuePanel, queueBody = UI.MakeSection(left, "Needs Attention", TOP)
    queuePanel:SetTall(258)

    local queue = vgui.Create("DScrollPanel", queueBody)
    queue:Dock(FILL)

    local function queueRow(text, detail, accent, clickTab)
        local row = vgui.Create("DButton", queue)
        row:Dock(TOP)
        row:DockMargin(0, 0, 0, 3)
        row:SetTall(38)
        row:SetText("")
        row.Paint = function(_, w, h)
            surface.SetDrawColor(C.bg2)
            surface.DrawRect(0, 0, w, h)
            surface.SetDrawColor(C.border)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
            surface.SetDrawColor(accent.r, accent.g, accent.b, 200)
            surface.DrawRect(0, 0, 4, h)
            draw.SimpleText(text, "DAdmin.Small", 10, 12, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText(detail, "DAdmin.Tiny", 10, 27, C.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
        row.DoClick = function()
            if clickTab then DAdmin.SwitchTab(clickTab) end
        end
    end

    if openReports > 0 then
        queueRow("Open reports need a handler", openReports .. " currently unclaimed or unresolved", C.yellow, "reports")
    end
    if activeSitCount > 0 then
        queueRow("Active sits in progress", activeSitCount .. " active moderation sessions", C.blue, "reports")
    end
    if highAlerts > 0 then
        queueRow("High-severity guard alerts", highAlerts .. " worth reviewing now", C.red, "guard")
    end
    if #staff == 0 then
        queueRow("No staff currently active", "You may be the only staff member online", C.textDim, "control")
    elseif #queue:GetCanvas():GetChildren() == 0 then
        queueRow("No urgent moderation backlog", "The server looks quiet right now", C.green, "logs")
    end

    local quickPanel, quickBody = UI.MakeSection(left, "Quick Actions", FILL, {0, 6, 0, 0})
    quickButton(quickBody, "Open Player Manager", "primary", function() DAdmin.SwitchTab("players") end)
    quickButton(quickBody, "Open Reports Queue", nil, function() DAdmin.SwitchTab("reports") end)
    quickButton(quickBody, "Open Guard", nil, function() DAdmin.SwitchTab("guard") end)
    quickButton(quickBody, "Open Command Palette", nil, function() DAdmin.OpenCommandPalette() end)
    quickButton(quickBody, "View Logs", nil, function() DAdmin.SwitchTab("logs") end)
    quickButton(quickBody, "Refresh Dashboard", nil, function() DAdmin.Port.Refresh() end)

    local actionsPanel, actionsBody = UI.MakeSection(center, "Recent Actions", FILL)
    local actionHeader = vgui.Create("DPanel", actionsBody)
    actionHeader:Dock(TOP)
    actionHeader:SetTall(22)
    actionHeader.Paint = function(_, w, h)
        surface.SetDrawColor(26, 29, 38, 255)
        surface.DrawRect(0, 0, w, h)
        draw.SimpleText("Admin", "DAdmin.Small", 8, h / 2, C.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Action", "DAdmin.Small", w * 0.21, h / 2, C.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Target", "DAdmin.Small", w * 0.38, h / 2, C.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Reason", "DAdmin.Small", w * 0.55, h / 2, C.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Time", "DAdmin.Small", w - 10, h / 2, C.textDim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end

    local actionList = vgui.Create("DScrollPanel", actionsBody)
    actionList:Dock(FILL)
    for i, a in ipairs(logs or {}) do
        local row = actionList:Add("DPanel")
        row:Dock(TOP)
        row:SetTall(26)
        row.Paint = function(_, w, h)
            surface.SetDrawColor((i % 2 == 0) and Color(20, 22, 30) or C.bg2)
            surface.DrawRect(0, 0, w, h)
            draw.SimpleText(a.admin or "-", "DAdmin.Small", 8, h / 2, C.blue, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText(a.action or "-", "DAdmin.Small", w * 0.21, h / 2, actionColor(a.action), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText(a.target or "-", "DAdmin.Small", w * 0.38, h / 2, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText(tostring(a.reason or ""):sub(1, 44), "DAdmin.Small", w * 0.55, h / 2, C.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText(a.time or "-", "DAdmin.Small", w - 10, h / 2, C.textDark, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end
    end

    local staffPanel, staffBody = UI.MakeSection(right, "Staff Online", TOP)
    staffPanel:SetTall(190)
    local staffList = vgui.Create("DScrollPanel", staffBody)
    staffList:Dock(FILL)
    if #staff == 0 then
        local lbl = vgui.Create("DLabel", staffList)
        lbl:Dock(TOP)
        lbl:DockMargin(8, 10, 8, 0)
        lbl:SetFont("DAdmin.Small")
        lbl:SetTextColor(C.textDark)
        lbl:SetText("No active staff tracked right now.")
    else
        for _, member in ipairs(staff) do
            local row = vgui.Create("DPanel", staffList)
            row:Dock(TOP)
            row:DockMargin(0, 0, 0, 3)
            row:SetTall(28)
            row.Paint = function(_, w, h)
                surface.SetDrawColor(C.bg2)
                surface.DrawRect(0, 0, w, h)
                surface.SetDrawColor(C.border)
                surface.DrawOutlinedRect(0, 0, w, h, 1)
                draw.SimpleText(tostring(member.name or member.steamid), "DAdmin.Small", 8, h / 2, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                draw.SimpleText(tostring(member.rank or ""), "DAdmin.Small", w - 8, h / 2, C.blue, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
            end
        end
    end

    local playersPanel, playersBody = UI.MakeSection(right, "Players Online", FILL, {0, 6, 0, 0})
    local playerList = vgui.Create("DScrollPanel", playersBody)
    playerList:Dock(FILL)
    for _, p in ipairs(players or {}) do
        local row = vgui.Create("DButton", playerList)
        row:Dock(TOP)
        row:DockMargin(0, 0, 0, 3)
        row:SetTall(26)
        row:SetText("")
        row.Paint = function(_, w, h)
            surface.SetDrawColor(C.bg2)
            surface.DrawRect(0, 0, w, h)
            surface.SetDrawColor(C.border)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
            draw.SimpleText(tostring(p.name or "-"), "DAdmin.Small", 8, h / 2, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText(tostring(p.rank or "User"), "DAdmin.Small", w - 8, h / 2, p.rankColor or C.textDim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end
        row.DoClick = function()
            DAdmin._selectedPlayerId = p.steamid
            DAdmin.SwitchTab("players")
        end
    end
end
