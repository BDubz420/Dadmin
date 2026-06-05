if SERVER then return end

DAdmin = DAdmin or {}
DAdmin.UI = DAdmin.UI or {}
local UI = DAdmin.UI

local paletteFrame

function DAdmin.OpenCommandPalette()
    if IsValid(paletteFrame) then paletteFrame:Remove() end

    local C = UI.Colors
    local commands = DAdmin.Port.GetCommands()

    paletteFrame = vgui.Create("EditablePanel")
    paletteFrame:SetSize(460, 380)
    paletteFrame:Center()
    paletteFrame:MakePopup()
    paletteFrame:SetKeyboardInputEnabled(true)
    paletteFrame.Paint = function(_, w, h)
        surface.SetDrawColor(C.bg)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(C.border)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    local hdr = vgui.Create("DPanel", paletteFrame)
    hdr:Dock(TOP)
    hdr:SetTall(24)
    hdr.Paint = function(_, w, h)
        UI.DrawVerticalGradient(0, 0, w, h, C.headerA, C.headerB)
        surface.SetDrawColor(C.borderDark)
        surface.DrawLine(0, h - 1, w, h - 1)
        draw.SimpleText("Command Palette", "DAdmin.Title", 8, h / 2, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local close = vgui.Create("DButton", hdr)
    close:Dock(RIGHT)
    close:SetWide(18)
    close:SetText("x")
    UI.StyleButton(close)
    close.DoClick = function() paletteFrame:Remove() end

    local search = vgui.Create("DTextEntry", paletteFrame)
    search:Dock(TOP)
    search:DockMargin(8, 8, 8, 0)
    search:SetTall(26)
    search:SetPlaceholderText("Type a command name...")
    search:SetFont("DAdmin.Normal")
    UI.StyleTextEntry(search)
    search:RequestFocus()

    local resultList = vgui.Create("DScrollPanel", paletteFrame)
    resultList:Dock(FILL)
    resultList:DockMargin(8, 4, 8, 4)

    local argPanel = vgui.Create("DPanel", paletteFrame)
    argPanel:Dock(BOTTOM)
    argPanel:SetTall(90)
    argPanel:DockMargin(8, 0, 8, 8)
    argPanel.Paint = function(_, w, h)
        surface.SetDrawColor(C.bg2)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(C.border)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end
    argPanel:SetVisible(false)

    local selectedCmd

    local function showRunUI(cmd)
        selectedCmd = cmd
        argPanel:Clear()
        argPanel:SetVisible(true)

        local lbl = vgui.Create("DLabel", argPanel)
        lbl:Dock(TOP)
        lbl:DockMargin(6, 4, 6, 0)
        lbl:SetTall(16)
        lbl:SetFont("DAdmin.Small")
        lbl:SetTextColor(C.green)
        lbl:SetText(cmd.usage or cmd.name)

        local targetEntry = vgui.Create("DTextEntry", argPanel)
        targetEntry:Dock(TOP)
        targetEntry:DockMargin(6, 4, 6, 0)
        targetEntry:SetTall(22)
        targetEntry:SetPlaceholderText("Target / SteamID / @all")
        UI.StyleTextEntry(targetEntry)

        local argsEntry = vgui.Create("DTextEntry", argPanel)
        argsEntry:Dock(TOP)
        argsEntry:DockMargin(6, 4, 6, 0)
        argsEntry:SetTall(22)
        argsEntry:SetPlaceholderText("Extra args / reason / duration")
        UI.StyleTextEntry(argsEntry)

        local run = vgui.Create("DButton", argPanel)
        run:Dock(BOTTOM)
        run:DockMargin(6, 0, 6, 4)
        run:SetTall(22)
        run:SetText("Run")
        UI.StyleButton(run, "primary")
        run.DoClick = function()
            DAdmin.Port.RunCommand(cmd.name, targetEntry:GetValue(), argsEntry:GetValue())
            paletteFrame:Remove()
        end
    end

    local function rebuild()
        resultList:Clear()
        local q = string.Trim(string.lower(search:GetValue() or ""))
        local matched = 0
        for _, cmd in ipairs(commands) do
            if q == "" or string.find(string.lower(cmd.name), q, 1, true) or string.find(string.lower(cmd.desc or ""), q, 1, true) then
                matched = matched + 1
                if matched > 30 then break end
                local row = resultList:Add("DButton")
                row:Dock(TOP)
                row:DockMargin(0, 0, 0, 2)
                row:SetTall(36)
                row:SetText("")
                row.Paint = function(self, w, h)
                    surface.SetDrawColor(self:IsHovered() and C.select or C.bg2)
                    surface.DrawRect(0, 0, w, h)
                    surface.SetDrawColor(C.border)
                    surface.DrawOutlinedRect(0, 0, w, h, 1)
                    draw.SimpleText(cmd.name, "DAdmin.Normal", 8, 10, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                    draw.SimpleText(cmd.desc or "", "DAdmin.Small", 8, 26, C.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                    draw.SimpleText("[" .. (cmd.cat or "admin") .. "]", "DAdmin.Small", w - 8, 10, C.blue, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
                    draw.SimpleText(cmd.perm or "", "DAdmin.Small", w - 8, 26, C.textDark, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
                end
                row.DoClick = function() showRunUI(cmd) end
            end
        end

        if matched == 0 then
            local empty = resultList:Add("DLabel")
            empty:Dock(TOP)
            empty:SetTall(24)
            empty:SetFont("DAdmin.Normal")
            empty:SetTextColor(C.textDark)
            empty:SetText("  No commands found.")
        end
    end

    search.OnValueChange = function() rebuild() end
    rebuild()

    paletteFrame.OnKeyCodePressed = function(_, key)
        if key == KEY_ESCAPE then paletteFrame:Remove() end
    end
end

hook.Add("PlayerBindPress", "DAdmin_CommandPalette", function(ply, bind, pressed)
    if not pressed then return end
    if bind == "gm_showhelp" then
        if DAdmin.HasPermission and DAdmin.HasPermission(LocalPlayer(), "menu") then
            DAdmin.OpenCommandPalette()
            return true
        end
    end
end)
