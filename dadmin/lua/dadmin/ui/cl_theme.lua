if SERVER then return end

DAdmin = DAdmin or {}
DAdmin.UI = DAdmin.UI or {}
local UI = DAdmin.UI

UI.Colors = {
    bg = Color(26, 29, 38),
    bg2 = Color(18, 20, 28),
    bg3 = Color(12, 14, 20),
    panel = Color(18, 20, 28),
    border = Color(46, 50, 64),
    borderDark = Color(17, 19, 24),
    headerA = Color(42, 46, 60),
    headerB = Color(32, 35, 46),
    text = Color(214, 218, 228),
    textDim = Color(125, 131, 145),
    textDark = Color(82, 88, 102),
    blue = Color(74, 144, 217),
    green = Color(90, 170, 106),
    yellow = Color(204, 170, 68),
    red = Color(204, 68, 68),
    purple = Color(136, 85, 204),
    select = Color(30, 58, 96),
}

surface.CreateFont("DAdmin.Title", {font = "DermaDefaultBold", size = 15, weight = 700, antialias = true})
surface.CreateFont("DAdmin.Normal", {font = "DermaDefault", size = 14, weight = 500, antialias = true})
surface.CreateFont("DAdmin.Small", {font = "DermaDefault", size = 13, weight = 500, antialias = true})
surface.CreateFont("DAdmin.Tiny", {font = "DermaDefault", size = 11, weight = 500, antialias = true})
surface.CreateFont("DAdmin.Mono", {font = "BudgetLabel", size = 13, weight = 500, antialias = true})

function UI.PaintPanel(selfOrW, maybeW, maybeH)
    local w, h
    if maybeH ~= nil then
        w, h = maybeW, maybeH
    else
        w, h = selfOrW, maybeW
    end
    w = tonumber(w) or 0
    h = tonumber(h) or 0
    surface.SetDrawColor(UI.Colors.panel)
    surface.DrawRect(0, 0, w, h)
    surface.SetDrawColor(UI.Colors.border)
    surface.DrawOutlinedRect(0, 0, w, h, 1)
end

function UI.DrawVerticalGradient(x, y, w, h, c1, c2)
    h = math.max(1, math.floor(h or 1))
    for i = 0, h - 1 do
        local t = i / math.max(h - 1, 1)
        surface.SetDrawColor(
            Lerp(t, c1.r, c2.r),
            Lerp(t, c1.g, c2.g),
            Lerp(t, c1.b, c2.b),
            Lerp(t, c1.a or 255, c2.a or 255)
        )
        surface.DrawRect(x, y + i, w, 1)
    end
end

function UI.PaintHeader(selfOrW, maybeW, maybeH, maybeText)
    local w, h, text
    if maybeText ~= nil then
        w, h, text = maybeW, maybeH, maybeText
    elseif maybeH ~= nil then
        w, h, text = selfOrW, maybeW, maybeH
    else
        w, h, text = selfOrW, maybeW, ""
    end
    w = tonumber(w) or 0
    h = tonumber(h) or 0
    UI.DrawVerticalGradient(0, 0, w, h, UI.Colors.headerA, UI.Colors.headerB)
    surface.SetDrawColor(UI.Colors.border)
    surface.DrawOutlinedRect(0, 0, w, h, 1)
    draw.SimpleText(tostring(text or ""), "DAdmin.Title", 8, h * 0.5, UI.Colors.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
end

function UI.StyleButton(btn, variant)
    btn:SetFont("DAdmin.Normal")
    btn:SetTextColor(color_white)
    btn:SetTall(btn:GetTall() > 0 and btn:GetTall() or 22)
    btn:SetContentAlignment(5)
    if variant then btn._variant = variant end
    btn.Paint = function(self, w, h)
        local a, b, outline, txt = UI.Colors.headerA, UI.Colors.headerB, UI.Colors.border, UI.Colors.text
        local current = self._variant
        if current == "primary" then
            a, b, outline, txt = Color(74,144,217), Color(48,112,185), Color(90,160,233), color_white
        elseif current == "danger" then
            a, b, outline, txt = Color(204,68,68), Color(170,51,51), Color(221,85,85), color_white
        elseif current == "active" then
            a, b, outline, txt = UI.Colors.select, Color(26,44,74), Color(42,80,144), color_white
        end
        if self:IsHovered() then
            a = Color(math.min(a.r + 8,255), math.min(a.g + 8,255), math.min(a.b + 8,255), a.a or 255)
        end
        UI.DrawVerticalGradient(0, 0, w, h, a, b)
        surface.SetDrawColor(outline)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        draw.SimpleText(self:GetText(), "DAdmin.Normal", w * 0.5, h * 0.5, txt, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        return true
    end
end

function UI.StyleTextEntry(entry)
    entry:SetFont("DAdmin.Normal")
    entry:SetTextColor(UI.Colors.text)
    entry:SetHighlightColor(UI.Colors.blue)
    entry:SetCursorColor(UI.Colors.text)
    entry.Paint = function(self, w, h)
        surface.SetDrawColor(UI.Colors.bg3)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(UI.Colors.border)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        self:DrawTextEntryText(UI.Colors.text, UI.Colors.blue, UI.Colors.text)
        if self:GetValue() == "" and self:GetPlaceholderText() and not self:HasFocus() then
            draw.SimpleText(self:GetPlaceholderText(), "DAdmin.Normal", 5, h * 0.5, UI.Colors.textDark, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
    end
end

function UI.MakeSection(parent, title, dock, margin)
    local pnl = vgui.Create("DPanel", parent)
    pnl:Dock(dock or TOP)
    if margin then pnl:DockMargin(unpack(margin)) end
    pnl.Paint = function(s, w, h) UI.PaintPanel(w, h) end

    local hdr = vgui.Create("DPanel", pnl)
    hdr:Dock(TOP)
    hdr:SetTall(22)
    hdr.Paint = function(_, w, h) UI.PaintHeader(w, h, title) end

    local body = vgui.Create("DPanel", pnl)
    body:Dock(FILL)
    body.Paint = nil
    pnl.Body = body

    return pnl, body
end

function UI.PaintInfoCard(_, w, h, accent, title, value, subtitle)
    accent = accent or UI.Colors.blue
    surface.SetDrawColor(UI.Colors.bg2)
    surface.DrawRect(0, 0, w, h)
    surface.SetDrawColor(UI.Colors.border)
    surface.DrawOutlinedRect(0, 0, w, h, 1)
    surface.SetDrawColor(accent.r, accent.g, accent.b, 180)
    surface.DrawRect(0, 0, 4, h)
    draw.SimpleText(tostring(title or ""), "DAdmin.Small", 12, 14, UI.Colors.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    draw.SimpleText(tostring(value or "-"), "DAdmin.Title", 12, 34, accent, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    if subtitle and subtitle ~= "" then
        draw.SimpleText(tostring(subtitle), "DAdmin.Tiny", 12, h - 12, UI.Colors.textDark, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
end
