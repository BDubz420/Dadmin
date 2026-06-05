if SERVER then return end
local UI = DAdmin.UI
local C = UI.Colors

function DAdmin.BuildCommandsPanel(parent)
    parent:Clear()
    local commands = DAdmin.Port.GetCommands()
    local selectedCmd, selectedCat, subTab = nil, "all", "info"
    local execLog = {}

    local shell = vgui.Create("DPanel", parent) shell:Dock(FILL) shell.Paint = nil
    local listPanel = vgui.Create("DPanel", shell) listPanel:Dock(LEFT) listPanel:SetWide(190) listPanel.Paint = nil
    local content = vgui.Create("DPanel", shell) content:Dock(FILL) content:DockMargin(5, 0, 0, 0) content.Paint = nil

    -- Categories
    local catSection, catBody = UI.MakeSection(listPanel, "Categories", TOP) catSection:SetTall(100)
    local catColors = { all = C.text, player = C.yellow, movement = C.blue, admin = C.red }
    local catButtons = {}
    for _, cat in ipairs({"all", "player", "movement", "admin"}) do
        local b = vgui.Create("DButton", catBody) b:Dock(TOP) b:DockMargin(4, 2, 4, 0) b:SetTall(18) b:SetText(cat)
        UI.StyleButton(b, cat == selectedCat and "active" or nil)
        catButtons[cat] = b
    end

    -- Command list
    local cmdSection, cmdBody = UI.MakeSection(listPanel, "Commands", FILL, {0, 5, 0, 0})
    local cmdList = vgui.Create("DScrollPanel", cmdBody) cmdList:Dock(FILL)

    -- Sub-tabs
    local subBar = vgui.Create("DPanel", content) subBar:Dock(TOP) subBar:SetTall(24) subBar.Paint = nil
    local subButtons = {}
    for _, t in ipairs({"info", "execute", "guide"}) do
        local b = vgui.Create("DButton", subBar) b:Dock(LEFT) b:DockMargin(0, 3, 4, 3) b:SetWide(60) b:SetText(t:sub(1,1):upper()..t:sub(2))
        UI.StyleButton(b, t == subTab and "active" or nil)
        subButtons[t] = b
    end

    local contentBody = vgui.Create("DPanel", content) contentBody:Dock(FILL) contentBody:DockMargin(0, 5, 0, 0) contentBody.Paint = nil

    local showInfo, showExecute, showGuide, showContent

    showInfo = function()
        contentBody:Clear()
        local section, body = UI.MakeSection(contentBody, "Command Info", FILL)
        if not selectedCmd then
            local lbl = vgui.Create("DLabel", body) lbl:Dock(TOP) lbl:DockMargin(10, 10, 10, 0)
            lbl:SetFont("DAdmin.Normal") lbl:SetTextColor(C.textDark) lbl:SetWrap(true) lbl:SetText("Select a command to view details.")
            return
        end
        for _, pair in ipairs({
            {"Name", selectedCmd.name},
            {"Category", selectedCmd.cat or "admin"},
            {"Permission", selectedCmd.perm or "none"},
            {"Usage", selectedCmd.usage or ""},
            {"Description", selectedCmd.desc or "No description."},
        }) do
            local row = vgui.Create("DPanel", body) row:Dock(TOP) row:SetTall(22) row:DockMargin(6, 0, 6, 0)
            row.Paint = function(_, w, h)
                draw.SimpleText(pair[1], "DAdmin.Small", 0, h / 2, C.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                draw.SimpleText(pair[2], "DAdmin.Small", w, h / 2, C.text, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
            end
        end

        if selectedCmd.args and #selectedCmd.args > 0 then
            local argsLabel = vgui.Create("DLabel", body) argsLabel:Dock(TOP) argsLabel:DockMargin(6, 12, 6, 0)
            argsLabel:SetFont("DAdmin.Small") argsLabel:SetTextColor(C.textDim) argsLabel:SetText("Arguments:")
            for _, a in ipairs(selectedCmd.args) do
                local aRow = vgui.Create("DPanel", body) aRow:Dock(TOP) aRow:SetTall(18) aRow:DockMargin(12, 0, 6, 0)
                aRow.Paint = function(_, w, h) draw.SimpleText(a, "DAdmin.Small", 0, h / 2, C.blue, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER) end
            end
        end

        local execBtn = vgui.Create("DButton", body) execBtn:Dock(TOP) execBtn:DockMargin(6, 14, 6, 0) execBtn:SetTall(22)
        execBtn:SetText("Execute this command ->") UI.StyleButton(execBtn, "primary")
        execBtn.DoClick = function()
            subTab = "execute"
            for k, b in pairs(subButtons) do b._variant = k == "execute" and "active" or nil end
            showExecute()
        end
    end

    showExecute = function()
        contentBody:Clear()
        local section, body = UI.MakeSection(contentBody, "Execute: " .. (selectedCmd and selectedCmd.name or ""), FILL)
        if not selectedCmd then
            local lbl = vgui.Create("DLabel", body) lbl:Dock(TOP) lbl:DockMargin(10, 10, 10, 0)
            lbl:SetFont("DAdmin.Normal") lbl:SetTextColor(C.textDark) lbl:SetWrap(true) lbl:SetText("Select a command first.")
            return
        end

        -- Usage display
        local usagePanel = vgui.Create("DPanel", body) usagePanel:Dock(TOP) usagePanel:SetTall(24) usagePanel:DockMargin(8, 4, 8, 0)
        usagePanel.Paint = function(_, w, h)
            surface.SetDrawColor(26, 29, 38, 255) surface.DrawRect(0, 0, w, h)
            draw.SimpleText(selectedCmd.usage or ("dadmin " .. selectedCmd.name), "DAdmin.Small", 8, h / 2, C.blue, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end

        -- Build arg inputs based on command definition
        local argInputs = {}
        local cmdArgs = selectedCmd.args or {}

        -- Target player selector (for commands that take a player target)
        if selectedCmd.hasTarget then
            local targetRow = vgui.Create("DPanel", body) targetRow:Dock(TOP) targetRow:SetTall(28) targetRow:DockMargin(8, 6, 8, 0) targetRow.Paint = nil
            local tLabel = vgui.Create("DLabel", targetRow) tLabel:Dock(LEFT) tLabel:SetWide(80) tLabel:SetFont("DAdmin.Small") tLabel:SetTextColor(C.textDim) tLabel:SetText("Target")
            local players = DAdmin.Port.GetPlayers()
            local targetCombo = vgui.Create("DComboBox", targetRow) targetCombo:Dock(FILL) targetCombo:SetTall(22)
            targetCombo:AddChoice("Player name / @all / @admins / ^", "")
            for _, p in ipairs(players) do targetCombo:AddChoice(p.name .. " [" .. p.rank .. "]", p.name) end
            argInputs[#argInputs + 1] = { type = "combo", input = targetCombo, key = "target" }
        end

        -- Parse command args for separate input boxes
        local argDefs = {}
        for _, a in ipairs(cmdArgs) do
            local argName = tostring(a):gsub("[<>%[%]]", "")
            local isOptional = tostring(a):find("^%[")
            if argName ~= "target" and argName ~= "player" then
                argDefs[#argDefs + 1] = { name = argName, optional = isOptional, raw = a }
            end
        end

        -- If no arg defs but command likely needs reason/duration, add smart defaults
        if #argDefs == 0 then
            local name = selectedCmd.name
            if name == "kick" or name == "warn" or name == "mute" or name == "gag" then
                argDefs = {{ name = "reason", optional = true }}
            elseif name == "ban" then
                argDefs = {{ name = "duration", optional = false }, { name = "reason", optional = true }}
            elseif name == "setrank" then
                argDefs = {{ name = "rank", optional = false }}
            end
        end

        for _, def in ipairs(argDefs) do
            local argRow = vgui.Create("DPanel", body) argRow:Dock(TOP) argRow:SetTall(28) argRow:DockMargin(8, 4, 8, 0) argRow.Paint = nil
            local aLabel = vgui.Create("DLabel", argRow) aLabel:Dock(LEFT) aLabel:SetWide(80) aLabel:SetFont("DAdmin.Small")
            aLabel:SetTextColor(C.textDim)
            aLabel:SetText(def.name:sub(1,1):upper() .. def.name:sub(2))
            local aEntry = vgui.Create("DTextEntry", argRow) aEntry:Dock(FILL) aEntry:SetTall(22)
            aEntry:SetPlaceholderText(def.optional and ("[" .. def.name .. "]") or def.name)
            UI.StyleTextEntry(aEntry)
            argInputs[#argInputs + 1] = { type = "text", input = aEntry, key = def.name }
        end

        -- Execute button
        local execBtn = vgui.Create("DButton", body) execBtn:Dock(TOP) execBtn:DockMargin(8, 8, 8, 0) execBtn:SetTall(28)
        execBtn:SetText("Execute Command") UI.StyleButton(execBtn, "primary")

        local function doExec()
            local args = {}
            for _, ai in ipairs(argInputs) do
                if ai.type == "combo" then
                    local _, data = ai.input:GetSelected()
                    if data and data ~= "" then args[#args + 1] = data end
                else
                    local val = string.Trim(ai.input:GetValue() or "")
                    if val ~= "" then args[#args + 1] = val end
                end
            end
            DAdmin.Port.UIAction("command", { command = selectedCmd.name, args = args })
            execLog[#execLog + 1] = { cmd = selectedCmd.name, args = table.concat(args, " "), time = os.date("%H:%M:%S") }
            showExecute()
        end
        execBtn.DoClick = doExec

        -- Console output
        local consoleLabel = vgui.Create("DLabel", body) consoleLabel:Dock(TOP) consoleLabel:DockMargin(8, 10, 8, 0)
        consoleLabel:SetFont("DAdmin.Small") consoleLabel:SetTextColor(C.textDim) consoleLabel:SetText("Console output will appear here...")
        local console = vgui.Create("DScrollPanel", body) console:Dock(FILL) console:DockMargin(8, 2, 8, 4)
        for _, entry in ipairs(execLog) do
            local row = console:Add("DPanel") row:Dock(TOP) row:SetTall(18)
            row.Paint = function(_, w, h)
                draw.SimpleText("[" .. entry.time .. "] > " .. entry.cmd .. " " .. entry.args, "DAdmin.Small", 0, h / 2, C.green, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end
        end
        if #execLog > 0 then
            local kids = console:GetCanvas():GetChildren()
            if kids and #kids > 0 then console:ScrollToChild(kids[#kids]) end
        end
    end

    showGuide = function()
        contentBody:Clear()
        local section, body = UI.MakeSection(contentBody, "Usage Guide", FILL)
        local guideText = {
            {"SELECTORS", C.blue},
            {"  @all    - targets all players", C.text},
            {"  @admin  - targets all admins", C.text},
            {"  ^       - targets yourself", C.text},
            {"  name    - partial name match", C.text},
            {""},
            {"DURATION FORMAT", C.blue},
            {"  30s    - 30 seconds", C.text},
            {"  10m    - 10 minutes", C.text},
            {"  1h     - 1 hour", C.text},
            {"  1d     - 1 day", C.text},
            {"  1w     - 1 week", C.text},
            {"  perm   - permanent", C.text},
            {"  1h30m  - 1 hour 30 minutes", C.text},
            {""},
            {"ARGUMENT SYNTAX", C.blue},
            {"  <arg>  - required argument", C.text},
            {"  [arg]  - optional argument", C.text},
        }
        for _, g in ipairs(guideText) do
            local row = vgui.Create("DPanel", body) row:Dock(TOP) row:SetTall(16) row:DockMargin(8, 0, 8, 0)
            row.Paint = function(_, w, h)
                draw.SimpleText(g[1] or "", "DAdmin.Small", 0, h / 2, g[2] or C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end
        end
    end

    showContent = function()
        if subTab == "info" then showInfo()
        elseif subTab == "execute" then showExecute()
        elseif subTab == "guide" then showGuide()
        end
    end

    for k, btn in pairs(subButtons) do
        btn.DoClick = function()
            subTab = k
            for k2, b in pairs(subButtons) do b._variant = k2 == k and "active" or nil end
            showContent()
        end
    end

    local function rebuildCmdList()
        cmdList:Clear()
        for _, cmd in ipairs(commands) do
            if selectedCat ~= "all" and cmd.cat ~= selectedCat then continue end
            local row = cmdList:Add("DButton") row:Dock(TOP) row:SetTall(22) row:DockMargin(4, 1, 4, 0) row:SetText("")
            row.Paint = function(_, w, h)
                surface.SetDrawColor(selectedCmd == cmd and C.select or C.bg2) surface.DrawRect(0, 0, w, h)
                surface.SetDrawColor(catColors[cmd.cat] or C.text) surface.DrawRect(0, 0, 3, h)
                draw.SimpleText(cmd.name, "DAdmin.Small", 8, h / 2, selectedCmd == cmd and color_white or C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end
            row.DoClick = function()
                selectedCmd = (selectedCmd == cmd) and nil or cmd
                showContent()
                rebuildCmdList()
            end
        end
    end

    for cat, btn in pairs(catButtons) do
        btn.DoClick = function()
            selectedCat = cat
            for k, b in pairs(catButtons) do b._variant = k == cat and "active" or nil end
            rebuildCmdList()
        end
    end

    rebuildCmdList() showContent()
end
