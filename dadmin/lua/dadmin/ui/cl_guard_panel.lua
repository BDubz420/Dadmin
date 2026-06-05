if SERVER then return end

DAdmin = DAdmin or {}
DAdmin.UI = DAdmin.UI or {}

local function truncateText(text, maxChars)
    text = tostring(text or "")
    maxChars = maxChars or 64
    if #text <= maxChars then return text end
    return string.sub(text, 1, maxChars - 3) .. "..."
end

local function sortedModules(modules)
    modules = modules or {}
    table.sort(modules, function(a, b)
        local sa = tostring(a.severity or "")
        local sb = tostring(b.severity or "")
        if sa == sb then return tostring(a.name or a.key) < tostring(b.name or b.key) end
        local order = { high = 1, medium = 2, low = 3 }
        return (order[sa] or 9) < (order[sb] or 9)
    end)
    return modules
end

function DAdmin.BuildGuardPanel(parent)
    parent:Clear()

    local UI = DAdmin.UI
    local C = UI.Colors
    local state = DAdmin.Port and DAdmin.Port.GetGuard and DAdmin.Port.GetGuard() or { config = {}, modules = {}, alerts = {}, stats = {} }
    local cfg = table.Copy(state.config or {})
    local modules = sortedModules(table.Copy(state.modules or {}))
    local alerts = state.alerts or {}
    local stats = state.stats or {}

    local shell = vgui.Create("DPanel", parent)
    shell:Dock(FILL)
    shell.Paint = nil

    local left = vgui.Create("DPanel", shell)
    left:Dock(LEFT)
    left:SetWide(340)
    left.Paint = nil

    local leftScroll = vgui.Create("DScrollPanel", left)
    leftScroll:Dock(FILL)

    local center = vgui.Create("DPanel", shell)
    center:Dock(FILL)
    center:DockMargin(6, 0, 6, 0)
    center.Paint = nil

    local right = vgui.Create("DPanel", shell)
    right:Dock(RIGHT)
    right:SetWide(250)
    right.Paint = nil

    local statusPanel, statusBody = UI.MakeSection(leftScroll, "Guard Status", TOP)
    statusPanel:SetTall(134)

    local enabledText = cfg.enabled ~= false and "ONLINE" or "DISABLED"
    local statusRows = {
        {"Status", enabledText, cfg.enabled ~= false and C.green or C.red},
        {"Total Alerts", tostring(stats.total or #alerts or 0), C.text},
        {"Today", tostring(stats.todayCount or 0), C.yellow},
        {"Stored Alerts", tostring(#alerts), C.text},
        {"Auto-ban", cfg.autoban and ("ON / " .. tostring(cfg.autoban_threshold or 95) .. "%") or "OFF", cfg.autoban and C.red or C.textDim}
    }

    for _, rowData in ipairs(statusRows) do
        local row = vgui.Create("DPanel", statusBody)
        row:Dock(TOP)
        row:SetTall(20)
        row:DockMargin(8, 2, 8, 0)
        row.Paint = function(_, w, h)
            draw.SimpleText(rowData[1], "DAdmin.Small", 0, h / 2, C.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText(rowData[2], "DAdmin.Small", w, h / 2, rowData[3], TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end
    end

    local quickPanel, quickBody = UI.MakeSection(leftScroll, "Global Settings", TOP, {0, 6, 0, 0})
    quickPanel:SetTall(170)

    local function makeToggle(parentPanel, label, key)
        local row = vgui.Create("DPanel", parentPanel)
        row:Dock(TOP)
        row:SetTall(24)
        row:DockMargin(8, 3, 8, 0)
        row.Paint = function(_, w, h)
            draw.SimpleText(label, "DAdmin.Small", 0, h / 2, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end

        local btn = vgui.Create("DButton", row)
        btn:Dock(RIGHT)
        btn:SetWide(48)
        btn:SetText(cfg[key] ~= false and "ON" or "OFF")
        UI.StyleButton(btn, cfg[key] ~= false and "primary" or nil)
        btn.DoClick = function()
            cfg[key] = not (cfg[key] ~= false)
            btn:SetText(cfg[key] and "ON" or "OFF")
            btn._variant = cfg[key] and "primary" or nil
        end
    end

    local function makeNumberRow(parentPanel, label, key, width)
        local row = vgui.Create("DPanel", parentPanel)
        row:Dock(TOP)
        row:SetTall(24)
        row:DockMargin(8, 3, 8, 0)
        row.Paint = function(_, w, h)
            draw.SimpleText(label, "DAdmin.Small", 0, h / 2, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end

        local entry = vgui.Create("DTextEntry", row)
        entry:Dock(RIGHT)
        entry:SetWide(width or 58)
        entry:SetText(tostring(cfg[key] or "0"))
        UI.StyleTextEntry(entry)
        entry.OnChange = function(self)
            cfg[key] = tonumber(self:GetValue()) or cfg[key] or 0
        end
    end

    makeToggle(quickBody, "Guard Enabled", "enabled")
    makeToggle(quickBody, "Notify Staff", "notify_staff")

    local autoRow = vgui.Create("DPanel", quickBody)
    autoRow:Dock(TOP)
    autoRow:SetTall(24)
    autoRow:DockMargin(8, 3, 8, 0)
    autoRow.Paint = function(_, w, h)
        draw.SimpleText("Auto-ban", "DAdmin.Small", 0, h / 2, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
    local autoBtn = vgui.Create("DButton", autoRow)
    autoBtn:Dock(RIGHT)
    autoBtn:SetWide(48)
    autoBtn:SetText(cfg.autoban and "ON" or "OFF")
    UI.StyleButton(autoBtn, cfg.autoban and "danger" or nil)
    autoBtn.DoClick = function()
        cfg.autoban = not cfg.autoban
        autoBtn:SetText(cfg.autoban and "ON" or "OFF")
        autoBtn._variant = cfg.autoban and "danger" or nil
    end
    makeNumberRow(quickBody, "Auto-ban threshold %", "autoban_threshold")
    makeNumberRow(quickBody, "Alert cooldown (sec)", "alert_cooldown")
    makeNumberRow(quickBody, "Stored alerts cap", "max_alerts", 72)

    local propPanel, propBody = UI.MakeSection(leftScroll, "Prop Defense", TOP, {0, 6, 0, 0})
    propPanel:SetTall(174)
    makeToggle(propBody, "Freeze existing props", "propspam_freeze_existing")
    makeToggle(propBody, "Block new props after trigger", "propspam_remove_new")
    makeToggle(propBody, "Cleanup on hard limit", "propspam_cleanup_on_limit")
    makeNumberRow(propBody, "Spam threshold", "propspam_threshold")
    makeNumberRow(propBody, "Spam window (sec)", "propspam_window")
    makeNumberRow(propBody, "Restriction time (sec)", "propspam_restrict_seconds")
    makeNumberRow(propBody, "Hard prop limit", "propspam_total_prop_limit")

    local tuningPanel, tuningBody = UI.MakeSection(leftScroll, "Detection Tuning", TOP, {0, 6, 0, 0})
    tuningPanel:SetTall(214)
    for _, rowData in ipairs({
        {"Speed threshold", "speedhack_threshold"},
        {"Spin threshold", "spinbot_threshold"},
        {"Bhop chain", "bhop_threshold"},
        {"Tool threshold", "toolspam_threshold"},
        {"Tool window", "toolspam_window"},
        {"Chat threshold", "chatspam_threshold"},
        {"Chat window", "chatspam_window"},
    }) do
        makeNumberRow(tuningBody, rowData[1], rowData[2])
    end

    local saveBtn = vgui.Create("DButton", leftScroll)
    saveBtn:Dock(TOP)
    saveBtn:DockMargin(0, 6, 0, 0)
    saveBtn:SetTall(28)
    saveBtn:SetText("Save Guard Settings")
    UI.StyleButton(saveBtn, "primary")
    saveBtn.DoClick = function()
        DAdmin.Port.UIAction("guard_config", { config = cfg })
        DAdmin.Port.Refresh()
    end

    local modulePanel, moduleBody = UI.MakeSection(center, "Detection Modules", TOP)
    modulePanel:SetTall(330)

    local moduleList = vgui.Create("DScrollPanel", moduleBody)
    moduleList:Dock(FILL)

    for _, mod in ipairs(modules) do
        local key = tostring(mod.key or "")
        local row = moduleList:Add("DPanel")
        row:Dock(TOP)
        row:SetTall(50)
        row:DockMargin(6, 4, 6, 0)
        row.Paint = function(_, w, h)
            surface.SetDrawColor(C.bg2)
            surface.DrawRect(0, 0, w, h)
            surface.SetDrawColor(C.border)
            surface.DrawOutlinedRect(0, 0, w, h, 1)

            local sev = tostring(mod.severity or "medium")
            local sc = sev == "high" and C.red or (sev == "medium" and C.yellow or C.textDim)
            local extra = mod.window and mod.window > 0 and (" | " .. tostring(mod.window) .. "s") or ""
            draw.SimpleText(truncateText(mod.name or key, 36), "DAdmin.Normal", 10, 13, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText(string.upper(sev), "DAdmin.Small", w - 78, 13, sc, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
            draw.SimpleText(truncateText((mod.description or "") .. extra, math.max(24, math.floor((w - 105) / 7))), "DAdmin.Small", 10, 34, C.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText("T:" .. tostring(mod.threshold or "-") .. " | " .. tostring(mod.count or 0), "DAdmin.Small", w - 78, 34, C.textDim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end

        local toggle = vgui.Create("DButton", row)
        toggle:Dock(RIGHT)
        toggle:DockMargin(0, 10, 8, 10)
        toggle:SetWide(54)
        local current = cfg[key] ~= false
        toggle:SetText(current and "ON" or "OFF")
        UI.StyleButton(toggle, current and "primary" or nil)
        toggle.DoClick = function()
            cfg[key] = not (cfg[key] ~= false)
            toggle:SetText(cfg[key] and "ON" or "OFF")
            toggle._variant = cfg[key] and "primary" or nil
        end
    end

    local feedPanel, feedBody = UI.MakeSection(center, "Detection Feed", FILL, {0, 6, 0, 0})
    local feedList = vgui.Create("DScrollPanel", feedBody)
    feedList:Dock(FILL)

    if #alerts == 0 then
        local empty = vgui.Create("DLabel", feedList)
        empty:Dock(TOP)
        empty:DockMargin(10, 10, 10, 0)
        empty:SetFont("DAdmin.Normal")
        empty:SetTextColor(C.textDim)
        empty:SetText("No Guard alerts have been recorded.")
    end

    local detailPanel, detailBody = UI.MakeSection(right, "Alert Details", FILL)
    local selected

    local function drawDetails(alert)
        detailBody:Clear()

        if not alert then
            local lbl = vgui.Create("DLabel", detailBody)
            lbl:Dock(TOP)
            lbl:DockMargin(8, 8, 8, 0)
            lbl:SetFont("DAdmin.Normal")
            lbl:SetTextColor(C.textDim)
            lbl:SetWrap(true)
            lbl:SetAutoStretchVertical(true)
            lbl:SetText("Select an alert to view details.")
            return
        end

        for _, pair in ipairs({
            {"Player", alert.playerName or "Unknown"},
            {"SteamID", alert.steamid or "N/A"},
            {"Type", alert.title or alert.type or "Unknown"},
            {"Severity", alert.severity or "medium"},
            {"Confidence", tostring(alert.confidence or 0) .. "%"},
            {"Time", tostring(alert.date or "") .. " " .. tostring(alert.time or "")}
        }) do
            local row = vgui.Create("DPanel", detailBody)
            row:Dock(TOP)
            row:SetTall(20)
            row:DockMargin(8, 2, 8, 0)
            row.Paint = function(_, w, h)
                draw.SimpleText(pair[1], "DAdmin.Small", 0, h / 2, C.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                draw.SimpleText(truncateText(pair[2], 24), "DAdmin.Small", w, h / 2, C.text, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
            end
        end

        local desc = vgui.Create("DLabel", detailBody)
        desc:Dock(TOP)
        desc:DockMargin(8, 8, 8, 0)
        desc:SetFont("DAdmin.Small")
        desc:SetTextColor(C.text)
        desc:SetWrap(true)
        desc:SetAutoStretchVertical(true)
        desc:SetText(alert.details or "No details.")

        local dismiss = vgui.Create("DButton", detailBody)
        dismiss:Dock(TOP)
        dismiss:DockMargin(8, 10, 8, 0)
        dismiss:SetTall(26)
        dismiss:SetText("Dismiss Alert")
        UI.StyleButton(dismiss, "danger")
        dismiss.DoClick = function()
            DAdmin.Port.UIAction("guard_dismiss", { alertID = alert.id })
            DAdmin.Port.Refresh()
        end
    end

    for _, alert in ipairs(alerts) do
        local row = feedList:Add("DPanel")
        row:Dock(TOP)
        row:SetTall(44)
        row:DockMargin(6, 4, 6, 0)
        row:SetCursor("hand")
        row.Paint = function(_, w, h)
            local active = selected and selected.id == alert.id
            surface.SetDrawColor(active and C.select or C.bg2)
            surface.DrawRect(0, 0, w, h)
            surface.SetDrawColor(C.border)
            surface.DrawOutlinedRect(0, 0, w, h, 1)

            local sev = tostring(alert.severity or "medium")
            local sc = sev == "high" and C.red or (sev == "medium" and C.yellow or C.textDim)
            draw.SimpleText(truncateText(alert.title or alert.type or "Alert", 38), "DAdmin.Normal", 10, 12, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText(tostring(alert.confidence or 0) .. "%", "DAdmin.Small", w - 10, 12, sc, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
            draw.SimpleText(truncateText((alert.playerName or "Unknown") .. " - " .. (alert.details or ""), math.max(30, math.floor((w - 20) / 7))), "DAdmin.Small", 10, 31, C.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
        row.OnMousePressed = function()
            selected = alert
            drawDetails(alert)
        end
    end

    drawDetails(nil)
end
