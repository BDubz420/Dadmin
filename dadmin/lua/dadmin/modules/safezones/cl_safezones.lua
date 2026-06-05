if SERVER then return end

DAdmin = DAdmin or {}
DAdmin.SafeZonesClient = DAdmin.SafeZonesClient or {}
local SZ = DAdmin.SafeZonesClient

SZ.zones = SZ.zones or {}
SZ.config = SZ.config or {}
SZ.inside = SZ.inside or nil
SZ.selected = SZ.selected or nil
SZ.dragCorner = SZ.dragCorner or nil
SZ.cursor = SZ.cursor or false
SZ.editor = SZ.editor or nil

local function UI()
    return DAdmin.UI or {}
end

local function colors()
    return (DAdmin.UI and DAdmin.UI.Colors) or {
        bg = Color(24, 27, 36), panel = Color(18, 20, 28), border = Color(65, 72, 96),
        text = Color(235, 238, 245), textDim = Color(155, 160, 178), blue = Color(74, 144, 217),
        red = Color(210, 80, 80), green = Color(90, 190, 120)
    }
end

local function styleButton(btn, variant)
    if UI().StyleButton then UI().StyleButton(btn, variant) return end
    btn:SetTextColor(color_white)
    btn.Paint = function(_, w, h)
        local c = colors()
        surface.SetDrawColor(variant == "danger" and c.red or variant == "primary" and c.blue or c.panel)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(c.border)
        surface.DrawOutlinedRect(0, 0, w, h)
    end
end

local function styleText(entry)
    if UI().StyleTextEntry then UI().StyleTextEntry(entry) return end
    entry:SetTextColor(colors().text)
    entry:SetPaintBackground(false)
    entry.Paint = function(s, w, h)
        surface.SetDrawColor(12, 14, 20, 240)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(colors().border)
        surface.DrawOutlinedRect(0, 0, w, h)
        s:DrawTextEntryText(colors().text, colors().blue, colors().text)
    end
end

local function reqZones()
    net.Start("DAdmin_SafeZones_Request")
    net.SendToServer()
end

local function vtab(v)
    return { x = math.Round(v.x, 2), y = math.Round(v.y, 2), z = math.Round(v.z, 2) }
end

local function vec(t)
    if isvector(t) then return t end
    t = istable(t) and t or {}
    return Vector(tonumber(t.x or 0) or 0, tonumber(t.y or 0) or 0, tonumber(t.z or 0) or 0)
end

local function defaultSettings()
    return table.Copy((SZ.config or {}).safezone_default_settings or {
        god = true,
        block_damage = true,
        strip_weapons = false,
        prevent_fire = true,
        prevent_props = true,
        prevent_sents = true,
        prevent_vehicles = true,
        prevent_npcs = true,
        freeze_props = false,
        no_collide_props = false,
        prevent_physgun = false,
        show_ui = true,
        hud_color = "4A90D9"
    })
end

local function makeDefaultZone()
    local tr = LocalPlayer():GetEyeTrace()
    local base = tr.Hit and tr.HitPos or LocalPlayer():GetPos()
    local size = 160

    return {
        id = "new_" .. os.time(),
        name = "Safe Zone",
        color = (SZ.config or {}).safezone_ui_color or "4A90D9",
        height = tonumber((SZ.config or {}).safezone_default_height or 160) or 160,
        corners = {
            vtab(base + Vector(-size, -size, 0)),
            vtab(base + Vector( size, -size, 0)),
            vtab(base + Vector( size,  size, 0)),
            vtab(base + Vector(-size,  size, 0))
        },
        settings = defaultSettings()
    }
end

local function currentZone()
    if not SZ.selected then return nil end
    return SZ.zones and SZ.zones[SZ.selected]
end

local function saveZone(z)
    if not z then return end
    net.Start("DAdmin_SafeZones_Save")
        net.WriteTable(z)
    net.SendToServer()
end

local function deleteZone(id)
    if not id then return end
    net.Start("DAdmin_SafeZones_Delete")
        net.WriteString(tostring(id))
    net.SendToServer()
end

net.Receive("DAdmin_SafeZones_Send", function()
    local data = net.ReadTable() or {}
    SZ.zones = data.zones or {}
    SZ.config = data.config or {}
    if SZ.selected and not SZ.zones[SZ.selected] then SZ.selected = nil end
    if IsValid(SZ.editor) and SZ.editor.RebuildAll then SZ.editor:RebuildAll() end
    if isfunction(SZ._panelRefreshHook) then SZ._panelRefreshHook() end
end)

net.Receive("DAdmin_SafeZones_Inside", function()
    local data = net.ReadTable() or {}
    SZ.inside = data.id and data or nil
end)

net.Receive("DAdmin_SafeZones_Message", function()
    local msg = net.ReadString()
    if chat and msg ~= "" then chat.AddText(Color(74,144,217), "[DAdmin Safezones] ", color_white, msg) end
end)

local function hexColor(hex, fallback)
    if DAdmin.HexColor then return DAdmin.HexColor(hex, fallback) end
    fallback = fallback or Color(74,144,217)
    hex = tostring(hex or "")
    if #hex < 6 then return fallback end
    return Color(tonumber("0x" .. string.sub(hex, 1, 2)) or fallback.r, tonumber("0x" .. string.sub(hex, 3, 4)) or fallback.g, tonumber("0x" .. string.sub(hex, 5, 6)) or fallback.b, 255)
end

local function screenPoint(v)
    local p = vec(v):ToScreen()
    return p.x, p.y, p.visible
end

hook.Add("PlayerButtonDown", "DAdminSafeZones_F3Cursor", function(ply, key)
    if ply ~= LocalPlayer() or key ~= KEY_F3 then return end
    if not IsValid(SZ.editor) then return end
    SZ.cursor = not SZ.cursor
    gui.EnableScreenClicker(SZ.cursor)
    if IsValid(SZ.editor) and SZ.editor.RefreshCursorState then SZ.editor:RefreshCursorState() end
end)

hook.Add("Think", "DAdminSafeZones_DragCorners", function()
    if not IsValid(SZ.editor) or not SZ.cursor then return end
    local z = currentZone()
    if not z then return end

    if input.IsMouseDown(MOUSE_LEFT) and not SZ.mouseHeld then
        SZ.mouseHeld = true
        local mx, my = gui.MousePos()
        for i = 1, 4 do
            local sx, sy, vis = screenPoint(z.corners[i])
            if vis and math.abs(mx - sx) <= 18 and math.abs(my - sy) <= 18 then
                SZ.dragCorner = i
                break
            end
        end
    elseif not input.IsMouseDown(MOUSE_LEFT) then
        SZ.mouseHeld = false
        SZ.dragCorner = nil
    end

    if SZ.dragCorner then
        local tr = LocalPlayer():GetEyeTrace()
        if tr.Hit then
            local old = vec(z.corners[SZ.dragCorner])
            z.corners[SZ.dragCorner] = vtab(Vector(tr.HitPos.x, tr.HitPos.y, old.z))
            if IsValid(SZ.editor) and SZ.editor.RefreshCornerReadout then SZ.editor:RefreshCornerReadout() end
        end
    end
end)

hook.Add("PostDrawTranslucentRenderables", "DAdminSafeZones_DrawWorld", function()
    if not IsValid(SZ.editor) and not SZ.inside then return end

    for id, z in pairs(SZ.zones or {}) do
        local drawIt = IsValid(SZ.editor) or (SZ.inside and SZ.inside.id == id)
        if drawIt then
            local col = hexColor((z.settings or {}).hud_color or z.color, Color(74,144,217))
            local corners = z.corners or {}
            local h = tonumber(z.height or 160) or 160
            render.SetColorMaterial()

            for i = 1, 4 do
                local a = vec(corners[i])
                local b = vec(corners[(i % 4) + 1])
                render.DrawLine(a, b, col, true)
                render.DrawLine(a + Vector(0,0,h), b + Vector(0,0,h), col, true)
                render.DrawLine(a, a + Vector(0,0,h), col, true)
                render.DrawSphere(a, id == SZ.selected and 8 or 5, 12, 12, col)
                render.DrawSphere(a + Vector(0,0,h), 4, 8, 8, col)
            end
        end
    end
end)

hook.Add("HUDPaint", "DAdminSafeZones_HUD", function()
    local c = colors()

    if SZ.inside and (SZ.inside.settings or {}).show_ui ~= false and (SZ.config or {}).safezone_ui_enabled ~= false then
        local col = hexColor((SZ.inside.settings or {}).hud_color or SZ.inside.color or "4A90D9", c.blue)
        local text = tostring(SZ.inside.name or "Safe Zone")
        surface.SetFont("DAdmin.Title")
        local tw = surface.GetTextSize(text)
        local w, h = math.max(210, tw + 42), 34
        local x, y = ScrW() / 2 - w / 2, 72

        surface.SetDrawColor(18, 20, 28, 225)
        surface.DrawRect(x, y, w, h)
        surface.SetDrawColor(col)
        surface.DrawOutlinedRect(x, y, w, h, 1)
        draw.SimpleText("SAFE ZONE", "DAdmin.Small", x + 10, y + 8, col, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(text, "DAdmin.Title", x + 10, y + 22, c.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    if not IsValid(SZ.editor) then return end
    local z = currentZone()
    if not z then return end

    for i = 1, 4 do
        local sx, sy, vis = screenPoint(z.corners[i])
        if vis then
            surface.SetDrawColor(18, 20, 28, 230)
            surface.DrawRect(sx - 11, sy - 11, 22, 22)
            surface.SetDrawColor(i == SZ.dragCorner and c.green or c.blue)
            surface.DrawOutlinedRect(sx - 11, sy - 11, 22, 22, 1)
            draw.SimpleText(tostring(i), "DAdmin.Small", sx, sy, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end
end)

local function makeLabel(parent, text, tall)
    local c = colors()
    local l = vgui.Create("DLabel", parent)
    l:Dock(TOP)
    l:DockMargin(8, 5, 8, 0)
    l:SetTall(tall or 18)
    l:SetFont("DAdmin.Small")
    l:SetTextColor(c.textDim)
    l:SetText(text)
    return l
end

local toggleNames = {
    { "god", "Player god mode" },
    { "block_damage", "Block damage taken" },
    { "strip_weapons", "Strip weapons inside" },
    { "prevent_fire", "Block weapon damage from inside" },
    { "prevent_props", "Block props/ragdolls/effects" },
    { "prevent_sents", "Block SENT spawning" },
    { "prevent_vehicles", "Block vehicles" },
    { "prevent_npcs", "Block NPCs" },
    { "freeze_props", "Freeze spawned props" },
    { "no_collide_props", "No-collide spawned props" },
    { "prevent_physgun", "Block physgun pickup" },
    { "show_ui", "Show player safezone UI" }
}

function DAdmin.OpenSafeZoneEditor()
    reqZones()

    if IsValid(SZ.editor) then
        SZ.editor:SetVisible(true)
        SZ.editor:MakePopup()
        SZ.editor:SetKeyboardInputEnabled(false)
        SZ.editor:SetPos(14, math.floor(ScrH() / 2 - SZ.editor:GetTall() / 2))
        return
    end

    local c = colors()
    local frame = vgui.Create("DFrame")
    SZ.editor = frame
    frame:SetTitle("")
    frame:SetSize(360, math.min(720, ScrH() - 60))
    frame:SetPos(14, math.floor(ScrH() / 2 - frame:GetTall() / 2))
    frame:ShowCloseButton(false)
    frame:SetDraggable(false)
    frame:MakePopup()
    frame:SetKeyboardInputEnabled(false)

    frame.Paint = function(_, w, h)
        surface.SetDrawColor(c.bg)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(c.border)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        surface.SetDrawColor(c.blue)
        surface.DrawRect(0, 0, 4, h)
        draw.SimpleText("DAdmin Safezone Editor", "DAdmin.Title", 14, 18, c.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local close = vgui.Create("DButton", frame)
    close:SetText("×")
    close:SetSize(24, 24)
    close:SetPos(frame:GetWide() - 30, 6)
    styleButton(close, "danger")
    close.DoClick = function()
        SZ.cursor = false
        gui.EnableScreenClicker(false)
        frame:Remove()
        SZ.editor = nil
    end

    local cursorState = vgui.Create("DButton", frame)
    cursorState:Dock(TOP)
    cursorState:DockMargin(12, 34, 12, 0)
    cursorState:SetTall(28)
    styleButton(cursorState, "primary")

    function frame:RefreshCursorState()
        cursorState:SetText(SZ.cursor and "F3 cursor: ON - click numbered corner handles" or "F3 cursor: OFF - press F3 while editor is open")
    end
    cursorState.DoClick = function()
        SZ.cursor = not SZ.cursor
        gui.EnableScreenClicker(SZ.cursor)
        frame:RefreshCursorState()
    end
    frame:RefreshCursorState()

    local body = vgui.Create("DPanel", frame)
    body:Dock(FILL)
    body:DockMargin(8, 8, 8, 8)
    body.Paint = nil

    local list = vgui.Create("DScrollPanel", body)
    list:Dock(LEFT)
    list:SetWide(132)
    list:DockMargin(0, 0, 8, 0)

    local form = vgui.Create("DScrollPanel", body)
    form:Dock(FILL)

    function frame:RefreshCornerReadout()
        if IsValid(frame.cornerReadout) then
            local z = currentZone()
            if not z then frame.cornerReadout:SetText("") return end
            local lines = {}
            for i = 1, 4 do
                local p = vec(z.corners[i])
                lines[#lines + 1] = string.format("C%d: %.0f, %.0f, %.0f", i, p.x, p.y, p.z)
            end
            frame.cornerReadout:SetText(table.concat(lines, "\n"))
        end
    end

    local function rebuildForm()
        form:Clear()
        local z = currentZone()

        if not z then
            makeLabel(form, "Create or select a zone. This editor stays pinned to the left side of your screen. Press F3 to free your cursor, then drag the numbered corner handles in world view.", 66)
            return
        end

        makeLabel(form, "Zone name")
        local name = vgui.Create("DTextEntry", form)
        name:Dock(TOP)
        name:DockMargin(8, 0, 8, 0)
        name:SetTall(26)
        name:SetText(z.name or "")
        styleText(name)
        name.OnChange = function(s) z.name = s:GetValue() end

        makeLabel(form, "HUD color hex")
        local colorEntry = vgui.Create("DTextEntry", form)
        colorEntry:Dock(TOP)
        colorEntry:DockMargin(8, 0, 8, 0)
        colorEntry:SetTall(26)
        colorEntry:SetText((z.settings or {}).hud_color or z.color or "4A90D9")
        styleText(colorEntry)
        colorEntry.OnChange = function(s)
            z.settings = z.settings or {}
            z.settings.hud_color = s:GetValue()
            z.color = s:GetValue()
        end

        makeLabel(form, "Height")
        local height = vgui.Create("DNumSlider", form)
        height:Dock(TOP)
        height:DockMargin(4, 0, 8, 0)
        height:SetTall(36)
        height:SetText("")
        height:SetMin(8)
        height:SetMax(4096)
        height:SetDecimals(0)
        height:SetValue(tonumber(z.height or 160) or 160)
        height.OnValueChanged = function(_, val) z.height = math.floor(val) end

        frame.cornerReadout = makeLabel(form, "", 62)
        frame:RefreshCornerReadout()

        makeLabel(form, "Zone behavior toggles")
        for _, info in ipairs(toggleNames) do
            local key, label = info[1], info[2]
            local b = vgui.Create("DButton", form)
            b:Dock(TOP)
            b:DockMargin(8, 3, 8, 0)
            b:SetTall(24)
            styleButton(b)

            local function refresh()
                z.settings = z.settings or {}
                b:SetText((z.settings[key] and "ON  " or "OFF ") .. label)
            end

            b.DoClick = function()
                z.settings = z.settings or {}
                z.settings[key] = not z.settings[key]
                refresh()
            end
            refresh()
        end

        local save = vgui.Create("DButton", form)
        save:Dock(TOP)
        save:DockMargin(8, 10, 8, 0)
        save:SetTall(28)
        save:SetText("Save Zone")
        styleButton(save, "primary")
        save.DoClick = function() saveZone(z) end

        local del = vgui.Create("DButton", form)
        del:Dock(TOP)
        del:DockMargin(8, 4, 8, 0)
        del:SetTall(28)
        del:SetText("Delete Zone")
        styleButton(del, "danger")
        del.DoClick = function()
            local id = z.id
            SZ.selected = nil
            deleteZone(id)
            timer.Simple(0.2, reqZones)
        end
    end

    local function rebuildList()
        list:Clear()

        local create = vgui.Create("DButton", list)
        create:Dock(TOP)
        create:DockMargin(0, 0, 0, 5)
        create:SetTall(30)
        create:SetText("+ New")
        styleButton(create, "primary")
        create.DoClick = function()
            local z = makeDefaultZone()
            SZ.zones[z.id] = z
            SZ.selected = z.id
            frame:RebuildAll()
        end

        local keys = {}
        for id in pairs(SZ.zones or {}) do keys[#keys + 1] = id end
        table.sort(keys, function(a, b)
            return tostring((SZ.zones[a] or {}).name or a) < tostring((SZ.zones[b] or {}).name or b)
        end)

        for _, id in ipairs(keys) do
            local z = SZ.zones[id]
            local b = vgui.Create("DButton", list)
            b:Dock(TOP)
            b:DockMargin(0, 0, 0, 4)
            b:SetTall(28)
            b:SetText(string.sub(tostring(z.name or id), 1, 18))
            styleButton(b, SZ.selected == id and "primary" or nil)
            b.DoClick = function()
                SZ.selected = id
                frame:RebuildAll()
            end
        end
    end

    function frame:RebuildAll()
        rebuildList()
        rebuildForm()
        frame:RefreshCursorState()
    end

    frame:RebuildAll()
end

concommand.Add("dadmin_safezone_editor", function()
    DAdmin.OpenSafeZoneEditor()
end)

function DAdmin.SafeZonesOpenEditor()
    DAdmin.OpenSafeZoneEditor()
end

function DAdmin.BuildSafezonesPanel(parent)
    parent:Clear()
    reqZones()

    local c = colors()
    local shell = vgui.Create("DPanel", parent)
    shell:Dock(FILL)
    shell.Paint = nil

    local top = vgui.Create("DPanel", shell)
    top:Dock(TOP)
    top:SetTall(72)
    top.Paint = function(_, w, h)
        surface.SetDrawColor(18,20,28,230)
        surface.DrawRect(0,0,w,h)
        surface.SetDrawColor(c.border)
        surface.DrawOutlinedRect(0,0,w,h,1)
        draw.SimpleText("Safezones", "DAdmin.Title", 12, 16, c.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Create, edit, and enforce per-zone player / prop / weapon behavior. Open the pinned editor for corner and height editing.", "DAdmin.Small", 12, 42, c.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local open = vgui.Create("DButton", top)
    open:Dock(RIGHT)
    open:DockMargin(8, 20, 12, 20)
    open:SetWide(150)
    open:SetText("Open Editor")
    styleButton(open, "primary")
    open.DoClick = DAdmin.OpenSafeZoneEditor

    local refresh = vgui.Create("DButton", top)
    refresh:Dock(RIGHT)
    refresh:DockMargin(8, 20, 0, 20)
    refresh:SetWide(90)
    refresh:SetText("Refresh")
    styleButton(refresh)
    refresh.DoClick = reqZones

    local list = vgui.Create("DScrollPanel", shell)
    list:Dock(FILL)
    list:DockMargin(0, 8, 0, 0)

    local function rebuild()
        list:Clear()

        local keys = {}
        for id in pairs(SZ.zones or {}) do keys[#keys + 1] = id end
        table.sort(keys, function(a, b)
            return tostring((SZ.zones[a] or {}).name or a) < tostring((SZ.zones[b] or {}).name or b)
        end)

        if #keys == 0 then
            makeLabel(list, "No safezones have been created yet. Use Open Editor > New.", 28)
            return
        end

        for _, id in ipairs(keys) do
            local z = SZ.zones[id]
            local row = vgui.Create("DPanel", list)
            row:Dock(TOP)
            row:DockMargin(0, 0, 0, 5)
            row:SetTall(54)
            row.Paint = function(_, w, h)
                surface.SetDrawColor(18,20,28,230)
                surface.DrawRect(0,0,w,h)
                surface.SetDrawColor(c.border)
                surface.DrawOutlinedRect(0,0,w,h,1)
                draw.SimpleText(tostring(z.name or id), "DAdmin.Title", 10, 14, c.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                draw.SimpleText("Height: " .. tostring(z.height or 160) .. " | ID: " .. tostring(id), "DAdmin.Small", 10, 34, c.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end

            local edit = vgui.Create("DButton", row)
            edit:Dock(RIGHT)
            edit:DockMargin(5, 12, 8, 12)
            edit:SetWide(80)
            edit:SetText("Edit")
            styleButton(edit, "primary")
            edit.DoClick = function()
                SZ.selected = id
                DAdmin.OpenSafeZoneEditor()
            end
        end
    end

    timer.Simple(0.25, function()
        if IsValid(list) then rebuild() end
    end)

    local oldReceive = SZ._panelRefreshHook
    SZ._panelRefreshHook = function()
        if IsValid(list) then rebuild() end
    end
end
