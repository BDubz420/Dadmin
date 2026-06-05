if SERVER then return end
DAdmin = DAdmin or {}
DAdmin.UI = DAdmin.UI or {}
local UI = DAdmin.UI
local C = UI.Colors

local TABS = {
    { id = "dashboard", label = "Overview", group = "Home", permission = "menu", build = function(parent) DAdmin.BuildDashboardPanel(parent) end },
    { id = "players", label = "Players", group = "Moderation", permission = "menu", build = function(parent) DAdmin.BuildPlayersPanel(parent) end },
    { id = "reports", label = "Reports", group = "Moderation", permission = "reports", build = function(parent) DAdmin.BuildReportsPanel(parent) end },
    { id = "history", label = "History", group = "Moderation", permission = "history", build = function(parent) DAdmin.BuildPlayerHistoryPanel(parent) end },
    { id = "logs", label = "Logs", group = "Moderation", permission = "logs.view", build = function(parent) DAdmin.BuildLogsPanel(parent) end },
    { id = "ranks", label = "Ranks", group = "Configuration", permission = "rank", build = function(parent) DAdmin.BuildRanksPanel(parent) end },
    { id = "permissions", label = "Permissions", group = "Configuration", permission = "permissions.view", build = function(parent) DAdmin.BuildPermissionsPanel(parent) end },
    { id = "safezones", label = "Safezones", group = "Protection", permission = "safezones.view", build = function(parent) DAdmin.BuildSafezonesPanel(parent) end },
    { id = "playtime", label = "Playtime", group = "Protection", permission = "playtime.view", build = function(parent) DAdmin.BuildPlaytimePanel(parent) end },
    { id = "guard", label = "Guard", group = "Protection", permission = "guard", build = function(parent) DAdmin.BuildGuardPanel(parent) end },
    { id = "control", label = "Control", group = "Protection", permission = "guard", build = function(parent) DAdmin.BuildControlPanel(parent) end },
    { id = "commands", label = "Commands", group = "Tools", permission = "menu", build = function(parent) DAdmin.BuildCommandsPanel(parent) end },
    { id = "settings", label = "Settings", group = "Tools", permission = "admin", build = function(parent) DAdmin.BuildSettingsPanel(parent) end },
}

local function canSeeTab(tab)
    if not tab then return false end
    local perm = tostring(tab.permission or "")
    if perm == "" then return true end

    if DAdmin.Port and DAdmin.Port.HasPermission then
        if DAdmin.Port.HasPermission(perm) then return true end
        if perm == "logs.view" and DAdmin.Port.HasPermission("logs") then return true end
        if perm == "permissions.view" and DAdmin.Port.HasPermission("permissions") then return true end
        if perm == "safezones.view" and DAdmin.Port.HasPermission("safezones.manage") then return true end
        if perm == "playtime.view" and DAdmin.Port.HasPermission("playtime.manage") then return true end
        if perm == "guard" and DAdmin.Port.HasPermission("guard.admin") then return true end
    end

    return false
end

local function getVisibleTabs()
    local out = {}
    for _, tab in ipairs(TABS) do
        if canSeeTab(tab) then
            out[#out + 1] = tab
        end
    end
    return out
end

function DAdmin.RefreshCurrentTab()
    if not IsValid(DAdmin.Frame) or not DAdmin.CurrentTab then return end
    for _, tab in ipairs(getVisibleTabs()) do
        if tab.id == DAdmin.CurrentTab then
            tab.build(DAdmin.PageHost)
            break
        end
    end
end

function DAdmin.SwitchTab(tabId)
    if not IsValid(DAdmin.Frame) or not IsValid(DAdmin.PageHost) then return end

    for _, tab in ipairs(getVisibleTabs()) do
        if tab.id == tabId then
            DAdmin.CurrentTab = tabId
            tab.build(DAdmin.PageHost)

            for _, info in ipairs(TABS) do
                if IsValid(info.button) then
                    info.button._variant = info == tab and "active" or nil
                    info.button:InvalidateLayout(true)
                end
            end

            DAdmin.Frame:InvalidateLayout(true)
            return
        end
    end
end

DAdmin.SetActiveTab = DAdmin.SwitchTab

function DAdmin.OpenMenu(defaultTab)
    defaultTab = defaultTab or DAdmin.CurrentTab or "dashboard"
    if IsValid(DAdmin.Frame) then
        DAdmin.Frame:SetVisible(true)
        DAdmin.Frame:MakePopup()
        DAdmin.Frame:Center()
        -- Always route through the central tab controller so dashboard quick
        -- buttons update both content and highlighted tab state.
        DAdmin.SwitchTab(defaultTab)
        if DAdmin.Port and DAdmin.Port.Refresh then DAdmin.Port.Refresh() end
        return
    end

    local frame = vgui.Create("EditablePanel")
    frame:SetSize(math.min(1180, ScrW() - 40), math.min(700, ScrH() - 40))
    frame:Center()
    frame:MakePopup()
    frame:SetKeyboardInputEnabled(true)
    DAdmin.Frame = frame

    frame.Paint = function(_, w, h)
        surface.SetDrawColor(C.bg)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(Color(74, 78, 94))
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    local title = vgui.Create("DPanel", frame)
    title:Dock(TOP)
    title:SetTall(24)
    local dragX, dragY, dragging
    title.OnMousePressed = function(_, code)
        if code == MOUSE_LEFT then
            dragX, dragY = gui.MouseX() - frame:GetX(), gui.MouseY() - frame:GetY()
            dragging = true
            title:MouseCapture(true)
        end
    end
    title.OnMouseReleased = function(_, code)
        if code == MOUSE_LEFT then
            dragging = false
            title:MouseCapture(false)
        end
    end
    title.Think = function()
        if dragging and dragX then
            frame:SetPos(gui.MouseX() - dragX, gui.MouseY() - dragY)
        end
    end
    title.Paint = function(_, w, h)
        UI.DrawVerticalGradient(0, 0, w, h, Color(58,63,82), Color(40,44,58))
        surface.SetDrawColor(C.borderDark)
        surface.DrawLine(0, h - 1, w, h - 1)
        surface.SetDrawColor(C.blue)
        surface.DrawRect(5, 5, 13, 13)
        draw.SimpleText("D", "DAdmin.Small", 11, 11, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("DAdmin", "DAdmin.Normal", 24, h / 2, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Server Control Panel", "DAdmin.Tiny", 86, h / 2, C.textDark, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local function hideFrame()
        frame:SetVisible(false)
    end

    local btnClose = vgui.Create("DButton", title)
    btnClose:Dock(RIGHT) btnClose:SetWide(18) btnClose:SetText("x") UI.StyleButton(btnClose) btnClose.DoClick = hideFrame
    local btnMax = vgui.Create("DButton", title)
    btnMax:Dock(RIGHT) btnMax:SetWide(18) btnMax:SetText("□") UI.StyleButton(btnMax)
    btnMax.DoClick = function()
        if frame:GetWide() >= ScrW() - 10 then
            frame:SetSize(math.min(1180, ScrW() - 40), math.min(700, ScrH() - 40))
            frame:Center()
        else
            frame:SetPos(5, 5)
            frame:SetSize(ScrW() - 10, ScrH() - 10)
        end
    end
    local btnMin = vgui.Create("DButton", title)
    btnMin:Dock(RIGHT) btnMin:SetWide(18) btnMin:SetText("_") UI.StyleButton(btnMin) btnMin.DoClick = hideFrame

    local tabsBar = vgui.Create("DPanel", frame)
    tabsBar:Dock(TOP)
    tabsBar:SetTall(34)
    tabsBar.Paint = function(_, w, h)
        surface.SetDrawColor(34, 38, 46, 255)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(C.borderDark)
        surface.DrawLine(0, h - 1, w, h - 1)
    end

    local footer = vgui.Create("DPanel", frame)
    footer:Dock(BOTTOM)
    footer:SetTall(20)
    footer.Paint = function(_, w, h)
        local status = DAdmin.Port.GetServer()
        UI.DrawVerticalGradient(0, 0, w, h, Color(30,33,48), Color(22,24,32))
        surface.SetDrawColor(C.borderDark)
        surface.DrawLine(0, 0, w, 0)
        draw.SimpleText("*", "DAdmin.Small", 7, h / 2, C.green, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Connected", "DAdmin.Small", 18, h / 2, Color(136,136,136), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("|", "DAdmin.Small", 82, h / 2, Color(60,64,78), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Map:", "DAdmin.Small", 96, h / 2, C.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(tostring(status.map or game.GetMap()), "DAdmin.Small", 126, h / 2, C.blue, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Players: " .. tostring(status.players or 0) .. "/" .. tostring(status.maxPlayers or game.MaxPlayers()), "DAdmin.Small", w * 0.42, h / 2, C.blue, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Ping: " .. tostring(status.ping or 0) .. "ms", "DAdmin.Small", w * 0.58, h / 2, C.green, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("DAdmin " .. tostring(status.version or "v2.2.0"), "DAdmin.Small", w - 10, h / 2, Color(68,72,88), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end

    local content = vgui.Create("DPanel", frame)
    content:Dock(FILL)
    content:DockMargin(5, 5, 5, 5)
    content.Paint = nil

    local pageHost = vgui.Create("DPanel", content)
    pageHost:Dock(FILL)
    pageHost.Paint = nil
    DAdmin.PageHost = pageHost

    local function openTab(tab)
        DAdmin.SwitchTab(tab.id)
    end

    local visibleTabs = getVisibleTabs()
    if #visibleTabs == 0 then
        visibleTabs = { TABS[1] }
    end

    if not canSeeTab((function()
        for _, tab in ipairs(visibleTabs) do
            if tab.id == defaultTab then return tab end
        end
    end)()) then
        defaultTab = visibleTabs[1].id
    end

    local paletteBtn = vgui.Create("DButton", tabsBar)
    paletteBtn:Dock(RIGHT)
    paletteBtn:DockMargin(0, 5, 6, 5)
    paletteBtn:SetWide(116)
    paletteBtn:SetText("Command Palette")
    UI.StyleButton(paletteBtn)
    paletteBtn.DoClick = function()
        DAdmin.OpenCommandPalette()
    end

    local currentGroup = nil
    for _, tab in ipairs(visibleTabs) do
        if tab.group ~= currentGroup then
            currentGroup = tab.group
            local groupLabel = currentGroup
            local sep = vgui.Create("DPanel", tabsBar)
            sep:Dock(LEFT)
            sep:DockMargin(8, 0, 6, 0)
            sep:SetWide(58)
            sep.Paint = function(_, w, h)
                draw.SimpleText(string.upper(tostring(groupLabel or "")), "DAdmin.Tiny", 0, h / 2, C.textDark, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end
        end

        local btn = vgui.Create("DButton", tabsBar)
        btn:Dock(LEFT)
        btn:DockMargin(0, 5, 4, 5)
        surface.SetFont("DAdmin.Small")
        local tw = surface.GetTextSize(tab.label)
        btn:SetWide(math.Clamp(tw + 24, 60, 112))
        btn:SetText(tab.label)
        UI.StyleButton(btn, tab.id == defaultTab and "active" or nil)
        btn.DoClick = function() openTab(tab) end
        tab.button = btn
    end

    for _, tab in ipairs(visibleTabs) do
        if tab.id == defaultTab then openTab(tab) break end
    end
    if DAdmin.Port and DAdmin.Port.Refresh then DAdmin.Port.Refresh() end
    frame.OnRemove = function() end
end
