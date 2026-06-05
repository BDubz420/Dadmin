if SERVER then return end

DAdmin = DAdmin or {}
DAdmin.UI = DAdmin.UI or {}
DAdmin.Evidence = DAdmin.Evidence or {}

local UI = DAdmin.UI

function DAdmin.OpenEvidenceViewer(caseID, items)
    local C = UI.Colors
    items = items or {}

    local frame = vgui.Create("EditablePanel")
    frame:SetSize(520, 420)
    frame:Center()
    frame:MakePopup()
    frame.Paint = function(_, w, h)
        surface.SetDrawColor(C.bg)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(C.border)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    local hdr = vgui.Create("DPanel", frame)
    hdr:Dock(TOP)
    hdr:SetTall(24)
    hdr.Paint = function(_, w, h)
        UI.DrawVerticalGradient(0, 0, w, h, C.headerA, C.headerB)
        surface.SetDrawColor(C.borderDark)
        surface.DrawLine(0, h - 1, w, h - 1)
        draw.SimpleText("Evidence Viewer" .. (caseID and (" - Case #" .. tostring(caseID)) or ""), "DAdmin.Title", 8, h / 2, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local close = vgui.Create("DButton", hdr)
    close:Dock(RIGHT)
    close:SetWide(18)
    close:SetText("x")
    UI.StyleButton(close)
    close.DoClick = function() frame:Remove() end

    local shell = vgui.Create("DPanel", frame)
    shell:Dock(FILL)
    shell:DockMargin(6, 6, 6, 6)
    shell.Paint = nil

    local left = vgui.Create("DPanel", shell)
    left:Dock(LEFT)
    left:SetWide(180)
    left.Paint = nil

    local right = vgui.Create("DPanel", shell)
    right:Dock(FILL)
    right:DockMargin(6, 0, 0, 0)
    right.Paint = nil

    local listSection, listBody = UI.MakeSection(left, "Evidence Items (" .. tostring(#items) .. ")", FILL)
    local list = vgui.Create("DScrollPanel", listBody)
    list:Dock(FILL)

    local previewSection, previewBody = UI.MakeSection(right, "Preview", FILL)

    local function showPreview(item)
        previewBody:Clear()

        if not item then
            local lbl = vgui.Create("DLabel", previewBody)
            lbl:Dock(TOP)
            lbl:DockMargin(10, 10, 10, 0)
            lbl:SetFont("DAdmin.Normal")
            lbl:SetTextColor(C.textDark)
            lbl:SetText("Select an evidence item to preview.")
            return
        end

        for _, pair in ipairs({
            {"Type", item.type or "unknown"},
            {"Source", item.source or "unknown"},
            {"Time", item.time or "unknown"},
            {"Added By", item.addedBy or "System"},
        }) do
            local row = vgui.Create("DPanel", previewBody)
            row:Dock(TOP)
            row:DockMargin(8, 2, 8, 0)
            row:SetTall(18)
            row.Paint = function(_, w, h)
                draw.SimpleText(pair[1], "DAdmin.Small", 0, h / 2, C.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                draw.SimpleText(pair[2], "DAdmin.Small", w, h / 2, C.text, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
            end
        end

        if item.type == "screenshot" and item.material then
            local imgPanel = vgui.Create("DPanel", previewBody)
            imgPanel:Dock(TOP)
            imgPanel:DockMargin(8, 8, 8, 0)
            imgPanel:SetTall(180)
            imgPanel.Paint = function(_, w, h)
                surface.SetDrawColor(C.bg3)
                surface.DrawRect(0, 0, w, h)
                surface.SetDrawColor(C.border)
                surface.DrawOutlinedRect(0, 0, w, h, 1)
                if item.material then
                    surface.SetMaterial(item.material)
                    surface.SetDrawColor(255, 255, 255, 255)
                    surface.DrawTexturedRect(2, 2, w - 4, h - 4)
                end
            end
        elseif item.type == "note" or item.type == "text" then
            local note = vgui.Create("DLabel", previewBody)
            note:Dock(TOP)
            note:DockMargin(8, 8, 8, 0)
            note:SetTall(120)
            note:SetWrap(true)
            note:SetFont("DAdmin.Normal")
            note:SetTextColor(C.text)
            note:SetText(item.content or item.details or "No content.")
        elseif item.type == "log" then
            local log = vgui.Create("DLabel", previewBody)
            log:Dock(TOP)
            log:DockMargin(8, 8, 8, 0)
            log:SetTall(80)
            log:SetWrap(true)
            log:SetFont("DAdmin.Mono")
            log:SetTextColor(C.textDim)
            log:SetText(item.content or item.details or "No log content.")
        else
            local desc = vgui.Create("DLabel", previewBody)
            desc:Dock(TOP)
            desc:DockMargin(8, 8, 8, 0)
            desc:SetTall(60)
            desc:SetWrap(true)
            desc:SetFont("DAdmin.Normal")
            desc:SetTextColor(C.text)
            desc:SetText(item.details or item.content or "No details available.")
        end

        local del = vgui.Create("DButton", previewBody)
        del:Dock(BOTTOM)
        del:DockMargin(8, 0, 8, 8)
        del:SetTall(22)
        del:SetText("Remove Evidence")
        UI.StyleButton(del, "danger")
        del.DoClick = function()
            if caseID then
                DAdmin.Port.UIAction("evidence_remove", { caseID = caseID, evidenceID = item.id })
            end
            frame:Remove()
        end
    end

    local typeIcons = { screenshot = "[IMG]", note = "[NOTE]", log = "[LOG]", text = "[TXT]" }
    local selected
    for _, item in ipairs(items) do
        local btn = list:Add("DButton")
        btn:Dock(TOP)
        btn:DockMargin(0, 0, 0, 2)
        btn:SetTall(30)
        btn:SetText("")
        btn.Paint = function(self, w, h)
            surface.SetDrawColor(selected == item and C.select or (self:IsHovered() and Color(24, 28, 40) or C.bg2))
            surface.DrawRect(0, 0, w, h)
            surface.SetDrawColor(C.border)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
            draw.SimpleText(typeIcons[item.type] or "[?]", "DAdmin.Small", 6, h / 2, C.blue, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText(item.label or item.type or "Evidence", "DAdmin.Small", 42, h / 2, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText(item.time or "", "DAdmin.Small", w - 4, h / 2, C.textDark, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end
        btn.DoClick = function()
            selected = item
            showPreview(item)
        end
    end

    if #items == 0 then
        local lbl = vgui.Create("DLabel", listBody)
        lbl:Dock(TOP)
        lbl:DockMargin(8, 8, 8, 0)
        lbl:SetFont("DAdmin.Normal")
        lbl:SetTextColor(C.textDark)
        lbl:SetText("No evidence attached.")
    end

    showPreview(nil)

    local addBtn = vgui.Create("DButton", frame)
    addBtn:Dock(BOTTOM)
    addBtn:DockMargin(6, 0, 6, 6)
    addBtn:SetTall(24)
    addBtn:SetText("Add Note as Evidence")
    UI.StyleButton(addBtn, "primary")
    addBtn.DoClick = function()
        local prompt = vgui.Create("EditablePanel")
        prompt:SetSize(320, 130)
        prompt:Center()
        prompt:MakePopup()
        prompt.Paint = function(_, w, h) UI.PaintPanel(w, h) end

        local promptHdr = vgui.Create("DPanel", prompt)
        promptHdr:Dock(TOP)
        promptHdr:SetTall(22)
        promptHdr.Paint = function(_, w, h) UI.PaintHeader(w, h, "Add Evidence Note") end

        local input = vgui.Create("DTextEntry", prompt)
        input:Dock(TOP)
        input:DockMargin(8, 8, 8, 0)
        input:SetTall(40)
        input:SetMultiline(true)
        input:SetPlaceholderText("Describe the evidence...")
        UI.StyleTextEntry(input)

        local btns = vgui.Create("DPanel", prompt)
        btns:Dock(BOTTOM)
        btns:SetTall(30)
        btns.Paint = nil

        local ok = vgui.Create("DButton", btns)
        ok:Dock(RIGHT)
        ok:DockMargin(0, 4, 8, 4)
        ok:SetWide(90)
        ok:SetText("Add")
        UI.StyleButton(ok, "primary")
        ok.DoClick = function()
            if caseID and input:GetValue() ~= "" then
                DAdmin.Port.UIAction("evidence_add", { caseID = caseID, type = "note", content = input:GetValue() })
            end
            prompt:Remove()
            frame:Remove()
        end

        local cancel = vgui.Create("DButton", btns)
        cancel:Dock(RIGHT)
        cancel:DockMargin(0, 4, 4, 4)
        cancel:SetWide(90)
        cancel:SetText("Cancel")
        UI.StyleButton(cancel)
        cancel.DoClick = function() prompt:Remove() end
    end
end
