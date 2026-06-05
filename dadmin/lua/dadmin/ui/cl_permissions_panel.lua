if SERVER then return end
local UI = DAdmin.UI
local C = UI.Colors

local function contains(tbl, val)
    for _, v in ipairs(tbl or {}) do if v == val then return true end end
    return false
end

local function togglePerm(tbl, val)
    for i, v in ipairs(tbl) do
        if v == val then table.remove(tbl, i) return false end
    end
    tbl[#tbl + 1] = val
    return true
end

local function safeColor(col, fallback)
    if istable(col) and col.r then return col end
    return fallback or C.text
end

function DAdmin.BuildPermissionsPanel(parent)
    parent:Clear()

    local groups = DAdmin.Port.GetPermissionGroups() or {}
    local cats = DAdmin.Port.GetPermissionCategories() or {}
    local perms = table.Copy(DAdmin.Port.GetPermissionMatrix() or {})

    local dirty = false
    local collapsed = {}
    local filterText = ""

    local shell = vgui.Create("DPanel", parent)
    shell:Dock(FILL)
    shell.Paint = nil

    local toolbar = vgui.Create("DPanel", shell)
    toolbar:Dock(TOP)
    toolbar:SetTall(28)
    toolbar.Paint = nil

    local filter = vgui.Create("DTextEntry", toolbar)
    filter:Dock(LEFT)
    filter:SetWide(220)
    filter:SetPlaceholderText("Filter permissions...")
    UI.StyleTextEntry(filter)

    local hint = vgui.Create("DLabel", toolbar)
    hint:Dock(FILL)
    hint:DockMargin(10, 0, 0, 0)
    hint:SetFont("DAdmin.Small")
    hint:SetTextColor(C.textDim)
    hint:SetText("| Click checkboxes to toggle permissions per group.")
    hint:SetContentAlignment(4)

    local save = vgui.Create("DButton", toolbar)
    save:Dock(RIGHT)
    save:DockMargin(6, 2, 0, 2)
    save:SetWide(92)
    save:SetText("Save Changes")
    UI.StyleButton(save, "primary")

    local status = vgui.Create("DLabel", toolbar)
    status:Dock(RIGHT)
    status:DockMargin(0, 0, 6, 0)
    status:SetWide(110)
    status:SetFont("DAdmin.Small")
    status:SetTextColor(C.textDark)
    status:SetContentAlignment(6)
    status:SetText("")

    local header = vgui.Create("DPanel", shell)
    header:Dock(TOP)
    header:SetTall(44)
    header:DockMargin(0, 5, 0, 0)

    local body = vgui.Create("DScrollPanel", shell)
    body:Dock(FILL)
    body:DockMargin(0, 0, 0, 0)

    local legend = vgui.Create("DPanel", shell)
    legend:Dock(BOTTOM)
    legend:SetTall(22)

    local function markDirty()
        dirty = true
        status:SetText("Unsaved")
        status:SetTextColor(C.yellow)
    end

    local function saveMatrix()
        DAdmin._skipNextRefresh = true
        DAdmin.Port.UIAction("save_permissions", { matrix = perms })
        dirty = false
        status:SetText("Saved")
        status:SetTextColor(C.green)
        timer.Simple(2, function()
            if IsValid(status) and not dirty then status:SetText("") end
        end)
    end

    save.DoClick = saveMatrix

    local function layoutMetrics(w)
        local groupCount = math.max(#groups, 1)
        local permW = math.Clamp(math.floor(w * 0.28), 230, 310)
        local cellW = math.max(78, math.floor((w - permW) / groupCount))
        return permW, cellW
    end

    header.Paint = function(_, w, h)
        local permW, cellW = layoutMetrics(w)
        surface.SetDrawColor(26, 29, 38, 255)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(C.border)
        surface.DrawOutlinedRect(0, 0, w, h, 1)

        draw.SimpleText("PERMISSION", "DAdmin.Small", 10, h / 2, C.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

        for gi, g in ipairs(groups) do
            local x = permW + (gi - 1) * cellW
            local color = safeColor(g.color, C.text)
            surface.SetDrawColor(35, 38, 48, 180)
            surface.DrawRect(x, 0, cellW, h)
            surface.SetDrawColor(C.border)
            surface.DrawLine(x, 0, x, h)

            draw.SimpleText(g.label or g.id or ("Group " .. gi), "DAdmin.Small", x + cellW / 2, 13, color, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            draw.SimpleText("+ all", "DAdmin.Small", x + cellW / 2 - 16, 31, C.green, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            draw.SimpleText("- none", "DAdmin.Small", x + cellW / 2 + 24, 31, C.red, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end

    header.OnMousePressed = function(_, code)
        if code ~= MOUSE_LEFT then return end
        local mx = header:CursorPos()
        local permW, cellW = layoutMetrics(header:GetWide())
        if mx < permW then return end
        local gi = math.floor((mx - permW) / cellW) + 1
        local g = groups[gi]
        if not g then return end

        local localX = mx - (permW + (gi - 1) * cellW)
        perms[g.id] = perms[g.id] or {}

        if localX < cellW / 2 then
            for _, cat in ipairs(cats) do
                for _, p in ipairs(cat.perms or {}) do
                    if not contains(perms[g.id], p.id) then perms[g.id][#perms[g.id] + 1] = p.id end
                end
            end
        else
            perms[g.id] = {}
        end

        markDirty()
        body:InvalidateLayout(true)
    end

    legend.Paint = function(_, w, h)
        surface.SetDrawColor(26, 29, 38, 255)
        surface.DrawRect(0, 0, w, h)
        local x = 8
        draw.SimpleText("Groups:", "DAdmin.Small", x, h / 2, C.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        x = x + 52
        for _, g in ipairs(groups) do
            local color = safeColor(g.color, C.text)
            surface.SetDrawColor(color)
            surface.DrawRect(x, h / 2 - 3, 6, 6)
            draw.SimpleText(g.label or g.id, "DAdmin.Small", x + 10, h / 2, color, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            x = x + 10 + surface.GetTextSize(g.label or g.id) + 14
        end
    end

    local function addCheckCell(row, g, perm)
        local cell = vgui.Create("DButton", row)
        cell:Dock(LEFT)
        cell:SetText("")
        cell.Paint = function(self, w, h)
            local active = contains(perms[g.id] or {}, perm.id)
            local color = safeColor(g.color, C.text)

            surface.SetDrawColor(active and Color(color.r, color.g, color.b, 18) or Color(18, 20, 28, 0))
            surface.DrawRect(0, 0, w, h)
            surface.SetDrawColor(C.border)
            surface.DrawLine(0, 0, 0, h)

            local box = 14
            local bx, by = math.floor(w / 2 - box / 2), math.floor(h / 2 - box / 2)
            surface.SetDrawColor(active and color or C.border)
            surface.DrawOutlinedRect(bx, by, box, box, 1)
            if active then
                surface.SetDrawColor(color.r, color.g, color.b, 45)
                surface.DrawRect(bx + 1, by + 1, box - 2, box - 2)
                draw.SimpleText("✓", "DAdmin.Small", w / 2, h / 2 - 1, color, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
        end
        cell.DoClick = function()
            perms[g.id] = perms[g.id] or {}
            togglePerm(perms[g.id], perm.id)
            markDirty()
        end
        return cell
    end

    local function buildGrid()
        body:Clear()

        local canvas = body:GetCanvas()
        local groupCount = math.max(#groups, 1)

        canvas.PerformLayout = function(s, w, h)
            local permW, cellW = layoutMetrics(w)
            for _, row in ipairs(s:GetChildren()) do
                if IsValid(row) and row._permissionRow then
                    local cells = row._cells or {}
                    for _, cell in ipairs(cells) do
                        if IsValid(cell) then cell:SetWide(cellW) end
                    end
                    row._permWidth = permW
                end
            end
        end

        for ci, cat in ipairs(cats) do
            local visiblePerms = {}
            for _, perm in ipairs(cat.perms or {}) do
                local hay = string.lower(tostring(perm.label or "") .. " " .. tostring(perm.id or "") .. " " .. tostring(perm.usage or ""))
                if filterText == "" or string.find(hay, filterText, 1, true) then
                    visiblePerms[#visiblePerms + 1] = perm
                end
            end
            if #visiblePerms == 0 then continue end

            local catRow = body:Add("DButton")
            catRow:Dock(TOP)
            catRow:SetTall(24)
            catRow:SetText("")
            catRow.Paint = function(_, w, h)
                surface.SetDrawColor(30, 32, 48, 255)
                surface.DrawRect(0, 0, w, h)
                surface.SetDrawColor(C.borderDark)
                surface.DrawLine(0, h - 1, w, h - 1)
                draw.SimpleText((collapsed[ci] and "▶ " or "▼ ") .. string.upper(cat.name or "Category") .. " (" .. tostring(#visiblePerms) .. ")",
                    "DAdmin.Small", 10, h / 2, C.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end
            catRow.DoClick = function()
                collapsed[ci] = not collapsed[ci]
                buildGrid()
            end

            if not collapsed[ci] then
                for _, perm in ipairs(visiblePerms) do
                    local row = body:Add("DPanel")
                    row:Dock(TOP)
                    row:SetTall(46)
                    row._permissionRow = true
                    row._cells = {}

                    local label = vgui.Create("DPanel", row)
                    label:Dock(LEFT)
                    label.Paint = function(_, w, h)
                        surface.SetDrawColor(C.bg2)
                        surface.DrawRect(0, 0, w, h)
                        draw.SimpleText(perm.label or perm.id, "DAdmin.Small", 10, 12, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                        draw.SimpleText(perm.id or "", "DAdmin.Small", 10, 26, C.textDark, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                        if perm.usage and perm.usage ~= "" then
                            draw.SimpleText(tostring(perm.usage), "DAdmin.Small", 10, 39, C.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                        end
                    end

                    row.PerformLayout = function(s, w, h)
                        local permW, cellW = layoutMetrics(w)
                        label:SetWide(permW)
                        for _, cell in ipairs(s._cells or {}) do
                            if IsValid(cell) then cell:SetWide(cellW) end
                        end
                    end

                    row.Paint = function(_, w, h)
                        surface.SetDrawColor(C.bg2)
                        surface.DrawRect(0, 0, w, h)
                        surface.SetDrawColor(C.borderDark)
                        surface.DrawLine(0, h - 1, w, h - 1)
                    end

                    for _, g in ipairs(groups) do
                        perms[g.id] = perms[g.id] or {}
                        local cell = addCheckCell(row, g, perm)
                        row._cells[#row._cells + 1] = cell
                    end
                end
            end
        end
    end

    filter.OnValueChange = function(_, val)
        filterText = string.lower(string.Trim(val or ""))
        buildGrid()
    end

    buildGrid()
end
