if SERVER then return end

DAdmin = DAdmin or {}
DAdmin.UI = DAdmin.UI or {}

local UI = DAdmin.UI

function DAdmin.OpenPermissionGraph()
    local C = UI.Colors
    local ranks = DAdmin.Port.GetRanks()

    local frame = vgui.Create("EditablePanel")
    frame:SetSize(640, 440)
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
        draw.SimpleText("Permission Inheritance Graph", "DAdmin.Title", 8, h / 2, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
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
    left:SetWide(200)
    left.Paint = nil

    local right = vgui.Create("DPanel", shell)
    right:Dock(FILL)
    right:DockMargin(6, 0, 0, 0)
    right.Paint = nil

    local rankColors = {
        owner = C.purple, superadmin = C.red, admin = C.yellow,
        moderator = C.green, trusted = C.blue, user = Color(122, 126, 138)
    }

    local function getRankColor(id)
        return rankColors[string.lower(id or "")] or C.text
    end

    local sortedRanks = {}
    for _, r in ipairs(ranks) do
        sortedRanks[#sortedRanks + 1] = r
    end
    table.sort(sortedRanks, function(a, b) return (a.immunity or 0) > (b.immunity or 0) end)

    local graphPanel = vgui.Create("DPanel", left)
    graphPanel:Dock(FILL)
    graphPanel.Paint = function(_, w, h)
        surface.SetDrawColor(C.bg2)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(C.border)
        surface.DrawOutlinedRect(0, 0, w, h, 1)

        local count = #sortedRanks
        if count == 0 then return end

        local nodeH = 28
        local spacing = math.floor((h - 20) / math.max(count, 1))
        spacing = math.min(spacing, 50)
        local startY = 15

        for i, rank in ipairs(sortedRanks) do
            local y = startY + (i - 1) * spacing
            local cx = w / 2
            local rc = getRankColor(rank.id)

            surface.SetDrawColor(rc)
            surface.DrawOutlinedRect(cx - 60, y, 120, nodeH, 1)
            surface.SetDrawColor(Color(rc.r, rc.g, rc.b, 40))
            surface.DrawRect(cx - 59, y + 1, 118, nodeH - 2)

            draw.SimpleText(rank.label or rank.id, "DAdmin.Normal", cx, y + 9, rc, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            draw.SimpleText("imm: " .. tostring(rank.immunity or 0), "DAdmin.Small", cx, y + 21, C.textDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

            if rank.inherits and i < count then
                local nextY = y + nodeH
                surface.SetDrawColor(C.textDark)
                surface.DrawLine(cx, nextY, cx, nextY + (spacing - nodeH))

                local arrowY = nextY + (spacing - nodeH) - 3
                surface.DrawLine(cx - 4, arrowY, cx, nextY + (spacing - nodeH))
                surface.DrawLine(cx + 4, arrowY, cx, nextY + (spacing - nodeH))
            end
        end
    end

    local selected = sortedRanks[1]

    local function showDetail(rank)
        right:Clear()
        if not rank then return end
        selected = rank

        local detailSection, detailBody = UI.MakeSection(right, rank.label .. " - Permissions", FILL)
        local scroll = vgui.Create("DScrollPanel", detailBody)
        scroll:Dock(FILL)

        local function line(text, color)
            local lbl = vgui.Create("DLabel", scroll)
            lbl:Dock(TOP)
            lbl:DockMargin(8, 2, 8, 0)
            lbl:SetTall(18)
            lbl:SetFont("DAdmin.Small")
            lbl:SetTextColor(color or C.text)
            lbl:SetText(text)
        end

        line("Rank: " .. rank.label, getRankColor(rank.id))
        line("Immunity: " .. tostring(rank.immunity or 0), C.yellow)
        line("Inherits: " .. tostring(rank.inherits or "None"), C.textDim)
        line("Members: " .. tostring(rank.members or 0), C.text)
        line("", C.text)

        local matrix = DAdmin.Port.GetPermissionMatrix()
        local ownPerms = matrix[rank.id] or {}
        if #ownPerms > 0 then
            line("Direct Permissions:", C.blue)
            for _, p in ipairs(ownPerms) do
                line("  " .. p, C.green)
            end
        else
            line("No direct permissions assigned.", C.textDark)
        end

        if rank.inherits then
            line("", C.text)
            line("Inherited from " .. tostring(rank.inherits) .. ":", C.textDim)
            local parentPerms = matrix[rank.inherits] or {}
            if #parentPerms > 0 then
                for _, p in ipairs(parentPerms) do
                    line("  " .. p, C.textDim)
                end
            else
                line("  (none)", C.textDark)
            end
        end
    end

    for _, rank in ipairs(sortedRanks) do
        local clickable = vgui.Create("DButton", graphPanel)
        clickable:SetSize(120, 28)
        clickable:SetText("")
        clickable:SetPos(graphPanel:GetWide() / 2 - 60, 15 + (_ - 1) * math.min(50, math.floor((graphPanel:GetTall() - 20) / math.max(#sortedRanks, 1))))
        clickable.Paint = function() end
        clickable.DoClick = function() showDetail(rank) end
    end

    showDetail(selected)
end
