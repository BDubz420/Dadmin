if SERVER then return end
local UI = DAdmin.UI
local C = UI.Colors

function DAdmin.BuildLogsPanel(parent)
    parent:Clear()
    local logs = DAdmin.Port.GetLogs()
    local selected, filterType, searchText = nil, "all", ""

    local shell = vgui.Create("DPanel", parent) shell:Dock(FILL) shell.Paint = nil
    local right = vgui.Create("DPanel", shell) right:Dock(RIGHT) right:SetWide(210) right.Paint = nil
    local left = vgui.Create("DPanel", shell) left:Dock(FILL) left:DockMargin(0, 0, 5, 0) left.Paint = nil

    local toolbar = vgui.Create("DPanel", left) toolbar:Dock(TOP) toolbar:SetTall(24) toolbar.Paint = nil
    local search = vgui.Create("DTextEntry", toolbar) search:Dock(LEFT) search:SetWide(160) search:SetPlaceholderText("Search logs...") UI.StyleTextEntry(search)
    local typeFilter = vgui.Create("DPanel", toolbar) typeFilter:Dock(FILL) typeFilter:DockMargin(4, 0, 0, 0) typeFilter.Paint = nil

    local typeButtons = {}
    for _, t in ipairs({"all", "admin", "punishment", "command", "kill", "death", "damage", "chat", "connect"}) do
        local b = vgui.Create("DButton", typeFilter)
        b:Dock(LEFT) b:DockMargin(0, 3, 3, 3) b:SetWide(52) b:SetText(t) UI.StyleButton(b, t == "all" and "active" or nil)
        typeButtons[t] = b
    end

    local listSection, listBody = UI.MakeSection(left, "Admin Logs (" .. tostring(#logs) .. ")", FILL, {0, 5, 0, 0})
    local header = vgui.Create("DPanel", listBody) header:Dock(TOP) header:SetTall(20)
    header.Paint = function(_, w, h)
        surface.SetDrawColor(26, 29, 38, 255) surface.DrawRect(0, 0, w, h)
        draw.SimpleText("Time", "DAdmin.Small", 6, h/2, C.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Admin", "DAdmin.Small", w*0.12, h/2, C.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Action", "DAdmin.Small", w*0.28, h/2, C.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Target", "DAdmin.Small", w*0.42, h/2, C.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Reason", "DAdmin.Small", w*0.58, h/2, C.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
    local list = vgui.Create("DScrollPanel", listBody) list:Dock(FILL)

    local function showDetail()
        right:Clear()
        local detailSection, detailBody = UI.MakeSection(right, "Log Detail", FILL)
        if not selected then
            local lbl = vgui.Create("DLabel", detailBody) lbl:Dock(TOP) lbl:DockMargin(10, 10, 10, 0)
            lbl:SetFont("DAdmin.Normal") lbl:SetTextColor(C.textDark) lbl:SetText("Select a log entry.") lbl:SetWrap(true) return
        end
        for _, pair in ipairs({
            {"ID", tostring(selected.id or "-")},
            {"Time", tostring(selected.time or "-")},
            {"Source", tostring(selected.admin or "System")},
            {"Action", tostring(selected.action or "-")},
            {"Target", tostring(selected.target or "-")},
            {"Type", tostring(selected.type or "admin")},
            {"Details", tostring(selected.reason or selected.details or "-")},
        }) do
            local row = vgui.Create("DPanel", detailBody) row:Dock(TOP) row:SetTall(20) row:DockMargin(6, 0, 6, 0)
            row.Paint = function(_, w, h)
                draw.SimpleText(pair[1], "DAdmin.Small", 0, h/2, C.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                draw.SimpleText(pair[2], "DAdmin.Small", w, h/2, C.text, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
            end
        end

        if selected.weapon then
            local weapRow = vgui.Create("DPanel", detailBody) weapRow:Dock(TOP) weapRow:SetTall(20) weapRow:DockMargin(6, 0, 6, 0)
            weapRow.Paint = function(_, w, h)
                draw.SimpleText("Weapon", "DAdmin.Small", 0, h/2, C.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                draw.SimpleText(tostring(selected.weapon), "DAdmin.Small", w, h/2, C.yellow, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
            end
        end

        local viewHist = vgui.Create("DButton", detailBody) viewHist:Dock(TOP) viewHist:DockMargin(6, 10, 6, 0) viewHist:SetTall(22)
        viewHist:SetText("View Player History") UI.StyleButton(viewHist)
        viewHist.DoClick = function() DAdmin.SwitchTab("history") end

        local copy = vgui.Create("DButton", detailBody) copy:Dock(TOP) copy:DockMargin(6, 4, 6, 0) copy:SetTall(22)
        copy:SetText("Copy Entry") UI.StyleButton(copy)
        copy.DoClick = function()
            SetClipboardText("[" .. tostring(selected.time) .. "] " .. tostring(selected.admin) .. " " .. tostring(selected.action) .. " " .. tostring(selected.target) .. " - " .. tostring(selected.reason or ""))
        end

        local deleteSpacer = vgui.Create("DPanel", detailBody)
        deleteSpacer:Dock(FILL)
        deleteSpacer.Paint = nil

        local del = vgui.Create("DButton", detailBody) del:Dock(BOTTOM) del:DockMargin(6, 8, 6, 6) del:SetTall(24)
        del:SetText("Delete Entry") UI.StyleButton(del, "danger")
        del.DoClick = function()
            Derma_Query(
                "Delete this log entry? This cannot be undone.",
                "Confirm Log Delete",
                "Delete", function()
                    DAdmin.Port.UIAction("log_delete", { id = selected.id })
                    for i, l in ipairs(logs) do if tostring(l.id) == tostring(selected.id) then table.remove(logs, i) break end end
                    selected = nil
                    DAdmin.BuildLogsPanel(parent)
                end,
                "Cancel"
            )
        end

        local statsSection, statsBody = UI.MakeSection(right, "Log Statistics", BOTTOM, {0, 5, 0, 0}) statsSection:SetTall(140)
        local counts = {}
        for _, l in ipairs(logs) do counts[l.type or "admin"] = (counts[l.type or "admin"] or 0) + 1 end
        for k, v in SortedPairs(counts) do
            local row = vgui.Create("DPanel", statsBody) row:Dock(TOP) row:SetTall(18) row:DockMargin(6, 0, 6, 0)
            row.Paint = function(_, w, h)
                draw.SimpleText(k, "DAdmin.Small", 0, h/2, C.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                draw.SimpleText(tostring(v), "DAdmin.Title", w, h/2, C.blue, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
            end
        end
        local total = vgui.Create("DPanel", statsBody) total:Dock(TOP) total:SetTall(18) total:DockMargin(6, 0, 6, 0)
        total.Paint = function(_, w, h)
            draw.SimpleText("Total", "DAdmin.Small", 0, h/2, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText(tostring(#logs), "DAdmin.Title", w, h/2, C.green, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end
    end

    local actionColors = {
        kick = C.yellow, ban = C.red, unban = C.green, mute = C.yellow, unmute = C.green,
        gag = C.yellow, ungag = C.green, slay = C.red, warn = C.yellow, freeze = C.blue,
        unfreeze = C.green, goto = C.blue, bring = C.blue, setrank = C.purple, report = C.yellow,
        noclip = C.green, god = C.green, settings = C.blue, permissions = C.blue, broadcast = C.blue,
        kill = C.red, death = C.red, damage = C.yellow, arrest = C.blue, unarrest = C.green,
        connect = C.green, disconnect = C.yellow, spawn = C.text, chat = C.text,
    }

    local function rebuildList()
        list:Clear()
        local q = string.lower(string.Trim(searchText))
        for i, l in ipairs(logs) do
            if filterType ~= "all" and l.type ~= filterType then continue end
            if q ~= "" and not string.find(string.lower(tostring(l.admin) .. " " .. tostring(l.target) .. " " .. tostring(l.action) .. " " .. tostring(l.reason or "")), q, 1, true) then continue end
            local row = list:Add("DButton") row:Dock(TOP) row:SetTall(24) row:SetText("")
            row.Paint = function(_, w, h)
                surface.SetDrawColor(selected == l and C.select or ((i % 2 == 0) and Color(20, 22, 30) or C.bg2)) surface.DrawRect(0, 0, w, h)
                draw.SimpleText(l.time or "-", "DAdmin.Small", 6, h/2, C.textDark, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                draw.SimpleText(l.admin or "-", "DAdmin.Small", w*0.12, h/2, C.blue, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                draw.SimpleText(l.action or "-", "DAdmin.Title", w*0.28, h/2, actionColors[l.action] or C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                draw.SimpleText(l.target or "-", "DAdmin.Small", w*0.42, h/2, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                local reason = tostring(l.reason or l.details or "")
                if reason == "" then reason = "-" end
                draw.SimpleText(string.sub(reason, 1, 40), "DAdmin.Small", w*0.58, h/2, C.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end
            row.DoClick = function() selected = (selected == l) and nil or l showDetail() rebuildList() end
        end
    end

    search.OnValueChange = function(_, val) searchText = val rebuildList() end
    for t, btn in pairs(typeButtons) do
        btn.DoClick = function()
            filterType = t
            for k, b in pairs(typeButtons) do b._variant = k == t and "active" or nil end
            rebuildList()
        end
    end

    rebuildList() showDetail()
end
