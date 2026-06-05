if SERVER then return end

DAdmin = DAdmin or {}
DAdmin.UI = DAdmin.UI or {}

local UI = DAdmin.UI

function DAdmin.OpenPlayerManager()
    local C = UI.Colors
    local allPlayers = DAdmin.Port.GetPlayers()

    local frame = vgui.Create("EditablePanel")
    frame:SetSize(700, 480)
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
        draw.SimpleText("Player Manager - Bulk Actions", "DAdmin.Title", 8, h / 2, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
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
    left:SetWide(280)
    left.Paint = nil

    local right = vgui.Create("DPanel", shell)
    right:Dock(FILL)
    right:DockMargin(6, 0, 0, 0)
    right.Paint = nil

    local toolbar = vgui.Create("DPanel", left)
    toolbar:Dock(TOP)
    toolbar:SetTall(26)
    toolbar.Paint = nil

    local search = vgui.Create("DTextEntry", toolbar)
    search:Dock(FILL)
    search:SetPlaceholderText("Filter players...")
    UI.StyleTextEntry(search)

    local selectAll = vgui.Create("DButton", toolbar)
    selectAll:Dock(RIGHT)
    selectAll:DockMargin(4, 0, 0, 0)
    selectAll:SetWide(70)
    selectAll:SetText("Select All")
    UI.StyleButton(selectAll)

    local listSection, listBody = UI.MakeSection(left, "Players", FILL, {0, 4, 0, 0})
    local list = vgui.Create("DScrollPanel", listBody)
    list:Dock(FILL)

    local selected = {}
    local checkboxes = {}

    local function getSelected()
        local out = {}
        for _, p in ipairs(allPlayers) do
            if selected[p.steamid] then out[#out + 1] = p end
        end
        return out
    end

    local function runBulk(cmd, extra)
        local sel = getSelected()
        for _, p in ipairs(sel) do
            local args = { p.name }
            if extra and extra ~= "" then args[#args + 1] = extra end
            DAdmin.Port.UIAction("command", { command = cmd, args = args })
        end
    end

    local actionSection, actionBody = UI.MakeSection(right, "Bulk Actions", TOP)
    actionSection:SetTall(260)

    local selectedLabel = vgui.Create("DLabel", actionBody)
    selectedLabel:Dock(TOP)
    selectedLabel:DockMargin(8, 6, 8, 0)
    selectedLabel:SetTall(18)
    selectedLabel:SetFont("DAdmin.Normal")
    selectedLabel:SetTextColor(C.blue)

    local function updateLabel()
        local count = 0
        for _ in pairs(selected) do count = count + 1 end
        selectedLabel:SetText(tostring(count) .. " player(s) selected")
    end
    updateLabel()

    local function actionButton(txt, variant, fn)
        local b = vgui.Create("DButton", actionBody)
        b:Dock(TOP)
        b:DockMargin(8, 4, 8, 0)
        b:SetTall(22)
        b:SetText(txt)
        UI.StyleButton(b, variant)
        b.DoClick = fn
    end

    local function promptAndRun(title, cmd)
        local prompt = vgui.Create("EditablePanel")
        prompt:SetSize(300, 100)
        prompt:Center()
        prompt:MakePopup()
        prompt.Paint = function(_, w, h) UI.PaintPanel(w, h) end

        local promptHdr = vgui.Create("DPanel", prompt)
        promptHdr:Dock(TOP)
        promptHdr:SetTall(22)
        promptHdr.Paint = function(_, w, h) UI.PaintHeader(w, h, title) end

        local input = vgui.Create("DTextEntry", prompt)
        input:Dock(TOP)
        input:DockMargin(8, 8, 8, 0)
        input:SetTall(22)
        input:SetPlaceholderText("Reason...")
        UI.StyleTextEntry(input)

        local btns = vgui.Create("DPanel", prompt)
        btns:Dock(BOTTOM)
        btns:SetTall(28)
        btns.Paint = nil

        local ok = vgui.Create("DButton", btns)
        ok:Dock(RIGHT)
        ok:DockMargin(0, 4, 8, 4)
        ok:SetWide(80)
        ok:SetText("Confirm")
        UI.StyleButton(ok, "primary")
        ok.DoClick = function()
            runBulk(cmd, input:GetValue())
            prompt:Remove()
        end

        local cancel = vgui.Create("DButton", btns)
        cancel:Dock(RIGHT)
        cancel:DockMargin(0, 4, 4, 4)
        cancel:SetWide(80)
        cancel:SetText("Cancel")
        UI.StyleButton(cancel)
        cancel.DoClick = function() prompt:Remove() end
    end

    actionButton("Freeze All Selected", nil, function() runBulk("freeze") end)
    actionButton("Unfreeze All Selected", nil, function() runBulk("unfreeze") end)
    actionButton("Mute All Selected", nil, function() runBulk("mute") end)
    actionButton("Unmute All Selected", nil, function() runBulk("unmute") end)
    actionButton("Gag All Selected", nil, function() runBulk("gag") end)
    actionButton("Slay All Selected", "danger", function() runBulk("slay") end)
    actionButton("Kick All Selected", "danger", function() promptAndRun("Kick Reason", "kick") end)
    actionButton("Warn All Selected", "primary", function() promptAndRun("Warn Reason", "warn") end)

    local logSection, logBody = UI.MakeSection(right, "Action Log", FILL, {0, 6, 0, 0})
    local logList = vgui.Create("DScrollPanel", logBody)
    logList:Dock(FILL)

    local function rebuildList()
        list:Clear()
        checkboxes = {}
        local q = string.Trim(string.lower(search:GetValue() or ""))

        for _, p in ipairs(allPlayers) do
            if q == "" or string.find(string.lower(p.name), q, 1, true) or string.find(string.lower(p.steamid), q, 1, true) then
                local row = list:Add("DButton")
                row:Dock(TOP)
                row:DockMargin(0, 0, 0, 2)
                row:SetTall(26)
                row:SetText("")
                row.Paint = function(self, w, h)
                    surface.SetDrawColor(selected[p.steamid] and C.select or (self:IsHovered() and Color(24, 28, 40) or C.bg2))
                    surface.DrawRect(0, 0, w, h)
                    surface.SetDrawColor(C.border)
                    surface.DrawOutlinedRect(0, 0, w, h, 1)

                    local cbx, cby = 8, h / 2 - 5
                    surface.SetDrawColor(C.border)
                    surface.DrawOutlinedRect(cbx, cby, 10, 10, 1)
                    if selected[p.steamid] then
                        surface.SetDrawColor(C.blue)
                        surface.DrawRect(cbx + 2, cby + 2, 6, 6)
                    end

                    draw.SimpleText(p.name, "DAdmin.Small", 24, h / 2, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                    draw.SimpleText("[" .. (p.rank or "User") .. "]", "DAdmin.Small", 150, h / 2, p.rankColor or C.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                    draw.SimpleText(tostring(p.ping) .. "ms", "DAdmin.Small", w - 8, h / 2, C.textDark, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
                end
                row.DoClick = function()
                    selected[p.steamid] = not selected[p.steamid] or nil
                    updateLabel()
                end
                checkboxes[p.steamid] = row
            end
        end
    end

    selectAll.DoClick = function()
        local anyUnselected = false
        for _, p in ipairs(allPlayers) do
            if not selected[p.steamid] then anyUnselected = true break end
        end
        for _, p in ipairs(allPlayers) do
            selected[p.steamid] = anyUnselected or nil
        end
        updateLabel()
        rebuildList()
    end

    search.OnValueChange = function() rebuildList() end
    rebuildList()
end
