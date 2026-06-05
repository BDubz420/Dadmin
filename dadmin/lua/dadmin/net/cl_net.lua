if SERVER then return end

DAdmin = DAdmin or {}

net.Receive("DAdmin_ChatNotify", function()
    local text = net.ReadString()
    local msgType = net.ReadUInt(2)

    local settings = DAdmin.Port and DAdmin.Port.GetSettings and DAdmin.Port.GetSettings() or {}
    local hex = settings.prefix_color or "4A90D9"
    local r = tonumber("0x" .. string.sub(hex, 1, 2)) or 74
    local g = tonumber("0x" .. string.sub(hex, 3, 4)) or 144
    local b = tonumber("0x" .. string.sub(hex, 5, 6)) or 217
    local prefixColor = Color(r, g, b)

    if msgType == 0 then
        chat.AddText(prefixColor, "[DAdmin] ", color_white, text)
    elseif msgType == 1 then
        chat.AddText(prefixColor, "[DAdmin] ", Color(204, 170, 68), text)
    elseif msgType == 2 then
        chat.AddText(prefixColor, "[MOTD] ", Color(90, 170, 106), text)
    end
end)

net.Receive("DAdmin_ReportNotify", function()
    local report = net.ReadTable() or {}

    local settings = DAdmin.Port and DAdmin.Port.GetSettings and DAdmin.Port.GetSettings() or {}
    local hex = settings.prefix_color or "4A90D9"
    local r = tonumber("0x" .. string.sub(hex, 1, 2)) or 74
    local g = tonumber("0x" .. string.sub(hex, 3, 4)) or 144
    local b = tonumber("0x" .. string.sub(hex, 5, 6)) or 217

    chat.AddText(
        Color(r, g, b), "[DAdmin Report] ",
        Color(204, 68, 68), tostring(report.reporterName or "Unknown"),
        color_white, " reported ",
        Color(204, 68, 68), tostring(report.targetName or "Unknown"),
        color_white, ": ",
        Color(204, 170, 68), tostring(report.reason or "No reason")
    )

    if DAdmin.UI and DAdmin.UI.Colors then
        local C = DAdmin.UI.Colors
        local popup = vgui.Create("EditablePanel")
        popup:SetSize(300, 80)
        popup:SetPos(ScrW() - 310, 10)
        popup.Paint = function(_, w, h)
            surface.SetDrawColor(26, 29, 38, 240) surface.DrawRect(0, 0, w, h)
            surface.SetDrawColor(C.red) surface.DrawOutlinedRect(0, 0, w, h, 1)
            draw.SimpleText("New Report", "DAdmin.Title", 8, 10, C.red, TEXT_ALIGN_LEFT)
            draw.SimpleText(tostring(report.reporterName or "Unknown") .. " -> " .. tostring(report.targetName or "Unknown"), "DAdmin.Small", 8, 30, C.text, TEXT_ALIGN_LEFT)
            draw.SimpleText(string.sub(tostring(report.reason or ""), 1, 40), "DAdmin.Small", 8, 46, C.textDim, TEXT_ALIGN_LEFT)
        end
        local openBtn = vgui.Create("DButton", popup)
        openBtn:SetPos(220, 56) openBtn:SetSize(70, 18) openBtn:SetText("Open") openBtn:SetFont("DAdmin.Small")
        openBtn:SetTextColor(Color(74, 144, 217))
        openBtn.Paint = function() end
        openBtn.DoClick = function()
            DAdmin.OpenMenu("reports")
            popup:Remove()
        end
        timer.Simple(8, function() if IsValid(popup) then popup:AlphaTo(0, 0.5, 0, function() popup:Remove() end) end end)
    end
end)
