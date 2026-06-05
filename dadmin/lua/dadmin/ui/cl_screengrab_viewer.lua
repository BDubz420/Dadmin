if SERVER then return end
local UI = DAdmin.UI
local C = UI.Colors

function DAdmin.OpenScreengrabViewer()
    local grabs = DAdmin.Port.GetScreengrabs()
    local fr = vgui.Create("EditablePanel") fr:SetSize(480, 360) fr:Center() fr:MakePopup()
    fr.Paint = function(_, w, h) UI.PaintPanel(w, h) end
    local hdr = vgui.Create("DPanel", fr) hdr:Dock(TOP) hdr:SetTall(22)
    hdr.Paint = function(_, w, h) UI.PaintHeader(w, h, "Screengrab Viewer") end
    local close = vgui.Create("DButton", hdr) close:Dock(RIGHT) close:SetWide(22) close:SetText("X") UI.StyleButton(close, "danger")
    close.DoClick = function() fr:Remove() end

    local shell = vgui.Create("DPanel", fr) shell:Dock(FILL) shell.Paint = nil
    local left = vgui.Create("DPanel", shell) left:Dock(LEFT) left:SetWide(160) left.Paint = nil
    local right = vgui.Create("DPanel", shell) right:Dock(FILL) right:DockMargin(5, 0, 0, 0) right.Paint = nil

    -- Player list
    local playerSection, playerBody = UI.MakeSection(left, "Players", FILL)
    local playerList = vgui.Create("DScrollPanel", playerBody) playerList:Dock(FILL)

    -- Detail area
    local detailSection, detailBody = UI.MakeSection(right, "Screenshots", FILL)
    local detailList = vgui.Create("DScrollPanel", detailBody) detailList:Dock(FILL)

    local function showPlayer(steamid)
        detailList:Clear()
        local playerGrabs = grabs[steamid] or {}
        if #playerGrabs == 0 then
            local lbl = vgui.Create("DLabel", detailList) lbl:Dock(TOP) lbl:DockMargin(10, 10, 10, 0)
            lbl:SetFont("DAdmin.Normal") lbl:SetTextColor(C.textDark) lbl:SetText("No screenshots for this player.")
            return
        end
        for i, grab in ipairs(playerGrabs) do
            local row = detailList:Add("DPanel") row:Dock(TOP) row:SetTall(26) row:DockMargin(4, 2, 4, 0)
            row.Paint = function(_, w, h)
                surface.SetDrawColor(C.bg2) surface.DrawRect(0, 0, w, h)
                draw.SimpleText("#" .. tostring(i), "DAdmin.Small", 6, h / 2, C.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                draw.SimpleText(grab.time or "Unknown", "DAdmin.Small", 26, h / 2, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                local sizeKB = math.Round((grab.size or 0) / 1024, 1)
                draw.SimpleText(tostring(sizeKB) .. " KB", "DAdmin.Small", w - 8, h / 2, C.textDim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
            end
            local viewBtn = vgui.Create("DButton", row) viewBtn:Dock(RIGHT) viewBtn:DockMargin(0, 4, 60, 4) viewBtn:SetWide(40) viewBtn:SetText("View") UI.StyleButton(viewBtn, "primary")
            viewBtn.DoClick = function()
                if grab.file and file.Exists(grab.file, "DATA") then
                    local imgPanel = vgui.Create("EditablePanel") imgPanel:SetSize(ScrW() * 0.6, ScrH() * 0.6) imgPanel:Center() imgPanel:MakePopup()
                    imgPanel.Paint = function(_, w, h) surface.SetDrawColor(0, 0, 0, 240) surface.DrawRect(0, 0, w, h) end
                    local html = vgui.Create("DHTML", imgPanel) html:Dock(FILL)
                    html:SetHTML('<html><body style="margin:0;background:#000;display:flex;align-items:center;justify-content:center;"><img src="../data/' .. grab.file .. '" style="max-width:100%;max-height:100%;"/></body></html>')
                    local closeImg = vgui.Create("DButton", imgPanel) closeImg:SetPos(imgPanel:GetWide() - 30, 2) closeImg:SetSize(26, 20) closeImg:SetText("X") UI.StyleButton(closeImg, "danger")
                    closeImg.DoClick = function() imgPanel:Remove() end
                end
            end
        end
    end

    local hasSome = false
    for steamid, playerGrabs in pairs(grabs) do
        if #playerGrabs > 0 then
            hasSome = true
            local b = playerList:Add("DButton") b:Dock(TOP) b:SetTall(24) b:DockMargin(2, 1, 2, 0) b:SetText("")
            b.Paint = function(_, w, h)
                surface.SetDrawColor(C.bg2) surface.DrawRect(0, 0, w, h)
                draw.SimpleText(steamid, "DAdmin.Small", 6, h / 2, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                draw.SimpleText(tostring(#playerGrabs), "DAdmin.Small", w - 6, h / 2, C.textDim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
            end
            b.DoClick = function() showPlayer(steamid) end
        end
    end

    if not hasSome then
        local lbl = vgui.Create("DLabel", playerBody) lbl:Dock(TOP) lbl:DockMargin(10, 10, 10, 0)
        lbl:SetFont("DAdmin.Normal") lbl:SetTextColor(C.textDark) lbl:SetWrap(true) lbl:SetText("No screengrabs stored yet. Use the screengrab command to capture player screenshots.")
    end
end
