if SERVER then return end

function DAdmin.BuildCasesPanel(parent)
    parent:Clear()
    local UI = DAdmin.UI
    local C = UI.Colors
    local cases = DAdmin.Port.GetCases and DAdmin.Port.GetCases() or {}

    local section, body = UI.MakeSection(parent, "Moderation Cases", FILL)
    local list = vgui.Create("DScrollPanel", body)
    list:Dock(FILL)

    if #cases == 0 then
        local empty = vgui.Create("DLabel", list)
        empty:Dock(TOP)
        empty:SetTall(24)
        empty:SetText("No cases yet.")
        empty:SetTextColor(C.textDim)
        empty:SetFont("DAdmin.Normal")
        return
    end

    for _, case in ipairs(cases) do
        local row = list:Add("DPanel")
        row:Dock(TOP)
        row:DockMargin(0, 0, 0, 4)
        row:SetTall(78)
        row.Paint = function(_, w, h)
            surface.SetDrawColor(C.bg2)
            surface.DrawRect(0, 0, w, h)
            surface.SetDrawColor(C.borderDark)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
            draw.SimpleText("#" .. tostring(case.id), "DAdmin.Title", 8, 8, C.text, TEXT_ALIGN_LEFT)
            draw.SimpleText("Player: " .. tostring(case.playerSteamID or "-"), "DAdmin.Small", 8, 30, C.textDim, TEXT_ALIGN_LEFT)
            draw.SimpleText("Status: " .. tostring(case.status or "open"), "DAdmin.Small", 8, 48, case.status == "closed" and C.green or C.yellow, TEXT_ALIGN_LEFT)
            draw.SimpleText("Reason: " .. tostring(case.reason or ""), "DAdmin.Small", 220, 30, C.textDim, TEXT_ALIGN_LEFT)
            draw.SimpleText("Report: " .. tostring(case.reportID or "-"), "DAdmin.Small", 220, 48, C.textDim, TEXT_ALIGN_LEFT)
        end
    end
end
