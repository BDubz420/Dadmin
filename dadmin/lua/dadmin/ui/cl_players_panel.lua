if SERVER then return end
local UI = DAdmin.UI
local C = UI.Colors

DAdmin._playerToggleStates = DAdmin._playerToggleStates or {}
DAdmin._playerActionLog = DAdmin._playerActionLog or {}
DAdmin._selectedPlayerId = DAdmin._selectedPlayerId or nil

local function getColumns()
    local cols = DAdmin.Port.GetPlayerColumns and DAdmin.Port.GetPlayerColumns() or {}
    if not istable(cols) or #cols == 0 then
        cols = {
            { key = "name", label = "Name", width = 0.32 },
            { key = "rank", label = "Rank", width = 0.20 },
            { key = "health", label = "HP", width = 0.12 },
            { key = "armor", label = "Armor", width = 0.12 },
            { key = "ping", label = "Ping", width = 0.12 },
            { key = "time", label = "Time", width = 0.12 },
        }
    end
    return cols
end

local function fmtCell(playerRow, key)
    local v = playerRow and playerRow[key]
    if key == "ping" and v ~= nil then return tostring(v) end
    if key == "health" or key == "armor" or key == "karma" then return tostring(v or "-") end
    if v == nil or v == "" then return "-" end
    return tostring(v)
end

local function addInfoRows(selected)
    local rows = {
        {"Name", selected.name}, {"Rank", selected.rank}, {"SteamID", selected.steamid}
    }

    local gm = DAdmin.Port.GetGamemode and DAdmin.Port.GetGamemode() or {}
    local features = gm.features or {}
    if features.jobs then
        rows[#rows + 1] = {"Job", selected.job or "Unassigned"}
        rows[#rows + 1] = {"Wallet", selected.wallet or "-"}
        rows[#rows + 1] = {"Salary", selected.salary or "-"}
        rows[#rows + 1] = {"Wanted", selected.wanted or "-"}
        rows[#rows + 1] = {"Arrested", selected.arrested or "-"}
    elseif features.ttt then
        rows[#rows + 1] = {"Role", selected.role or "-"}
        rows[#rows + 1] = {"Karma", tostring(selected.karma or "-")}
    elseif features.teams then
        rows[#rows + 1] = {"Team", selected.team or selected.role or "-"}
    end

    rows[#rows + 1] = {"Health", tostring(selected.health or 0)}
    rows[#rows + 1] = {"Armor", tostring(selected.armor or 0)}
    rows[#rows + 1] = {"Ping", tostring(selected.ping or 0) .. "ms"}
    return rows
end


local function SmallButton(parent, txt, variant, fn)
    local b = vgui.Create("DButton", parent)
    b:Dock(TOP) b:DockMargin(0, 2, 0, 0) b:SetTall(22) b:SetText(txt) UI.StyleButton(b, variant) b.DoClick = fn
    return b
end

function DAdmin.BuildPlayersPanel(parent)
    parent:Clear()
    local allPlayers = DAdmin.Port.GetPlayers()
    local rebuildInfo, rebuildList

    -- Restore selected player across rebuilds
    local selected = nil
    if DAdmin._selectedPlayerId then
        for _, p in ipairs(allPlayers) do
            if p.steamid == DAdmin._selectedPlayerId then selected = p break end
        end
    end

    local shell = vgui.Create("DPanel", parent) shell:Dock(FILL) shell.Paint = nil

    -- Right side: scrollable container for all info/actions
    local rightOuter = vgui.Create("DPanel", shell) rightOuter:Dock(RIGHT) rightOuter:SetWide(220) rightOuter.Paint = nil
    local rightScroll = vgui.Create("DScrollPanel", rightOuter) rightScroll:Dock(FILL)

    local left = vgui.Create("DPanel", shell) left:Dock(FILL) left:DockMargin(0, 0, 5, 0) left.Paint = nil
    local toolBar = vgui.Create("DPanel", left) toolBar:Dock(TOP) toolBar:SetTall(28) toolBar.Paint = nil
    local searchBar = vgui.Create("DTextEntry", toolBar) searchBar:Dock(LEFT) searchBar:SetWide(230) searchBar:SetTall(22) searchBar:SetPlaceholderText("Search name / steamid...") UI.StyleTextEntry(searchBar)
    local refreshBtn = vgui.Create("DButton", toolBar) refreshBtn:Dock(RIGHT) refreshBtn:DockMargin(4, 2, 0, 2) refreshBtn:SetWide(76) refreshBtn:SetText("Refresh") UI.StyleButton(refreshBtn)
    local paletteBtn = vgui.Create("DButton", toolBar) paletteBtn:Dock(RIGHT) paletteBtn:DockMargin(4, 2, 0, 2) paletteBtn:SetWide(112) paletteBtn:SetText("Palette") UI.StyleButton(paletteBtn)
    local clearBtn = vgui.Create("DButton", toolBar) clearBtn:Dock(RIGHT) clearBtn:DockMargin(4, 2, 0, 2) clearBtn:SetWide(96) clearBtn:SetText("Clear Select") UI.StyleButton(clearBtn)
    local topPanel, topBody = UI.MakeSection(left, "Players (" .. tostring(#allPlayers) .. ")", FILL, {0, 5, 0, 0})

    -- Column headers are generated from the detected gamemode profile.
    local columns = getColumns()
    local headerRow = vgui.Create("DPanel", topBody) headerRow:Dock(TOP) headerRow:SetTall(20)
    headerRow.Paint = function(_, w, h)
        surface.SetDrawColor(26, 29, 38, 255) surface.DrawRect(0, 0, w, h)
        local x = 8
        for _, col in ipairs(columns) do
            draw.SimpleText(tostring(col.label or col.key), "DAdmin.Small", x, h/2, C.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            x = x + math.max(40, (w - 16) * tonumber(col.width or 0.15))
        end
    end
    local list = vgui.Create("DScrollPanel", topBody) list:Dock(FILL)

    -- Action log at bottom - persists across rebuilds
    local logPanel, logBody = UI.MakeSection(left, "Action Log", BOTTOM, {0, 5, 0, 0}) logPanel:SetTall(80)
    local logList = vgui.Create("DScrollPanel", logBody) logList:Dock(FILL)

    local function refreshLogDisplay()
        if not IsValid(logList) then return end
        logList:Clear()
        for i = #DAdmin._playerActionLog, math.max(1, #DAdmin._playerActionLog - 50), -1 do
            local entry = DAdmin._playerActionLog[i]
            if entry then
                local line = vgui.Create("DLabel", logList)
                line:Dock(TOP) line:SetTall(16) line:SetFont("DAdmin.Small") line:SetTextColor(entry.clr or C.green) line:SetText(entry.text)
                logList:AddItem(line)
            end
        end
    end
    refreshLogDisplay()

    local function addLog(msg, clr)
        DAdmin._playerActionLog[#DAdmin._playerActionLog + 1] = { text = "[" .. os.date("%H:%M:%S") .. "] " .. msg, clr = clr or C.green }
        refreshLogDisplay()
    end

    local function showPrompt(title, fields, cb)
        local fieldCount = #fields
        local fr = vgui.Create("EditablePanel")
        fr:SetSize(340, 60 + fieldCount * 34) fr:Center() fr:MakePopup() fr.Paint = function(_, w, h) UI.PaintPanel(w, h) end
        local hdr = vgui.Create("DPanel", fr) hdr:Dock(TOP) hdr:SetTall(22) hdr.Paint = function(_, w, h) UI.PaintHeader(w, h, title) end

        local inputs = {}
        for _, field in ipairs(fields) do
            local row = vgui.Create("DPanel", fr) row:Dock(TOP) row:SetTall(30) row:DockMargin(8, 4, 8, 0) row.Paint = nil
            local label = vgui.Create("DLabel", row) label:Dock(LEFT) label:SetWide(80) label:SetFont("DAdmin.Small") label:SetTextColor(C.textDim) label:SetText(field.label or "")
            if field.choices then
                local combo = vgui.Create("DComboBox", row)
                combo:Dock(FILL) combo:SetTall(22)
                for _, choice in ipairs(field.choices) do combo:AddChoice(choice) end
                inputs[field.key] = combo
            else
                local entry = vgui.Create("DTextEntry", row)
                entry:Dock(FILL) entry:SetTall(22) entry:SetPlaceholderText(field.placeholder or "") UI.StyleTextEntry(entry)
                if #inputs == 0 then entry:RequestFocus() end
                inputs[field.key] = entry
            end
        end

        local btns = vgui.Create("DPanel", fr) btns:Dock(BOTTOM) btns:SetTall(30) btns.Paint = nil
        local ok = vgui.Create("DButton", btns) ok:Dock(RIGHT) ok:DockMargin(0, 4, 8, 4) ok:SetWide(90) ok:SetText("Confirm") UI.StyleButton(ok, "primary")
        local cancel = vgui.Create("DButton", btns) cancel:Dock(RIGHT) cancel:DockMargin(0, 4, 4, 4) cancel:SetWide(90) cancel:SetText("Cancel") UI.StyleButton(cancel)
        cancel.DoClick = function() fr:Remove() end
        ok.DoClick = function()
            local result = {}
            for key, input in pairs(inputs) do
                if input.GetSelected then
                    result[key] = ({ input:GetSelected() })[1] or ""
                else
                    result[key] = input:GetValue() or ""
                end
            end
            cb(result)
            fr:Remove()
        end
    end

    local function runPlayerCommand(cmd, extra)
        if not selected then return end
        local args = { selected.name }
        if extra and extra ~= "" then args[#args + 1] = extra end
        DAdmin.Port.UIAction("command", { command = cmd, args = args })
        local clr = (cmd == "kick" or cmd == "ban" or cmd == "slay") and C.red or C.green
        addLog(cmd .. " -> " .. selected.name .. (extra and extra ~= "" and (": " .. extra) or ""), clr)
    end

    refreshBtn.DoClick = function()
        DAdmin.Port.Refresh()
    end
    paletteBtn.DoClick = function()
        DAdmin.OpenCommandPalette()
    end
    clearBtn.DoClick = function()
        selected = nil
        DAdmin._selectedPlayerId = nil
        rebuildInfo()
        rebuildList()
    end

    rebuildInfo = function()
        if not IsValid(rightScroll) then return end
        rightScroll:Clear()

        if not selected then
            local lbl = vgui.Create("DLabel", rightScroll)
            lbl:Dock(TOP) lbl:DockMargin(10, 20, 10, 0) lbl:SetFont("DAdmin.Normal") lbl:SetTextColor(C.textDark)
            lbl:SetWrap(true) lbl:SetAutoStretchVertical(true)
            lbl:SetText("Select a player to view info and actions.")
            rightScroll:AddItem(lbl)
            return
        end

        -- Section: Player Info header
        local infoHdr = vgui.Create("DPanel", rightScroll) infoHdr:Dock(TOP) infoHdr:SetTall(22)
        infoHdr.Paint = function(_, w, h) UI.PaintHeader(w, h, "Player Info") end
        rightScroll:AddItem(infoHdr)

        -- Player info rows with hover+copy. Gamemode-specific fields are only shown when relevant.
        for _, pair in ipairs(addInfoRows(selected)) do
            local row = vgui.Create("DButton", rightScroll)
            row:Dock(TOP) row:SetTall(18) row:SetText("") row:SetCursor("hand")
            row.Paint = function(self, w, h)
                local hov = self:IsHovered()
                if hov then surface.SetDrawColor(35, 40, 55, 255) surface.DrawRect(0, 0, w, h) end
                draw.SimpleText(pair[1], "DAdmin.Small", 8, h/2, C.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                if hov then
                    draw.SimpleText(pair[2], "DAdmin.Small", w * 0.45, h/2, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                    draw.SimpleText("[copy]", "DAdmin.Small", w - 4, h/2, C.blue, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
                else
                    draw.SimpleText(pair[2], "DAdmin.Small", w - 4, h/2, C.text, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
                end
            end
            row.DoClick = function()
                SetClipboardText(pair[2])
                addLog("Copied " .. pair[1] .. ": " .. pair[2], C.blue)
            end
            rightScroll:AddItem(row)
        end

        -- Section: Actions header
        local actHdr = vgui.Create("DPanel", rightScroll) actHdr:Dock(TOP) actHdr:SetTall(22) actHdr:DockMargin(0, 4, 0, 0)
        actHdr.Paint = function(_, w, h) UI.PaintHeader(w, h, "Actions") end
        rightScroll:AddItem(actHdr)

        -- Movement
        local moveLabel = vgui.Create("DPanel", rightScroll) moveLabel:Dock(TOP) moveLabel:SetTall(16) moveLabel:DockMargin(0, 2, 0, 0)
        moveLabel.Paint = function(_, w, h) draw.SimpleText("MOVEMENT", "DAdmin.Small", 4, h/2, C.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER) end
        rightScroll:AddItem(moveLabel)

        local goto_ = SmallButton(rightScroll, "Goto", nil, function() runPlayerCommand("goto") end) rightScroll:AddItem(goto_)
        local bring_ = SmallButton(rightScroll, "Bring", nil, function() runPlayerCommand("bring") end) rightScroll:AddItem(bring_)
        local spec_ = SmallButton(rightScroll, "Spectate", nil, function() runPlayerCommand("spectate") end) rightScroll:AddItem(spec_)

        -- Toggles
        local toggleLabel = vgui.Create("DPanel", rightScroll) toggleLabel:Dock(TOP) toggleLabel:SetTall(16) toggleLabel:DockMargin(0, 4, 0, 0)
        toggleLabel.Paint = function(_, w, h) draw.SimpleText("TOGGLES", "DAdmin.Small", 4, h/2, C.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER) end
        rightScroll:AddItem(toggleLabel)

        local sid = selected.steamid or ""
        DAdmin._playerToggleStates[sid] = DAdmin._playerToggleStates[sid] or { frozen = false, muted = false, gagged = false }
        local ts = DAdmin._playerToggleStates[sid]

        local function makeToggle(labelOn, labelOff, stateKey, cmdOn, cmdOff)
            local isOn = ts[stateKey]
            local btn = SmallButton(rightScroll, isOn and labelOn or labelOff, isOn and "active" or nil, nil)
            btn.DoClick = function()
                ts[stateKey] = not ts[stateKey]
                local nowOn = ts[stateKey]
                btn:SetText(nowOn and labelOn or labelOff)
                btn._variant = nowOn and "active" or nil
                runPlayerCommand(nowOn and cmdOn or cmdOff)
            end
            rightScroll:AddItem(btn)
            return btn
        end

        makeToggle("Unfreeze", "Freeze", "frozen", "freeze", "unfreeze")
        makeToggle("Unmute", "Mute", "muted", "mute", "unmute")
        makeToggle("Ungag", "Gag", "gagged", "gag", "ungag")

        -- Punishment
        local punishLabel = vgui.Create("DPanel", rightScroll) punishLabel:Dock(TOP) punishLabel:SetTall(16) punishLabel:DockMargin(0, 4, 0, 0)
        punishLabel.Paint = function(_, w, h) draw.SimpleText("PUNISHMENT", "DAdmin.Small", 4, h/2, C.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER) end
        rightScroll:AddItem(punishLabel)

        local slay_ = SmallButton(rightScroll, "Slay", "danger", function() runPlayerCommand("slay") end) rightScroll:AddItem(slay_)
        local warn_ = SmallButton(rightScroll, "Warn", "primary", function()
            showPrompt("Warn " .. selected.name, {
                { key = "reason", label = "Reason", placeholder = "Enter reason..." }
            }, function(result)
                DAdmin.Port.UIAction("warn_player", { steamid = selected.steamid, reason = result.reason })
                addLog("warn -> " .. selected.name .. ": " .. result.reason, C.yellow)
                timer.Simple(0.5, function() if IsValid(rightScroll) then rebuildInfo() end end)
            end)
        end) rightScroll:AddItem(warn_)
        local kick_ = SmallButton(rightScroll, "Kick", "danger", function()
            showPrompt("Kick " .. selected.name, {
                { key = "reason", label = "Reason", placeholder = "Enter reason..." }
            }, function(result) runPlayerCommand("kick", result.reason) end)
        end) rightScroll:AddItem(kick_)
        local ban_ = SmallButton(rightScroll, "Ban", "danger", function()
            showPrompt("Ban " .. selected.name, {
                { key = "duration", label = "Duration", placeholder = "1h, 1d, 7d, perm..." },
                { key = "reason", label = "Reason", placeholder = "Enter reason..." }
            }, function(result)
                local banArg = result.duration
                if result.reason ~= "" then banArg = banArg .. " " .. result.reason end
                runPlayerCommand("ban", banArg)
            end)
        end) rightScroll:AddItem(ban_)
        local setrank_ = SmallButton(rightScroll, "SetRank", "primary", function()
            local ranks = {}
            for _, r in ipairs(DAdmin.Port.GetRanks()) do ranks[#ranks + 1] = r.label or r.id end
            if #ranks == 0 then ranks = {"User","Trusted","Moderator","Admin","Superadmin","Owner"} end
            showPrompt("Set Rank for " .. selected.name, {
                { key = "rank", label = "Rank", choices = ranks }
            }, function(result)
                DAdmin.Port.UIAction("setrank", { steamid = selected.steamid, rank = string.lower(result.rank) })
                addLog("setrank -> " .. selected.name .. ": " .. result.rank, C.blue)
            end)
        end) rightScroll:AddItem(setrank_)
        local screengrab_ = SmallButton(rightScroll, "Screengrab", nil, function() runPlayerCommand("screengrab") end) rightScroll:AddItem(screengrab_)

        -- Section: Warnings header
        local warns = selected.warnings or {}
        local warnHdr = vgui.Create("DPanel", rightScroll) warnHdr:Dock(TOP) warnHdr:SetTall(22) warnHdr:DockMargin(0, 4, 0, 0)
        warnHdr.Paint = function(_, w, h) UI.PaintHeader(w, h, "Warnings (" .. tostring(#warns) .. ")") end
        rightScroll:AddItem(warnHdr)

        if #warns == 0 then
            local lbl = vgui.Create("DLabel", rightScroll) lbl:Dock(TOP) lbl:DockMargin(8, 4, 8, 0) lbl:SetTall(20)
            lbl:SetFont("DAdmin.Small") lbl:SetTextColor(C.textDark) lbl:SetText("No warnings on record.")
            rightScroll:AddItem(lbl)
        else
            for i, w in ipairs(warns) do
                local row = vgui.Create("DButton", rightScroll) row:Dock(TOP) row:SetTall(26) row:DockMargin(2, 1, 2, 0) row:SetText("")
                row.Paint = function(self, ww, h)
                    local hov = self:IsHovered()
                    surface.SetDrawColor(hov and Color(35, 40, 55) or C.bg2) surface.DrawRect(0, 0, ww, h)
                    draw.SimpleText("#" .. tostring(i), "DAdmin.Small", 4, h/2, C.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                    local reason = tostring(w.reason or w.details or "-")
                    if #reason > 18 then reason = string.sub(reason, 1, 16) .. ".." end
                    draw.SimpleText(reason, "DAdmin.Small", 24, h/2, C.yellow, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                    local timeStr = ""
                    if w.timestamp then timeStr = os.date("%m/%d %H:%M", w.timestamp) end
                    draw.SimpleText(timeStr, "DAdmin.Small", ww - 4, h/2, C.textDark, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
                end
                row.DoClick = function()
                    -- Warning detail popup
                    local fr = vgui.Create("EditablePanel")
                    fr:SetSize(340, 180) fr:Center() fr:MakePopup() fr.Paint = function(_, ww, h) UI.PaintPanel(ww, h) end
                    local hdr2 = vgui.Create("DPanel", fr) hdr2:Dock(TOP) hdr2:SetTall(22)
                    hdr2.Paint = function(_, ww, h) UI.PaintHeader(ww, h, "Warning #" .. tostring(i)) end
                    local body = vgui.Create("DPanel", fr) body:Dock(FILL) body.Paint = nil
                    for _, info in ipairs({
                        {"Reason", tostring(w.reason or "-")},
                        {"Admin", tostring(w.admin or "Unknown")},
                        {"Date", w.timestamp and os.date("%Y-%m-%d %H:%M:%S", w.timestamp) or "-"},
                        {"ID", tostring(w.id or "-")},
                    }) do
                        local r = vgui.Create("DPanel", body) r:Dock(TOP) r:SetTall(20) r:DockMargin(8, 2, 8, 0)
                        r.Paint = function(_, ww, h)
                            draw.SimpleText(info[1], "DAdmin.Small", 0, h/2, C.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                            draw.SimpleText(info[2], "DAdmin.Small", ww, h/2, C.text, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
                        end
                    end
                    local btns = vgui.Create("DPanel", fr) btns:Dock(BOTTOM) btns:SetTall(30) btns.Paint = nil
                    local removeBtn = vgui.Create("DButton", btns) removeBtn:Dock(LEFT) removeBtn:DockMargin(8, 4, 0, 4) removeBtn:SetWide(120) removeBtn:SetText("Remove Warning") UI.StyleButton(removeBtn, "danger")
                    removeBtn.DoClick = function()
                        DAdmin.Port.UIAction("remove_warn", { steamid = selected.steamid, warnID = tostring(w.id or i) })
                        addLog("Removed warning #" .. tostring(i) .. " for " .. selected.name, C.yellow)
                        fr:Remove()
                        timer.Simple(0.5, function() if IsValid(rightScroll) then rebuildInfo() end end)
                    end
                    local closeBtn = vgui.Create("DButton", btns) closeBtn:Dock(RIGHT) closeBtn:DockMargin(0, 4, 8, 4) closeBtn:SetWide(80) closeBtn:SetText("Close") UI.StyleButton(closeBtn)
                    closeBtn.DoClick = function() fr:Remove() end
                end
                rightScroll:AddItem(row)
            end
        end

        -- Warning action buttons
        local warnBtns = vgui.Create("DPanel", rightScroll) warnBtns:Dock(TOP) warnBtns:SetTall(28) warnBtns:DockMargin(0, 2, 0, 0) warnBtns.Paint = nil
        local addWarnBtn = vgui.Create("DButton", warnBtns) addWarnBtn:Dock(LEFT) addWarnBtn:SetWide(100) addWarnBtn:DockMargin(2, 2, 2, 2) addWarnBtn:SetText("+ Add Warn") UI.StyleButton(addWarnBtn, "primary")
        addWarnBtn.DoClick = function()
            showPrompt("Warn " .. selected.name, {
                { key = "reason", label = "Reason", placeholder = "Enter reason..." }
            }, function(result)
                DAdmin.Port.UIAction("warn_player", { steamid = selected.steamid, reason = result.reason })
                addLog("warn -> " .. selected.name .. ": " .. result.reason, C.yellow)
                timer.Simple(0.5, function() if IsValid(rightScroll) then rebuildInfo() end end)
            end)
        end
        local clearWarnsBtn = vgui.Create("DButton", warnBtns) clearWarnsBtn:Dock(RIGHT) clearWarnsBtn:SetWide(100) clearWarnsBtn:DockMargin(2, 2, 2, 2) clearWarnsBtn:SetText("Clear All") UI.StyleButton(clearWarnsBtn, "danger")
        clearWarnsBtn.DoClick = function()
            DAdmin.Port.UIAction("clear_player_warns", { steamid = selected.steamid })
            addLog("Cleared warns for " .. selected.name, C.yellow)
            timer.Simple(0.5, function() if IsValid(rightScroll) then rebuildInfo() end end)
        end
        rightScroll:AddItem(warnBtns)

        -- Add some bottom padding
        local pad = vgui.Create("DPanel", rightScroll) pad:Dock(TOP) pad:SetTall(10) pad.Paint = nil
        rightScroll:AddItem(pad)
    end

    rebuildList = function()
        list:Clear()
        local q = string.Trim(string.lower(searchBar:GetValue() or ""))
        for i, p in ipairs(allPlayers) do
            if q == "" or string.find(string.lower(p.name), q, 1, true) or string.find(string.lower(p.steamid or ""), q, 1, true) then
                local row = list:Add("DButton") row:Dock(TOP) row:SetTall(24) row:SetText("")
                row.Paint = function(_, w, h)
                    surface.SetDrawColor(selected == p and C.select or ((i % 2 == 0) and Color(20, 22, 30) or C.bg2)) surface.DrawRect(0, 0, w, h)

                    local x = 8
                    for _, col in ipairs(columns) do
                        local key = tostring(col.key or "")
                        local val = fmtCell(p, key)
                        if key == "ping" and p.ping ~= nil then val = tostring(p.ping) .. "ms" end

                        local colColor = selected == p and color_white or C.textDim
                        local font = "DAdmin.Small"
                        if key == "name" then colColor = selected == p and color_white or C.text; font = "DAdmin.Small" end
                        if key == "rank" then colColor = p.rankColor or C.text end
                        if key == "health" then
                            local hp = p.health or 100
                            colColor = (hp <= 30 and C.red) or (hp <= 70 and C.yellow) or C.green
                        end
                        if key == "ping" then
                            local ping = p.ping or 0
                            colColor = (ping >= 100 and C.red) or (ping >= 60 and C.yellow) or C.green
                        end
                        if key == "role" and val == "Traitor" then colColor = C.red end

                        draw.SimpleText(val, font, x, h/2, colColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                        x = x + math.max(40, (w - 16) * tonumber(col.width or 0.15))
                    end
                end
                row.DoClick = function()
                    if selected == p then
                        selected = nil
                        DAdmin._selectedPlayerId = nil
                    else
                        selected = p
                        DAdmin._selectedPlayerId = p.steamid
                    end
                    rebuildInfo()
                    rebuildList()
                end
                row.DoRightClick = function()
                    local menu = DermaMenu()
                    menu:AddOption("Select " .. tostring(p.name), function()
                        selected = p
                        DAdmin._selectedPlayerId = p.steamid
                        rebuildInfo()
                        rebuildList()
                    end)
                    menu:AddSpacer()
                    menu:AddOption("Goto", function()
                        selected = p
                        DAdmin._selectedPlayerId = p.steamid
                        runPlayerCommand("goto")
                    end)
                    menu:AddOption("Bring", function()
                        selected = p
                        DAdmin._selectedPlayerId = p.steamid
                        runPlayerCommand("bring")
                    end)
                    menu:AddOption("Freeze", function()
                        selected = p
                        DAdmin._selectedPlayerId = p.steamid
                        runPlayerCommand("freeze")
                    end)
                    menu:AddOption("Warn", function()
                        selected = p
                        DAdmin._selectedPlayerId = p.steamid
                        showPrompt("Warn " .. p.name, {
                            { key = "reason", label = "Reason", placeholder = "Enter reason..." }
                        }, function(result)
                            DAdmin.Port.UIAction("warn_player", { steamid = p.steamid, reason = result.reason })
                            addLog("warn -> " .. p.name .. ": " .. result.reason, C.yellow)
                        end)
                    end)
                    menu:AddOption("Kick", function()
                        selected = p
                        DAdmin._selectedPlayerId = p.steamid
                        showPrompt("Kick " .. p.name, {
                            { key = "reason", label = "Reason", placeholder = "Enter reason..." }
                        }, function(result)
                            runPlayerCommand("kick", result.reason)
                        end)
                    end)
                    menu:AddOption("Open Screengrab Viewer", function()
                        DAdmin.OpenScreengrabViewer()
                    end)
                    menu:Open()
                end
            end
        end
    end

    searchBar.OnValueChange = rebuildList
    rebuildList()
    rebuildInfo()
end
