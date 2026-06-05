if SERVER then return end
DAdmin = DAdmin or {}
DAdmin.PlayTimeClient = DAdmin.PlayTimeClient or { data = {} }

local function req(target)
    net.Start("DAdmin_PlayTime_Request")
    net.WriteUInt(IsValid(target) and target:EntIndex() or 0, 16)
    net.SendToServer()
end

net.Receive("DAdmin_PlayTime_Send", function()
    DAdmin.PlayTimeClient.data = net.ReadTable() or {}
    DAdmin.PlayTimeClient.received = CurTime()
end)

local function live(block)
    if not istable(block) then return nil end
    local dt = math.max(0, CurTime() - (DAdmin.PlayTimeClient.received or CurTime()))
    local total = (tonumber(block.total or 0) or 0) + dt
    local session = (tonumber(block.session or 0) or 0) + dt
    return total, session
end

local function fmt(seconds)
    seconds = math.max(0, math.floor(tonumber(seconds or 0) or 0))
    local d = math.floor(seconds / 86400)
    local h = math.floor((seconds % 86400) / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = seconds % 60
    if d > 0 then return string.format("%dd %02dh %02dm", d, h, m) end
    if h > 0 then return string.format("%02dh %02dm", h, m) end
    return string.format("%02dm %02ds", m, s)
end

timer.Create("DAdminPlayTimeHUDRequest", 1, 0, function()
    if not IsValid(LocalPlayer()) then return end
    local tr = LocalPlayer():GetEyeTrace()
    local target = IsValid(tr.Entity) and tr.Entity:IsPlayer() and tr.Entity or nil
    req(target)
end)

hook.Add("HUDPaint", "DAdminPlayTimeHUD", function()
    local d = DAdmin.PlayTimeClient.data or {}
    if d.enabled == false or d.hud == false then return end
    local mine = d.local_player or {}
    local target = d.target
    local mt, ms = live(mine)
    local tt, ts = live(target)
    local col = DAdmin.HexColor and DAdmin.HexColor(d.color, Color(74,144,217)) or Color(74,144,217)
    local w = 260
    local expanded = istable(target)
    local h = expanded and 96 or 42
    local x, y = ScrW() - w - 12, 12

    surface.SetDrawColor(18,20,28,235) surface.DrawRect(x,y,w,h)
    surface.SetDrawColor(col) surface.DrawOutlinedRect(x,y,w,h,1)
    surface.SetDrawColor(col.r, col.g, col.b, 55) surface.DrawRect(x, y, w, 20)

    draw.SimpleText("Your Playtime", "DAdmin.Small", x+8, y+10, col, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    draw.SimpleText(fmt(mt or mine.total or 0), "DAdmin.Normal", x+w-8, y+13, color_white, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    draw.SimpleText("Session: "..fmt(ms or mine.session or 0), "DAdmin.Small", x+8, y+31, Color(190,195,210), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

    if expanded then
        surface.SetDrawColor(255,255,255,10) surface.DrawRect(x+8, y+45, w-16, 1)
        draw.SimpleText("Looking at: "..tostring(target.name or "Player"), "DAdmin.Small", x+8, y+58, col, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Total: "..fmt(tt or target.total or 0), "DAdmin.Small", x+8, y+75, Color(220,225,235), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Session: "..fmt(ts or target.session or 0), "DAdmin.Small", x+w-8, y+75, Color(190,195,210), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end
end)

-- Refined UTime-style playtime management panel with left records + right leaderboard/editor.
function DAdmin.BuildPlaytimePanel(parent)
    parent:Clear()
    local UI, C = DAdmin.UI, DAdmin.UI.Colors

    local shell = vgui.Create("DPanel", parent)
    shell:Dock(FILL)
    shell.Paint = nil

    local left = vgui.Create("DPanel", shell)
    left:Dock(LEFT)
    left:SetWide(270)
    left:DockMargin(0, 0, 8, 0)
    left.Paint = nil

    local search = vgui.Create("DTextEntry", left)
    search:Dock(TOP)
    search:DockMargin(0, 0, 0, 5)
    search:SetTall(26)
    search:SetPlaceholderText("Search recorded players...")
    UI.StyleTextEntry(search)

    local recordsScroll = vgui.Create("DScrollPanel", left)
    recordsScroll:Dock(FILL)

    local right = vgui.Create("DPanel", shell)
    right:Dock(FILL)
    right.Paint = nil

    local topPlayersPanel = vgui.Create("DPanel", right)
    topPlayersPanel:Dock(TOP)
    topPlayersPanel:SetTall(170)
    topPlayersPanel:DockMargin(0, 0, 0, 8)

    local editorPanel = vgui.Create("DScrollPanel", right)
    editorPanel:Dock(FILL)

    local selectedId = ""
    local filterText = ""

    local function secondsFromText(value)
        value = string.Trim(string.lower(tostring(value or "")))
        if value == "" then return 0 end
        local plain = tonumber(value)
        if plain then return math.max(0, plain) end
        local total = 0
        for n, unit in string.gmatch(value, "([%d%.]+)%s*([dhms])") do
            n = tonumber(n) or 0
            if unit == "d" then total = total + n * 86400
            elseif unit == "h" then total = total + n * 3600
            elseif unit == "m" then total = total + n * 60
            elseif unit == "s" then total = total + n end
        end
        return math.max(0, math.floor(total))
    end

    local function getRecords()
        local data = (DAdmin.PlayTimeClient and DAdmin.PlayTimeClient.data) or {}
        local byId = {}
        for _, record in ipairs(data.records or {}) do
            if istable(record) then
                local id = tostring(record.steamid64 or record.steamid or "")
                if id ~= "" and id ~= "unknown" then
                    local existing = byId[id]
                    local total = tonumber(record.total or 0) or 0
                    if not existing or total >= (tonumber(existing.total or 0) or 0) then
                        byId[id] = {
                            steamid64 = id,
                            steamid = record.steamid,
                            name = record.name or record.last_name or id,
                            total = total,
                            total_text = record.total_text or fmt(total),
                            last_seen = record.last_seen or 0
                        }
                    end
                end
            end
        end
        local out = {}
        for _, rec in pairs(byId) do out[#out + 1] = rec end
        table.sort(out, function(a, b) return (a.total or 0) > (b.total or 0) end)
        return out
    end

    local function sendAction(mode, record, amountText)
        if not record then return end
        net.Start("DAdmin_PlayTime_Admin")
        net.WriteString(mode)
        net.WriteString(tostring(record.steamid64 or ""))
        net.WriteString(tostring(secondsFromText(amountText)))
        net.SendToServer()
        timer.Simple(0.35, function() if IsValid(parent) then req(LocalPlayer()) end end)
    end

    local function findSelected()
        for _, rec in ipairs(getRecords()) do
            if tostring(rec.steamid64) == selectedId then return rec end
        end
    end

    local function paintBox(_, w, h)
        surface.SetDrawColor(12, 15, 24, 245)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(C.border)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    local rebuildEditor, rebuildRecords, rebuildTop

    rebuildTop = function()
        topPlayersPanel:Clear()

        local header = vgui.Create("DPanel", topPlayersPanel)
        header:Dock(TOP)
        header:SetTall(28)
        header.Paint = function(_, w, h)
            surface.SetDrawColor(16, 20, 31, 250)
            surface.DrawRect(0, 0, w, h)
            surface.SetDrawColor(C.border)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
            draw.SimpleText("Top Players", "DAdmin.Title", 8, h / 2, C.blue, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText("Total Playtime", "DAdmin.Small", w - 8, h / 2, C.textDim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end

        local list = vgui.Create("DScrollPanel", topPlayersPanel)
        list:Dock(FILL)

        for i, rec in ipairs(getRecords()) do
            if i > 10 then break end
            local row = vgui.Create("DButton", list)
            row:Dock(TOP)
            row:DockMargin(0, 0, 0, 3)
            row:SetTall(26)
            row:SetText("")
            row.Paint = function(_, w, h)
                surface.SetDrawColor(selectedId == rec.steamid64 and Color(23, 55, 95, 240) or Color(12, 15, 24, 245))
                surface.DrawRect(0, 0, w, h)
                surface.SetDrawColor(C.border)
                surface.DrawOutlinedRect(0, 0, w, h, 1)
                draw.SimpleText("#" .. i .. "  " .. tostring(rec.name or rec.steamid64), "DAdmin.Small", 8, h / 2, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                draw.SimpleText(rec.total_text or fmt(rec.total), "DAdmin.Small", w - 8, h / 2, C.blue, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
            end
            row.DoClick = function()
                selectedId = tostring(rec.steamid64)
                rebuildRecords()
                rebuildTop()
                rebuildEditor(rec)
            end
        end
    end

    rebuildEditor = function(record)
        editorPanel:Clear()
        record = record or findSelected()

        local header = vgui.Create("DPanel", editorPanel)
        header:Dock(TOP)
        header:DockMargin(0, 0, 0, 6)
        header:SetTall(34)
        header.Paint = function(_, w, h)
            surface.SetDrawColor(16, 20, 31, 250)
            surface.DrawRect(0, 0, w, h)
            surface.SetDrawColor(C.border)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
            draw.SimpleText(record and ("Editing: " .. tostring(record.name or record.steamid64)) or "Select a player record", "DAdmin.Title", 8, h / 2, record and C.blue or C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end

        if not record then
            local hint = vgui.Create("DLabel", editorPanel)
            hint:Dock(TOP)
            hint:DockMargin(8, 4, 8, 0)
            hint:SetTall(22)
            hint:SetFont("DAdmin.Normal")
            hint:SetTextColor(C.textDim)
            hint:SetText("Choose a stored playtime record from the left, or pick a top player above.")
            return
        end

        local info = vgui.Create("DPanel", editorPanel)
        info:Dock(TOP)
        info:DockMargin(0, 0, 0, 6)
        info:SetTall(78)
        info.Paint = function(_, w, h)
            paintBox(_, w, h)
            draw.SimpleText("SteamID64: " .. tostring(record.steamid64), "DAdmin.Small", 8, 18, C.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            if record.steamid then draw.SimpleText("SteamID: " .. tostring(record.steamid), "DAdmin.Small", 8, 38, C.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER) end
            draw.SimpleText("Total: " .. tostring(record.total_text or fmt(record.total)), "DAdmin.Title", 8, 60, C.blue, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end

        local amount = vgui.Create("DTextEntry", editorPanel)
        amount:Dock(TOP)
        amount:DockMargin(0, 0, 0, 6)
        amount:SetTall(28)
        amount:SetPlaceholderText("Amount: seconds, 1h, 30m, 2d, etc.")
        UI.StyleTextEntry(amount)

        local buttons = vgui.Create("DPanel", editorPanel)
        buttons:Dock(TOP)
        buttons:SetTall(32)
        buttons.Paint = nil

        local set = vgui.Create("DButton", buttons)
        set:Dock(LEFT)
        set:SetWide(100)
        set:SetText("Set Total")
        UI.StyleButton(set, "primary")
        set.DoClick = function() sendAction("set", record, amount:GetValue()) end

        local add = vgui.Create("DButton", buttons)
        add:Dock(LEFT)
        add:DockMargin(6, 0, 0, 0)
        add:SetWide(100)
        add:SetText("Add Time")
        UI.StyleButton(add, "primary")
        add.DoClick = function() sendAction("add", record, amount:GetValue()) end

        local reset = vgui.Create("DButton", buttons)
        reset:Dock(LEFT)
        reset:DockMargin(6, 0, 0, 0)
        reset:SetWide(100)
        reset:SetText("Reset")
        UI.StyleButton(reset, "danger")
        reset.DoClick = function()
            Derma_Query("Reset playtime for " .. tostring(record.name or record.steamid64) .. "?", "Confirm Reset",
                "Reset", function() sendAction("reset", record, 0) end,
                "Cancel")
        end
    end

    rebuildRecords = function()
        recordsScroll:Clear()
        for _, rec in ipairs(getRecords()) do
            local hay = string.lower(tostring(rec.name or "") .. " " .. tostring(rec.steamid64 or "") .. " " .. tostring(rec.steamid or ""))
            if filterText == "" or string.find(hay, filterText, 1, true) then
                local row = vgui.Create("DButton", recordsScroll)
                row:Dock(TOP)
                row:DockMargin(0, 0, 0, 4)
                row:SetTall(46)
                row:SetText("")
                row.Paint = function(_, w, h)
                    surface.SetDrawColor(selectedId == rec.steamid64 and Color(23, 55, 95, 240) or Color(12, 15, 24, 245))
                    surface.DrawRect(0, 0, w, h)
                    surface.SetDrawColor(C.border)
                    surface.DrawOutlinedRect(0, 0, w, h, 1)
                    draw.SimpleText(tostring(rec.name or rec.steamid64), "DAdmin.Normal", 8, 14, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                    draw.SimpleText(tostring(rec.total_text or fmt(rec.total)), "DAdmin.Small", 8, 32, C.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                end
                row.DoClick = function()
                    selectedId = tostring(rec.steamid64)
                    rebuildRecords()
                    rebuildTop()
                    rebuildEditor(rec)
                end
            end
        end
    end

    search.OnChange = function(s)
        filterText = string.lower(s:GetValue() or "")
        rebuildRecords()
    end

    req(LocalPlayer())
    timer.Simple(0.2, function()
        if not IsValid(parent) then return end
        rebuildRecords()
        rebuildTop()
        rebuildEditor()
    end)
end
