if SERVER then return end

DAdmin = DAdmin or {}
DAdmin.UI = DAdmin.UI or {}
local UI = DAdmin.UI

local function fmtTime(ts)
    ts = tonumber(ts or 0)
    if ts <= 0 then return "-" end
    return os.date("%H:%M:%S", ts)
end

local function colorForLevel(level)
    local C = UI.Colors
    level = tostring(level or "clean")
    if level == "critical" then return C.red end
    if level == "high" then return Color(255, 120, 70) end
    if level == "review" then return C.yellow end
    if level == "watch" then return C.blue end
    return C.green
end

local function smallButton(parent, text, variant, click)
    local b = vgui.Create("DButton", parent)
    b:Dock(TOP)
    b:DockMargin(6, 4, 6, 0)
    b:SetTall(22)
    b:SetText(text)
    UI.StyleButton(b, variant)
    b.DoClick = click
    return b
end

function DAdmin.BuildControlPanel(parent)
    parent:Clear()
    local C = UI.Colors
    local state = DAdmin.Port.GetState()
    local intel = DAdmin.Port.GetIntelligence()
    local staff = DAdmin.Port.GetStaffControl()
    local profiles = intel.profiles or {}
    local counts = intel.counts or {}
    local selected

    local shell = vgui.Create("DPanel", parent)
    shell:Dock(FILL)
    shell.Paint = nil

    local left = vgui.Create("DPanel", shell)
    left:Dock(LEFT)
    left:SetWide(205)
    left:DockMargin(0, 0, 5, 0)
    left.Paint = nil

    local status, statusBody = UI.MakeSection(left, "Intelligence Status", TOP)
    status:SetTall(150)
    local function statusRow(y, label, value, col)
        draw.SimpleText(label, "DAdmin.Normal", 8, y, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(value, "DAdmin.Normal", 190, y, col or C.blue, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end
    statusBody.Paint = function(_, w, h)
        statusRow(16, "Watch", tostring(counts.watch or 0), C.blue)
        statusRow(39, "Review", tostring(counts.review or 0), C.yellow)
        statusRow(62, "High Risk", tostring(counts.high or 0), Color(255, 120, 70))
        statusRow(85, "Critical", tostring(counts.critical or 0), C.red)
        statusRow(108, "Active Staff", tostring(#((staff or {}).active or {})), C.green)
    end

    local settings, settingsBody = UI.MakeSection(left, "Controls", TOP, {0,5,0,0})
    settings:SetTall(150)
    smallButton(settingsBody, "Open Guard", nil, function() DAdmin.SwitchTab("guard") end)
    smallButton(settingsBody, "View Logs", nil, function() DAdmin.SwitchTab("logs") end)
    smallButton(settingsBody, "Manual Refresh", "primary", function() DAdmin.Port.Refresh() end)

    local staffSec, staffBody = UI.MakeSection(left, "Active Staff", FILL, {0,5,0,0})
    local staffScroll = vgui.Create("DScrollPanel", staffBody)
    staffScroll:Dock(FILL)
    for _, s in ipairs((staff or {}).active or {}) do
        local row = vgui.Create("DPanel", staffScroll)
        row:Dock(TOP)
        row:SetTall(24)
        row.Paint = function(_, w, h)
            surface.SetDrawColor(C.bg2)
            surface.DrawRect(0, 0, w, h)
            surface.SetDrawColor(C.border)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
            draw.SimpleText(tostring(s.name or s.steamid), "DAdmin.Normal", 6, h/2, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText(tostring(s.rank or ""), "DAdmin.Small", w - 6, h/2, C.blue, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end
    end

    local center = vgui.Create("DPanel", shell)
    center:Dock(FILL)
    center.Paint = nil

    local riskSec, riskBody = UI.MakeSection(center, "Risk Profiles", TOP)
    riskSec:SetTall(310)

    local header = vgui.Create("DPanel", riskBody)
    header:Dock(TOP)
    header:SetTall(24)
    header.Paint = function(_, w, h)
        surface.SetDrawColor(C.bg3)
        surface.DrawRect(0,0,w,h)
        draw.SimpleText("Player", "DAdmin.Small", 8, h/2, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Risk", "DAdmin.Small", w*0.44, h/2, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Level", "DAdmin.Small", w*0.58, h/2, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Last", "DAdmin.Small", w-8, h/2, C.text, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end

    local riskScroll = vgui.Create("DScrollPanel", riskBody)
    riskScroll:Dock(FILL)

    local detailText = "Select a risk profile to inspect."
    for _, p in ipairs(profiles) do
        local row = vgui.Create("DButton", riskScroll)
        row:Dock(TOP)
        row:SetTall(25)
        row:SetText("")
        row.Paint = function(self, w, h)
            local selectedRow = selected == p
            surface.SetDrawColor(selectedRow and C.select or (self:IsHovered() and Color(24,29,40) or C.bg2))
            surface.DrawRect(0, 0, w, h)
            surface.SetDrawColor(C.border)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
            local col = colorForLevel(p.level)
            draw.SimpleText(tostring(p.name or p.steamid), "DAdmin.Normal", 8, h/2, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText(tostring(p.score or 0) .. "%", "DAdmin.Normal", w*0.44, h/2, col, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText(tostring(p.level or "clean"), "DAdmin.Normal", w*0.58, h/2, col, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText(fmtTime(p.lastSeen), "DAdmin.Small", w-8, h/2, C.textDim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end
        row.DoClick = function()
            selected = p
            detailText = "SteamID: " .. tostring(p.steamid) ..
                "\nScore: " .. tostring(p.score or 0) ..
                "\nLevel: " .. tostring(p.level or "clean") ..
                "\nCase: " .. tostring(p.caseID or "none") ..
                "\n\nRecent Offenses:\n"
            for i, e in ipairs(p.offenses or {}) do
                if i > 8 then break end
                detailText = detailText .. "- " .. tostring(e.time or "") .. " " .. tostring(e.type) .. " (" .. tostring(e.confidence or 0) .. "%) " .. tostring(e.details or "") .. "\n"
            end
            if IsValid(DAdmin.ControlDetail) then DAdmin.ControlDetail:SetText(detailText) end
        end
    end

    local caseSec, caseBody = UI.MakeSection(center, "Case Control Queue", FILL, {0,5,0,0})
    local cases = state.cases or {}
    local caseScroll = vgui.Create("DScrollPanel", caseBody)
    caseScroll:Dock(FILL)

    for _, c in ipairs(cases) do
        if tostring(c.status or "open") ~= "closed" then
            local row = vgui.Create("DPanel", caseScroll)
            row:Dock(TOP)
            row:SetTall(28)
            row.Paint = function(_, w, h)
                surface.SetDrawColor(C.bg2)
                surface.DrawRect(0,0,w,h)
                surface.SetDrawColor(C.border)
                surface.DrawOutlinedRect(0,0,w,h,1)
                draw.SimpleText(tostring(c.id), "DAdmin.Small", 6, h/2, C.blue, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                draw.SimpleText(tostring(c.reason or ""), "DAdmin.Small", 190, h/2, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                draw.SimpleText(c.claimedByName and ("claimed: " .. c.claimedByName) or "unclaimed", "DAdmin.Small", w-8, h/2, c.claimedBy and C.yellow or C.green, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
            end
            local btns = vgui.Create("DPanel", row)
            btns:Dock(RIGHT)
            btns:SetWide(145)
            btns.Paint = nil
            local claim = vgui.Create("DButton", btns)
            claim:Dock(LEFT)
            claim:SetWide(65)
            claim:SetText("Claim")
            UI.StyleButton(claim, "primary")
            claim.DoClick = function() DAdmin.Port.UIAction("case_claim", { caseID = c.id }) end
            local rel = vgui.Create("DButton", btns)
            rel:Dock(LEFT)
            rel:DockMargin(4,0,0,0)
            rel:SetWide(70)
            rel:SetText("Release")
            UI.StyleButton(rel)
            rel.DoClick = function() DAdmin.Port.UIAction("case_release", { caseID = c.id }) end
        end
    end

    local right = vgui.Create("DPanel", shell)
    right:Dock(RIGHT)
    right:SetWide(230)
    right:DockMargin(5,0,0,0)
    right.Paint = nil

    local detail, detailBody = UI.MakeSection(right, "Inspect", FILL)
    local d = vgui.Create("DTextEntry", detailBody)
    d:Dock(FILL)
    d:DockMargin(6,6,6,6)
    d:SetMultiline(true)
    d:SetText(detailText)
    d:SetEditable(false)
    UI.StyleTextEntry(d)
    DAdmin.ControlDetail = d

    local actions = vgui.Create("DPanel", detailBody)
    actions:Dock(BOTTOM)
    actions:SetTall(88)
    actions.Paint = nil
    smallButton(actions, "Reset Selected Risk", "danger", function()
        if selected then DAdmin.Port.UIAction("intel_reset", { steamid = selected.steamid }) end
    end)
    smallButton(actions, "Create Manual Case", "primary", function()
        if selected then DAdmin.Port.UIAction("command", { command = "case", args = { selected.caseID or "" } }) end
    end)
end
