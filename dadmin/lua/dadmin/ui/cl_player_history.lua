if SERVER then return end

function DAdmin.BuildPlayerHistoryPanel(parent)
    parent:Clear()
    local UI = DAdmin.UI
    local C = UI.Colors
    local histories = DAdmin.Port.GetHistories and DAdmin.Port.GetHistories() or {}

    local section, body = UI.MakeSection(parent, "Player History", FILL)

    local top = vgui.Create("DPanel", body)
    top:Dock(TOP)
    top:SetTall(30)
    top:DockMargin(8,8,8,4)
    top.Paint = nil

    local search = vgui.Create("DTextEntry", top)
    search:Dock(LEFT)
    search:SetWide(260)
    search:SetPlaceholderText("Search name or SteamID")
    UI.StyleTextEntry(search)

    local note = vgui.Create("DTextEntry", top)
    note:Dock(FILL)
    note:DockMargin(8,0,8,0)
    note:SetPlaceholderText("Staff note for selected SteamID")
    UI.StyleTextEntry(note)

    local addNote = vgui.Create("DButton", top)
    addNote:Dock(RIGHT)
    addNote:SetWide(100)
    addNote:SetText("Add Note")
    UI.StyleButton(addNote, "primary")

    local split = vgui.Create("DPanel", body)
    split:Dock(FILL)
    split:DockMargin(8,0,8,8)
    split.Paint = nil

    local list = vgui.Create("DScrollPanel", split)
    list:Dock(LEFT)
    list:SetWide(340)

    local details = vgui.Create("DScrollPanel", split)
    details:Dock(FILL)
    details:DockMargin(8,0,0,0)

    local selected

    local function line(parentPanel, text, color)
        local lbl = vgui.Create("DLabel", parentPanel)
        lbl:Dock(TOP)
        lbl:DockMargin(6,2,6,0)
        lbl:SetTall(18)
        lbl:SetFont("DAdmin.Small")
        lbl:SetTextColor(color or C.text)
        lbl:SetText(text)
        return lbl
    end

    local function count(summary, key)
        return tonumber(summary and summary[key] or 0) or 0
    end

    local function drawDetails(row)
        details:Clear()
        if not row then
            line(details, "Select a player history record.", C.textDim)
            return
        end

        selected = row
        line(details, row.name .. "  (" .. row.steamid .. ")", C.text)
        line(details, "Warnings: " .. count(row.summary,"warnings") ..
            " | Bans: " .. count(row.summary,"bans") ..
            " | Kicks: " .. count(row.summary,"kicks") ..
            " | Cases: " .. count(row.summary,"cases") ..
            " | Punishments: " .. count(row.summary,"punishments"), C.textDim)

        local function bucket(title, entries)
            local header = vgui.Create("DPanel", details)
            header:Dock(TOP)
            header:DockMargin(4,8,4,2)
            header:SetTall(22)
            header.Paint = function(_, w, h) UI.PaintHeader(w, h, title .. " (" .. tostring(#(entries or {})) .. ")") end

            if not entries or #entries == 0 then
                line(details, "No entries.", C.textDark)
                return
            end

            for i, e in ipairs(entries) do
                if i > 12 then line(details, "...older entries hidden in compact view.", C.textDark) break end
                local when = e.timestamp and os.date("%Y-%m-%d %H:%M", e.timestamp) or "unknown time"
                local text = when .. " - " .. tostring(e.type or e.action or e.reason or e.details or e.id or "entry")
                if e.reason and e.reason ~= text then text = text .. " | " .. tostring(e.reason) end
                if e.details and e.details ~= "" then text = text .. " | " .. tostring(e.details) end
                line(details, text, C.textDim)
            end
        end

        bucket("Punishments", row.punishments)
        bucket("Warnings", row.warnings)
        bucket("Reports", row.reports)
        bucket("Cases", row.cases)
        bucket("Sits", row.sits)
        bucket("Notes", row.notes)
    end

    local function rebuild()
        list:Clear()
        local needle = string.lower(search:GetValue() or "")

        for _, h in ipairs(histories) do
            local hay = string.lower((h.name or "") .. " " .. (h.steamid or "") .. " " .. table.concat(h.names or {}, " "))
            if needle == "" or string.find(hay, needle, 1, true) then
                local btn = vgui.Create("DButton", list)
                btn:Dock(TOP)
                btn:DockMargin(0,0,0,4)
                btn:SetTall(44)
                btn:SetText("")
                btn.Paint = function(self, w, hgt)
                    surface.SetDrawColor(self:IsHovered() and C.select or C.bg2)
                    surface.DrawRect(0,0,w,hgt)
                    surface.SetDrawColor(C.border)
                    surface.DrawOutlinedRect(0,0,w,hgt,1)
                    draw.SimpleText(h.name or h.steamid, "DAdmin.Normal", 8, 11, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                    draw.SimpleText(h.steamid or "", "DAdmin.Small", 8, 29, C.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                    draw.SimpleText("W:" .. count(h.summary,"warnings") .. " B:" .. count(h.summary,"bans") .. " C:" .. count(h.summary,"cases"), "DAdmin.Small", w - 8, 22, C.textDim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
                end
                btn.DoClick = function() drawDetails(h) end
            end
        end
    end

    search.OnChange = rebuild
    addNote.DoClick = function()
        if not selected then return end
        local txt = string.Trim(note:GetValue() or "")
        if txt == "" then return end
        DAdmin.Port.UIAction("history_note", { steamid = selected.steamid, note = txt })
        note:SetText("")
    end

    rebuild()
    drawDetails(histories[1])
end
