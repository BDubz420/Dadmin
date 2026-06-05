if SERVER then return end
local UI = DAdmin.UI
local C = UI.Colors

DAdmin._selectedRankId = DAdmin._selectedRankId or nil

function DAdmin.BuildRanksPanel(parent)
    parent:Clear()
    local ranks = DAdmin.Port.GetRanks()
    if not ranks or #ranks == 0 then
        local lbl = vgui.Create("DLabel", parent)
        lbl:Dock(TOP) lbl:DockMargin(10, 10, 10, 0) lbl:SetFont("DAdmin.Normal") lbl:SetTextColor(C.textDark) lbl:SetText("No ranks found.")
        return
    end

    local selected = ranks[1]
    if DAdmin._selectedRankId then
        for _, r in ipairs(ranks) do
            if r.id == DAdmin._selectedRankId then selected = r break end
        end
    end

    local shell = vgui.Create("DPanel", parent) shell:Dock(FILL) shell.Paint = nil
    local left = vgui.Create("DPanel", shell) left:Dock(LEFT) left:SetWide(160) left.Paint = nil
    local right = vgui.Create("DPanel", shell) right:Dock(RIGHT) right:SetWide(185) right.Paint = nil
    local center = vgui.Create("DPanel", shell) center:Dock(FILL) center:DockMargin(5, 0, 5, 0) center.Paint = nil

    local listP, listB = UI.MakeSection(left, "Rank Hierarchy", FILL)
    local changeP, changeB = UI.MakeSection(right, "Change Log", FILL)
    local clog = vgui.Create("DLabel", changeB) clog:Dock(TOP) clog:DockMargin(8, 8, 8, 0) clog:SetFont("DAdmin.Normal") clog:SetTextColor(C.textDark) clog:SetText("No changes yet...")

local toolsP, toolsB = UI.MakeSection(right, "Rank Management", BOTTOM, {0, 5, 0, 0}) toolsP:SetTall(120)

local create = vgui.Create("DButton", toolsB)
create:Dock(TOP) create:DockMargin(8, 8, 8, 0) create:SetTall(24)
create:SetText("Create Rank") UI.StyleButton(create, "primary")
create.DoClick = function()
    local frame = vgui.Create("EditablePanel")
    frame:SetSize(330, 190) frame:Center() frame:MakePopup()
    frame.Paint = function(_, w, h) UI.PaintPanel(w, h) end
    local hdr = vgui.Create("DPanel", frame) hdr:Dock(TOP) hdr:SetTall(24)
    hdr.Paint = function(_, w, h) UI.PaintHeader(w, h, "Create Rank") end

    local id = vgui.Create("DTextEntry", frame) id:Dock(TOP) id:DockMargin(10, 10, 10, 0) id:SetTall(24) id:SetPlaceholderText("rank id, e.g. senioradmin") UI.StyleTextEntry(id)
    local label = vgui.Create("DTextEntry", frame) label:Dock(TOP) label:DockMargin(10, 6, 10, 0) label:SetTall(24) label:SetPlaceholderText("Display name") UI.StyleTextEntry(label)
    local inherit = vgui.Create("DTextEntry", frame) inherit:Dock(TOP) inherit:DockMargin(10, 6, 10, 0) inherit:SetTall(24) inherit:SetPlaceholderText("Inherit from (user/admin/etc)") inherit:SetText("user") UI.StyleTextEntry(inherit)
    local immunity = vgui.Create("DTextEntry", frame) immunity:Dock(TOP) immunity:DockMargin(10, 6, 10, 0) immunity:SetTall(24) immunity:SetPlaceholderText("Immunity number") immunity:SetText("0") UI.StyleTextEntry(immunity)

    local buttons = vgui.Create("DPanel", frame) buttons:Dock(BOTTOM) buttons:SetTall(34) buttons.Paint = nil
    local ok = vgui.Create("DButton", buttons) ok:Dock(RIGHT) ok:DockMargin(0, 5, 10, 5) ok:SetWide(90) ok:SetText("Create") UI.StyleButton(ok, "primary")
    ok.DoClick = function()
        DAdmin.Port.UIAction("create_rank", {
            id = id:GetValue(),
            label = label:GetValue(),
            inherit = inherit:GetValue(),
            immunity = immunity:GetValue()
        })
        frame:Remove()
        timer.Simple(.15, function() DAdmin.Port.Refresh() if IsValid(parent) then DAdmin.BuildRanksPanel(parent) end end)
    end
    local cancel = vgui.Create("DButton", buttons) cancel:Dock(RIGHT) cancel:DockMargin(0, 5, 6, 5) cancel:SetWide(70) cancel:SetText("Cancel") UI.StyleButton(cancel)
    cancel.DoClick = function() frame:Remove() end
end

local del = vgui.Create("DButton", toolsB)
del:Dock(TOP) del:DockMargin(8, 6, 8, 0) del:SetTall(24)
del:SetText("Delete Selected") UI.StyleButton(del, "danger")
del.DoClick = function()
    if not selected then return end
    local id = selected.id
    if id == "owner" or id == "superadmin" or id == "admin" or id == "user" then return end

    Derma_Query(
        "Are you sure you want to permanently delete the rank '" .. tostring(id) .. "'?\n\nThis action cannot be undone.",
        "Delete Rank",
        "Delete Rank",
        function()
            Derma_Query(
                "Final confirmation required. Delete '" .. tostring(id) .. "' now?",
                "Confirm Rank Deletion",
                "Yes, Delete",
                function()
                    DAdmin.Port.UIAction("delete_rank", { id = id })
                    timer.Simple(.15, function()
                        DAdmin.Port.Refresh()
                        if IsValid(parent) then DAdmin.BuildRanksPanel(parent) end
                    end)
                end,
                "Cancel"
            )
        end,
        "Cancel"
    )
end


    for _, rank in ipairs(ranks) do
        local b = vgui.Create("DButton", listB) b:Dock(TOP) b:SetTall(28) b:DockMargin(0, 0, 0, 2) b:SetText("")
        b.Paint = function(_, w, h)
            surface.SetDrawColor(selected == rank and C.select or C.bg2) surface.DrawRect(0, 0, w, h)
            surface.SetDrawColor(rank.color or C.text) surface.DrawRect(6, h / 2 - 4, 8, 8)
            draw.SimpleText(rank.label or "", "DAdmin.Normal", 20, h / 2, selected == rank and color_white or C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText(tostring(rank.immunity or 0), "DAdmin.Small", w - 6, h / 2, C.textDark, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end
        b.DoClick = function()
            selected = rank
            DAdmin._selectedRankId = rank.id
            DAdmin.BuildRanksPanel(parent)
        end
    end

    local memberCount = selected.members or 0
    local detailP, detailB = UI.MakeSection(center, (selected.label or "Unknown") .. " (" .. tostring(memberCount) .. " members)", TOP) detailP:SetTall(200)

    local stats = vgui.Create("DPanel", detailB) stats:Dock(TOP) stats:DockMargin(8, 8, 8, 0) stats:SetTall(46)
    stats.Paint = function(_, w, h)
        if not selected then return end
        local cols = {
            {"Members", tostring(selected.members or 0), C.text},
            {"Immunity", tostring(selected.immunity or 0), C.yellow},
            {"Inherits", tostring(selected.inherits or "None"), C.textDim}
        }
        local cw = (w - 10) / 3
        for i, info in ipairs(cols) do
            local x = (i - 1) * (cw + 5)
            surface.SetDrawColor(C.bg2) surface.DrawRect(x, 0, cw, h)
            surface.SetDrawColor(C.border) surface.DrawOutlinedRect(x, 0, cw, h, 1)
            draw.SimpleText(info[1], "DAdmin.Small", x + 8, 12, C.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText(tostring(info[2]), "DAdmin.Title", x + 8, 30, info[3], TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
    end

    local chain = {}
    for _, r in ipairs(ranks) do table.insert(chain, r) end
    local chainP = vgui.Create("DPanel", detailB) chainP:Dock(TOP) chainP:DockMargin(8, 6, 8, 0) chainP:SetTall(16)
    chainP.Paint = function(_, w, h) draw.SimpleText("INHERITANCE CHAIN", "DAdmin.Small", 0, h / 2, C.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER) end
    local chainRow = vgui.Create("DPanel", detailB) chainRow:Dock(TOP) chainRow:DockMargin(8, 2, 8, 0) chainRow:SetTall(20)
    chainRow.Paint = function(_, w, h)
        local cx = 0
        for idx, r in ipairs(chain) do
            local col = r.color or C.text
            surface.SetDrawColor(col) surface.DrawRect(cx, h / 2 - 3, 6, 6) cx = cx + 9
            surface.SetFont("DAdmin.Small")
            local tw = surface.GetTextSize(r.label or "")
            draw.SimpleText(r.label or "", "DAdmin.Small", cx, h / 2, col, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            cx = cx + tw + 4
            if idx < #chain then draw.SimpleText("->", "DAdmin.Small", cx, h / 2, C.textDark, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER) cx = cx + 20 end
        end
    end

    local actionRow = vgui.Create("DPanel", detailB) actionRow:Dock(TOP) actionRow:DockMargin(8, 8, 8, 0) actionRow:SetTall(26) actionRow.Paint = nil
    local editBtn = vgui.Create("DButton", actionRow) editBtn:Dock(LEFT) editBtn:SetWide(90) editBtn:SetText("Edit Rank") UI.StyleButton(editBtn)
    editBtn.DoClick = function()
        if not selected then return end
        local fr = vgui.Create("EditablePanel") fr:SetSize(280, 155) fr:Center() fr:MakePopup()
        fr.Paint = function(_, w, h) UI.PaintPanel(w, h) end
        local hdr = vgui.Create("DPanel", fr) hdr:Dock(TOP) hdr:SetTall(22) hdr.Paint = function(_, w, h) UI.PaintHeader(w, h, "Edit " .. (selected.label or "Rank")) end
        local labelLabel = vgui.Create("DLabel", fr) labelLabel:Dock(TOP) labelLabel:DockMargin(8, 6, 8, 0) labelLabel:SetFont("DAdmin.Small") labelLabel:SetTextColor(C.textDim) labelLabel:SetText("Label:")
        local labelEntry = vgui.Create("DTextEntry", fr) labelEntry:Dock(TOP) labelEntry:DockMargin(8, 2, 8, 0) labelEntry:SetTall(22) labelEntry:SetText(selected.label or "") UI.StyleTextEntry(labelEntry)
        local immLabel = vgui.Create("DLabel", fr) immLabel:Dock(TOP) immLabel:DockMargin(8, 4, 8, 0) immLabel:SetFont("DAdmin.Small") immLabel:SetTextColor(C.textDim) immLabel:SetText("Immunity (higher = more immune):")
        local immEntry = vgui.Create("DTextEntry", fr) immEntry:Dock(TOP) immEntry:DockMargin(8, 2, 8, 0) immEntry:SetTall(22) immEntry:SetText(tostring(selected.immunity or 0)) UI.StyleTextEntry(immEntry)
        local save = vgui.Create("DButton", fr) save:Dock(BOTTOM) save:DockMargin(8, 4, 8, 8) save:SetTall(24) save:SetText("Save") UI.StyleButton(save, "primary")
        save.DoClick = function()
            DAdmin.Port.UIAction("edit_rank", { rank = selected.id, data = { label = labelEntry:GetValue(), immunity = immEntry:GetValue(), inherits = selected.inherits } })
            fr:Remove()
        end
    end

    local permsBtn = vgui.Create("DButton", actionRow) permsBtn:Dock(LEFT) permsBtn:DockMargin(6, 0, 0, 0) permsBtn:SetWide(90) permsBtn:SetText("Edit Perms") UI.StyleButton(permsBtn, "primary")
    permsBtn.DoClick = function() DAdmin.SwitchTab("permissions") end

    local settingsP, settingsB = UI.MakeSection(center, "Rank Settings - " .. (selected.label or ""), FILL, {0, 5, 0, 0})
    local mapping = {
        {"Can target same rank", "target_same"},
        {"Access admin menu", "access_menu"},
        {"Receive admin alerts", "receive_alerts"},
        {"Immune to target selectors", "immune_selectors"}
    }
    for _, row in ipairs(mapping) do
        local pnl = vgui.Create("DPanel", settingsB) pnl:Dock(TOP) pnl:SetTall(24)
        pnl.Paint = function(_, w, h) draw.SimpleText(row[1], "DAdmin.Small", 8, h / 2, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER) end
        local value = selected.settings and selected.settings[row[2]]
        local btn = vgui.Create("DButton", pnl) btn:Dock(RIGHT) btn:DockMargin(0, 4, 8, 4) btn:SetWide(40)
        btn:SetText(value and "ON" or "OFF") UI.StyleButton(btn, value and "primary" or nil)
        btn.DoClick = function()
            value = not value
            btn:SetText(value and "ON" or "OFF")
            btn._variant = value and "primary" or nil
            DAdmin.Port.UIAction("toggle_rank_setting", { rank = selected.id, key = row[2], value = value })
        end
    end
end
