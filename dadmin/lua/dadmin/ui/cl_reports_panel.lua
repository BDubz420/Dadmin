if SERVER then return end
local UI = DAdmin.UI
local C = UI.Colors

function DAdmin.BuildReportsPanel(parent)
    parent:Clear()
    local reports = DAdmin.Port.GetReports()
    local selected = nil
    local actionLog = {}
    local filterMode = "all"
    local filterQuery = ""
    local rebuildList, rebuildDetail

    local shell = vgui.Create("DPanel", parent) shell:Dock(FILL) shell.Paint = nil

    -- Right side: detail + quick actions (scrollable)
    local rightOuter = vgui.Create("DPanel", shell) rightOuter:Dock(RIGHT) rightOuter:SetWide(240) rightOuter.Paint = nil
    local rightScroll = vgui.Create("DScrollPanel", rightOuter) rightScroll:Dock(FILL)

    -- Left side: filter bar + report list + activity log
    local left = vgui.Create("DPanel", shell) left:Dock(FILL) left:DockMargin(0, 0, 5, 0) left.Paint = nil

    -- Filter bar
    local filterBar = vgui.Create("DPanel", left) filterBar:Dock(TOP) filterBar:SetTall(54) filterBar.Paint = nil
    local filters = {"all", "open", "claimed", "resolved", "dismissed"}
    local filterButtons = {}
    local search = vgui.Create("DTextEntry", filterBar)
    search:Dock(TOP)
    search:SetTall(24)
    search:SetPlaceholderText("Search reporter, target, reason, or report id...")
    UI.StyleTextEntry(search)
    local filterRow = vgui.Create("DPanel", filterBar) filterRow:Dock(TOP) filterRow:SetTall(26) filterRow.Paint = nil

    -- Count open reports
    local openCount = 0
    for _, r in ipairs(reports) do if r.status == "open" then openCount = openCount + 1 end end

    -- Report list
    local listSection, listBody = UI.MakeSection(left, "Reports (" .. tostring(openCount) .. " open)", FILL, {0, 3, 0, 0})
    local list = vgui.Create("DScrollPanel", listBody) list:Dock(FILL)

    -- Activity log at bottom
    local logPanel, logBody = UI.MakeSection(left, "Activity Log", BOTTOM, {0, 5, 0, 0}) logPanel:SetTall(70)
    local logList = vgui.Create("DScrollPanel", logBody) logList:Dock(FILL)

    local function addLog(msg, clr)
        actionLog[#actionLog + 1] = { text = "[" .. os.date("%H:%M:%S") .. "] " .. msg, clr = clr or C.green }
        if not IsValid(logList) then return end
        logList:Clear()
        for i = #actionLog, math.max(1, #actionLog - 30), -1 do
            local line = vgui.Create("DLabel", logList) line:Dock(TOP) line:SetTall(16) line:SetFont("DAdmin.Small")
            line:SetTextColor(actionLog[i].clr) line:SetText(actionLog[i].text) logList:AddItem(line)
        end
    end

    rebuildDetail = function()
        if not IsValid(rightScroll) then return end
        rightScroll:Clear()

        if not selected then
            local lbl = vgui.Create("DLabel", rightScroll) lbl:Dock(TOP) lbl:DockMargin(10, 20, 10, 0)
            lbl:SetFont("DAdmin.Normal") lbl:SetTextColor(C.textDark) lbl:SetWrap(true) lbl:SetAutoStretchVertical(true)
            lbl:SetText("Select a report to view details and take action.")
            rightScroll:AddItem(lbl)
            return
        end

        -- Report Detail header
        local hdr = vgui.Create("DPanel", rightScroll) hdr:Dock(TOP) hdr:SetTall(22)
        hdr.Paint = function(_, w, h) UI.PaintHeader(w, h, "Report Detail") end
        rightScroll:AddItem(hdr)

        -- Detail rows
        local statusColors = { open = C.yellow, claimed = C.blue, resolved = C.green, dismissed = C.red }
        local priColors = { high = C.red, medium = C.yellow, low = C.textDim }
        for _, pair in ipairs({
            {"ID", "#" .. tostring(selected.id)},
            {"Reporter", tostring(selected.reporter or selected.reporterName or "-")},
            {"Target", tostring(selected.target or selected.targetName or "-")},
            {"Priority", tostring(selected.priority or "medium")},
            {"Status", tostring(selected.status or "open")},
            {"Time", tostring(selected.time or "-")},
        }) do
            local row = vgui.Create("DPanel", rightScroll) row:Dock(TOP) row:SetTall(18) row:DockMargin(8, 0, 8, 0)
            row.Paint = function(_, w, h)
                draw.SimpleText(pair[1], "DAdmin.Small", 0, h / 2, C.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                local textC = C.text
                if pair[1] == "Priority" then textC = priColors[selected.priority] or C.yellow end
                if pair[1] == "Status" then textC = statusColors[selected.status] or C.text end
                draw.SimpleText(pair[2], "DAdmin.Small", w, h / 2, textC, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
            end
            rightScroll:AddItem(row)
        end

        -- Reason
        if selected.reason and selected.reason ~= "" then
            local reasonLabel = vgui.Create("DLabel", rightScroll) reasonLabel:Dock(TOP) reasonLabel:DockMargin(8, 8, 8, 0)
            reasonLabel:SetFont("DAdmin.Small") reasonLabel:SetTextColor(C.textDim) reasonLabel:SetText("Reason:")
            rightScroll:AddItem(reasonLabel)
            local reason = vgui.Create("DLabel", rightScroll) reason:Dock(TOP) reason:DockMargin(8, 2, 8, 0)
            reason:SetFont("DAdmin.Normal") reason:SetTextColor(C.text) reason:SetWrap(true) reason:SetAutoStretchVertical(true)
            reason:SetText(selected.reason)
            rightScroll:AddItem(reason)
        end

        -- Claimed by info
        if selected.claimedBy then
            local c = vgui.Create("DLabel", rightScroll) c:Dock(TOP) c:DockMargin(8, 6, 8, 0)
            c:SetFont("DAdmin.Small") c:SetTextColor(C.blue) c:SetText("Claimed by: " .. tostring(selected.claimedBy))
            rightScroll:AddItem(c)
        end

        -- Admin notes
        local note = vgui.Create("DTextEntry", rightScroll)
        note:Dock(TOP) note:DockMargin(8, 8, 8, 0) note:SetTall(40) note:SetMultiline(true) note:SetPlaceholderText("Admin notes...") UI.StyleTextEntry(note)
        rightScroll:AddItem(note)

        -- Quick Actions header
        local actHdr = vgui.Create("DPanel", rightScroll) actHdr:Dock(TOP) actHdr:SetTall(22) actHdr:DockMargin(0, 6, 0, 0)
        actHdr.Paint = function(_, w, h) UI.PaintHeader(w, h, "Quick Actions") end
        rightScroll:AddItem(actHdr)

        local function actionBtn(txt, variant, fn)
            local b = vgui.Create("DButton", rightScroll) b:Dock(TOP) b:DockMargin(8, 3, 8, 0) b:SetTall(22) b:SetText(txt) UI.StyleButton(b, variant) b.DoClick = fn
            rightScroll:AddItem(b)
            return b
        end

        -- Status management: keep the full report workflow inside this tab.
        local statusHdr = vgui.Create("DPanel", rightScroll)
        statusHdr:Dock(TOP)
        statusHdr:SetTall(16)
        statusHdr:DockMargin(0, 4, 0, 0)
        statusHdr.Paint = function(_, w, h)
            draw.SimpleText("STATUS MANAGEMENT", "DAdmin.Small", 8, h / 2, C.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
        rightScroll:AddItem(statusHdr)

        if selected.status ~= "claimed" then
            actionBtn("Claim Report", "primary", function()
                DAdmin.Port.UIAction("report_claim", { id = selected.id })
                addLog("Claimed report #" .. tostring(selected.id), C.blue)
                selected.status = "claimed"
                rebuildDetail()
                rebuildList()
            end)
        else
            actionBtn("Unclaim / Reopen", nil, function()
                DAdmin.Port.UIAction("report_reopen", { id = selected.id })
                addLog("Reopened report #" .. tostring(selected.id), C.yellow)
                selected.status = "open"
                selected.claimedBy = nil
                rebuildDetail()
                rebuildList()
            end)
        end

        if selected.status ~= "open" then
            actionBtn("Set Open", nil, function()
                DAdmin.Port.UIAction("report_reopen", { id = selected.id })
                addLog("Set report #" .. tostring(selected.id) .. " to open", C.yellow)
                selected.status = "open"
                rebuildDetail()
                rebuildList()
            end)
        end

        if selected.status ~= "resolved" then
            actionBtn("Mark Resolved", "primary", function()
                DAdmin.Port.UIAction("report_resolve", { id = selected.id, resolution = note:GetValue() ~= "" and note:GetValue() or "Resolved" })
                addLog("Resolved report #" .. tostring(selected.id), C.green)
                selected.status = "resolved"
                rebuildDetail()
                rebuildList()
            end)
        end

        if selected.status ~= "dismissed" then
            actionBtn("Dismiss Report", "danger", function()
                Derma_Query(
                    "Dismiss report #" .. tostring(selected.id) .. "?",
                    "Confirm Dismiss",
                    "Dismiss", function()
                        DAdmin.Port.UIAction("report_dismiss", { id = selected.id, reason = note:GetValue() ~= "" and note:GetValue() or "Dismissed" })
                        addLog("Dismissed report #" .. tostring(selected.id), C.red)
                        selected.status = "dismissed"
                        rebuildDetail()
                        rebuildList()
                    end,
                    "Cancel"
                )
            end)
        end

        local priorityHdr = vgui.Create("DPanel", rightScroll)
        priorityHdr:Dock(TOP)
        priorityHdr:SetTall(16)
        priorityHdr:DockMargin(0, 6, 0, 0)
        priorityHdr.Paint = function(_, w, h)
            draw.SimpleText("PRIORITY", "DAdmin.Small", 8, h / 2, C.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
        rightScroll:AddItem(priorityHdr)

        local priRow = vgui.Create("DPanel", rightScroll)
        priRow:Dock(TOP)
        priRow:DockMargin(8, 2, 8, 0)
        priRow:SetTall(22)
        priRow.Paint = nil
        rightScroll:AddItem(priRow)

        for _, pri in ipairs({"low", "medium", "high"}) do
            local pb = vgui.Create("DButton", priRow)
            pb:Dock(LEFT)
            pb:DockMargin(0, 0, 4, 0)
            pb:SetWide(66)
            pb:SetText(pri)
            UI.StyleButton(pb, selected.priority == pri and "active" or nil)
            pb.DoClick = function()
                selected.priority = pri
                DAdmin.Port.UIAction("report_priority", { id = selected.id, priority = pri })
                addLog("Set report #" .. tostring(selected.id) .. " priority to " .. pri, C.blue)
                rebuildDetail()
                rebuildList()
            end
        end

        -- Admin quick action separator
        local adminLabel = vgui.Create("DPanel", rightScroll) adminLabel:Dock(TOP) adminLabel:SetTall(16) adminLabel:DockMargin(0, 6, 0, 0)
        adminLabel.Paint = function(_, w, h) draw.SimpleText("ADMIN ACTIONS", "DAdmin.Small", 8, h/2, C.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER) end
        rightScroll:AddItem(adminLabel)

        actionBtn("Goto Reporter", nil, function()
            local name = selected.reporter or selected.reporterName or ""
            DAdmin.Port.UIAction("command", { command = "goto", args = { name } })
            addLog("Went to reporter: " .. name)
        end)
        actionBtn("Goto Target", nil, function()
            local name = selected.target or selected.targetName or ""
            DAdmin.Port.UIAction("command", { command = "goto", args = { name } })
            addLog("Went to target: " .. name)
        end)
        actionBtn("Bring Both Players", nil, function()
            local reporter = selected.reporter or selected.reporterName or ""
            local target = selected.target or selected.targetName or ""
            DAdmin.Port.UIAction("command", { command = "bring", args = { reporter } })
            DAdmin.Port.UIAction("command", { command = "bring", args = { target } })
            addLog("Brought " .. reporter .. " and " .. target)
        end)
        actionBtn("Start Sit", "primary", function()
            DAdmin.Port.UIAction("report_startsit", { id = selected.id })
            addLog("Started sit for report #" .. tostring(selected.id), C.blue)
        end)

        -- Punish target actions
        local punishLabel = vgui.Create("DPanel", rightScroll) punishLabel:Dock(TOP) punishLabel:SetTall(16) punishLabel:DockMargin(0, 6, 0, 0)
        punishLabel.Paint = function(_, w, h) draw.SimpleText("PUNISH TARGET", "DAdmin.Small", 8, h/2, C.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER) end
        rightScroll:AddItem(punishLabel)

        actionBtn("Warn Target", "primary", function()
            local target = selected.target or selected.targetName or ""
            local reason = selected.reason or "Report violation"
            DAdmin.Port.UIAction("command", { command = "warn", args = { target, reason } })
            addLog("Warned " .. target .. ": " .. reason, C.yellow)
        end)
        actionBtn("Kick Target", "danger", function()
            local target = selected.target or selected.targetName or ""
            local reason = selected.reason or "Report violation"
            DAdmin.Port.UIAction("command", { command = "kick", args = { target, reason } })
            addLog("Kicked " .. target, C.red)
        end)
        actionBtn("Ban Target", "danger", function()
            local target = selected.target or selected.targetName or ""
            local reason = selected.reason or "Report violation"
            -- Show a prompt for ban duration
            local fr = vgui.Create("EditablePanel")
            fr:SetSize(300, 100) fr:Center() fr:MakePopup()
            fr.Paint = function(_, w, h) UI.PaintPanel(w, h) end
            local hdr2 = vgui.Create("DPanel", fr) hdr2:Dock(TOP) hdr2:SetTall(22)
            hdr2.Paint = function(_, w, h) UI.PaintHeader(w, h, "Ban " .. target) end
            local durRow = vgui.Create("DPanel", fr) durRow:Dock(TOP) durRow:SetTall(28) durRow:DockMargin(8, 4, 8, 0) durRow.Paint = nil
            local durLabel = vgui.Create("DLabel", durRow) durLabel:Dock(LEFT) durLabel:SetWide(70) durLabel:SetFont("DAdmin.Small") durLabel:SetTextColor(C.textDim) durLabel:SetText("Duration")
            local durEntry = vgui.Create("DTextEntry", durRow) durEntry:Dock(FILL) durEntry:SetTall(22) durEntry:SetPlaceholderText("1h, 1d, 7d, perm...") UI.StyleTextEntry(durEntry) durEntry:RequestFocus()
            local btns = vgui.Create("DPanel", fr) btns:Dock(BOTTOM) btns:SetTall(28) btns.Paint = nil
            local ok = vgui.Create("DButton", btns) ok:Dock(RIGHT) ok:DockMargin(0, 3, 8, 3) ok:SetWide(80) ok:SetText("Ban") UI.StyleButton(ok, "danger")
            local cancel = vgui.Create("DButton", btns) cancel:Dock(RIGHT) cancel:DockMargin(0, 3, 4, 3) cancel:SetWide(80) cancel:SetText("Cancel") UI.StyleButton(cancel)
            cancel.DoClick = function() fr:Remove() end
            ok.DoClick = function()
                local dur = durEntry:GetValue() or "1h"
                DAdmin.Port.UIAction("command", { command = "ban", args = { target, dur, reason } })
                addLog("Banned " .. target .. " (" .. dur .. ")", C.red)
                fr:Remove()
            end
        end)
        actionBtn("Freeze Target", nil, function()
            local target = selected.target or selected.targetName or ""
            DAdmin.Port.UIAction("command", { command = "freeze", args = { target } })
            addLog("Froze " .. target, C.blue)
        end)

        -- Bottom padding
        local pad = vgui.Create("DPanel", rightScroll) pad:Dock(TOP) pad:SetTall(10) pad.Paint = nil
        rightScroll:AddItem(pad)
    end

    rebuildList = function()
        list:Clear()
        local statusColors = { open = C.yellow, claimed = C.blue, resolved = C.green, dismissed = C.red }
        local priColors = { high = C.red, medium = C.yellow, low = C.textDim }

        -- Column header
        local headerRow = list:Add("DPanel") headerRow:Dock(TOP) headerRow:SetTall(18)
        headerRow.Paint = function(_, w, h)
            surface.SetDrawColor(30,32,48) surface.DrawRect(0,0,w,h)
            draw.SimpleText("Reporter", "DAdmin.Small", 8, h/2, C.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText("Target", "DAdmin.Small", w*0.20, h/2, C.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText("Reason", "DAdmin.Small", w*0.40, h/2, C.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText("Priority", "DAdmin.Small", w*0.72, h/2, C.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText("Status", "DAdmin.Small", w*0.85, h/2, C.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end

        local filteredCount = 0
        for _, r in ipairs(reports) do
            if filterMode ~= "all" and r.status ~= filterMode then continue end
            local hay = string.lower(table.concat({
                tostring(r.id or ""),
                tostring(r.reporter or r.reporterName or ""),
                tostring(r.target or r.targetName or ""),
                tostring(r.reason or "")
            }, " "))
            if filterQuery ~= "" and not string.find(hay, filterQuery, 1, true) then
                continue
            end
            filteredCount = filteredCount + 1
            local row = list:Add("DButton") row:Dock(TOP) row:SetTall(28) row:DockMargin(0, 0, 0, 1) row:SetText("")
            row.Paint = function(_, w, h)
                surface.SetDrawColor(selected == r and C.select or C.bg2) surface.DrawRect(0, 0, w, h)
                surface.SetDrawColor(priColors[r.priority] or C.yellow) surface.DrawRect(0, 0, 3, h)
                draw.SimpleText(r.reporter or r.reporterName or "-", "DAdmin.Small", 8, h/2, C.blue, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                draw.SimpleText(r.target or r.targetName or "-", "DAdmin.Small", w*0.20, h/2, C.red, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                local reason = tostring(r.reason or "")
                if #reason > 30 then reason = string.sub(reason, 1, 28) .. ".." end
                draw.SimpleText(reason, "DAdmin.Small", w*0.40, h/2, C.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                draw.SimpleText(r.priority or "medium", "DAdmin.Small", w*0.72, h/2, priColors[r.priority] or C.yellow, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                draw.SimpleText(r.status or "open", "DAdmin.Small", w*0.85, h/2, statusColors[r.status] or C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end
            row.DoClick = function() selected = (selected == r) and nil or r rebuildDetail() rebuildList() end
            row.DoRightClick = function()
                local menu = DermaMenu()
                menu:AddOption("Select Report #" .. tostring(r.id), function()
                    selected = r
                    rebuildDetail()
                    rebuildList()
                end)
                menu:AddSpacer()
                menu:AddOption("Claim", function()
                    DAdmin.Port.UIAction("report_claim", { id = r.id })
                end)
                menu:AddOption("Resolve", function()
                    DAdmin.Port.UIAction("report_resolve", { id = r.id, resolution = "Resolved" })
                end)
                menu:AddOption("Dismiss", function()
                    DAdmin.Port.UIAction("report_dismiss", { id = r.id, reason = "Dismissed" })
                end)
                menu:AddOption("Start Sit", function()
                    DAdmin.Port.UIAction("report_startsit", { id = r.id })
                end)
                menu:AddOption("Goto Target", function()
                    DAdmin.Port.UIAction("command", { command = "goto", args = { r.target or r.targetName or "" } })
                end)
                menu:Open()
            end
        end

        if filteredCount == 0 then
            local empty = list:Add("DLabel") empty:Dock(TOP) empty:DockMargin(10, 10, 10, 0) empty:SetTall(20)
            empty:SetFont("DAdmin.Small") empty:SetTextColor(C.textDark) empty:SetText("No reports matching this filter.")
        end
    end

    -- Build filter buttons
    for _, f in ipairs(filters) do
        local b = vgui.Create("DButton", filterRow) b:Dock(RIGHT) b:DockMargin(2, 3, 0, 3) b:SetWide(65) b:SetText(f:sub(1,1):upper() .. f:sub(2))
        UI.StyleButton(b, f == filterMode and "active" or nil)
        filterButtons[f] = b
        b.DoClick = function()
            filterMode = f
            for k, btn in pairs(filterButtons) do btn._variant = k == f and "active" or nil end
            rebuildList()
        end
    end

    search.OnValueChange = function(self)
        filterQuery = string.lower(string.Trim(self:GetValue() or ""))
        rebuildList()
    end

    rebuildList() rebuildDetail()
end
