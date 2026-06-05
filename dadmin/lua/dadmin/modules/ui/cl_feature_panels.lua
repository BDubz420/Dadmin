if SERVER then return end
DAdmin = DAdmin or {}
DAdmin.MegaLogsClient = DAdmin.MegaLogsClient or { categories = {}, entries = {} }
DAdmin.FeatureSettingsClient = DAdmin.FeatureSettingsClient or {}
DAdmin.PermissionMatrixClient = DAdmin.PermissionMatrixClient or {}

net.Receive("DAdmin_MegaLogs_Send", function() DAdmin.MegaLogsClient = net.ReadTable() or {} end)
net.Receive("DAdmin_FeatureSettings_Send", function() DAdmin.FeatureSettingsClient = net.ReadTable() or {} end)
net.Receive("DAdmin_PermissionMatrix_Send", function() DAdmin.PermissionMatrixClient = net.ReadTable() or {} end)

local function reqLogs(cat, search)
    net.Start("DAdmin_MegaLogs_Request") net.WriteString(cat or "all") net.WriteString(search or "") net.WriteUInt(500, 16) net.SendToServer()
end

function DAdmin.BuildLogsPanel(parent)
    parent:Clear()
    local UI, C = DAdmin.UI, DAdmin.UI.Colors
    local selectedCat, searchText = "all", ""
    local shell = vgui.Create("DPanel", parent) shell:Dock(FILL) shell.Paint = nil
    local cats = vgui.Create("DScrollPanel", shell) cats:Dock(LEFT) cats:SetWide(170) cats:DockMargin(0,0,6,0)
    local main = vgui.Create("DPanel", shell) main:Dock(FILL) main.Paint = nil
    local top = vgui.Create("DPanel", main) top:Dock(TOP) top:SetTall(30) top.Paint = nil
    local search = vgui.Create("DTextEntry", top) search:Dock(FILL) search:DockMargin(0,3,6,3) search:SetPlaceholderText("Search every log field...") UI.StyleTextEntry(search)
    local refresh = vgui.Create("DButton", top) refresh:Dock(RIGHT) refresh:SetWide(90) refresh:SetText("Refresh") UI.StyleButton(refresh,"primary")
    local list = vgui.Create("DScrollPanel", main) list:Dock(FILL)
    local function rebuild()
        cats:Clear()
        local all = vgui.Create("DButton", cats) all:Dock(TOP) all:DockMargin(0,0,0,4) all:SetTall(24) all:SetText("All Logs") UI.StyleButton(all, selectedCat=="all" and "active" or nil)
        all.DoClick=function() selectedCat="all"; reqLogs(selectedCat, searchText); timer.Simple(.2,rebuild) end
        local categories = DAdmin.MegaLogsClient.categories or {
            commands="Commands", punishments="Punishments", chat="Chat", connections="Connections", damage="Damage", deaths="Deaths", props="Props", tools="Tools", reports="Reports", cases="Cases", ranks="Ranks", permissions="Permissions", settings="Settings", safezones="Safezones", playtime="Playtime", guard="Guard", system="System"
        }
        local keys={}
        for k in pairs(categories) do keys[#keys+1]=k end
        table.sort(keys)
        for _, k in ipairs(keys) do
            local b = vgui.Create("DButton", cats) b:Dock(TOP) b:DockMargin(0,0,0,4) b:SetTall(24) b:SetText(categories[k]) UI.StyleButton(b, selectedCat==k and "active" or nil)
            b.DoClick=function() selectedCat=k; reqLogs(selectedCat, searchText); timer.Simple(.2,rebuild) end
        end
        list:Clear()
        for _, e in ipairs(DAdmin.MegaLogsClient.entries or {}) do
            local row = vgui.Create("DButton", list) row:Dock(TOP) row:DockMargin(0,0,0,3) row:SetTall(46) row:SetText("")
            row.Paint=function(_,w,h)
                surface.SetDrawColor(18,20,28,235) surface.DrawRect(0,0,w,h)
                surface.SetDrawColor(C.border) surface.DrawOutlinedRect(0,0,w,h,1)
                draw.SimpleText("["..tostring(e.category).."] "..tostring(e.action), "DAdmin.Title", 8, 8, C.blue)
                draw.SimpleText(tostring(e.time).."  "..tostring(e.actor).." -> "..tostring(e.target), "DAdmin.Small", 8, 25, C.text)
                draw.SimpleText(string.sub(tostring(e.details or ""),1,80), "DAdmin.Small", w-8, 25, C.textDim, TEXT_ALIGN_RIGHT)
            end
        end
    end
    refresh.DoClick=function() reqLogs(selectedCat, searchText) timer.Simple(.2,rebuild) end
    search.OnChange=function(s) searchText=s:GetValue(); reqLogs(selectedCat, searchText); timer.Simple(.25,rebuild) end
    reqLogs("all",""); timer.Simple(.25,rebuild)
end

local function reqSettings()
    net.Start("DAdmin_FeatureSettings_Request") net.SendToServer()
end

function DAdmin.BuildSettingsPanel(parent)
    parent:Clear()
    local UI, C = DAdmin.UI, DAdmin.UI.Colors
    reqSettings()
    local scroll = vgui.Create("DScrollPanel", parent) scroll:Dock(FILL)
    local settings = DAdmin.FeatureSettingsClient or {}
    local function save()
        net.Start("DAdmin_FeatureSettings_Save") net.WriteTable(settings) net.SendToServer()
    end
    local function addSection(title, rows)
        local sec, body = UI.MakeSection(scroll, title, TOP, {0,0,0,6}) sec:SetTall(32 + (#rows * 30) + 38)
        for _, row in ipairs(rows) do
            local p = vgui.Create("DPanel", body) p:Dock(TOP) p:SetTall(28) p.Paint=function(_,w,h) draw.SimpleText(row.label, "DAdmin.Normal", 8, h/2, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER) end
            if row.kind == "toggle" then
                local b=vgui.Create("DButton", p) b:Dock(RIGHT) b:DockMargin(0,4,8,4) b:SetWide(60)
                local function t() b:SetText(settings[row.key] and "ON" or "OFF"); b._variant=settings[row.key] and "primary" or nil end
                UI.StyleButton(b); t(); b.DoClick=function() settings[row.key]=not settings[row.key]; t() end
            else
                local e=vgui.Create("DTextEntry", p) e:Dock(RIGHT) e:DockMargin(0,3,8,3) e:SetWide(row.width or 120) e:SetText(tostring(settings[row.key] or row.default or "")) UI.StyleTextEntry(e)
                e.OnChange=function(s) settings[row.key]=s:GetValue() end
            end
        end
        local b=vgui.Create("DButton", body) b:Dock(BOTTOM) b:DockMargin(8,6,8,6) b:SetTall(24) b:SetText("Save "..title) UI.StyleButton(b,"primary") b.DoClick=save
    end
    timer.Simple(.25, function()
        if not IsValid(scroll) then return end
        if IsValid(scroll) then scroll:Clear() else return end; settings = DAdmin.FeatureSettingsClient or {}
        addSection("Storage / Database", {
            {label="Use SQLite backend (toggle)", key="sqlite_enabled", kind="toggle"},
            {label="Enable external database mode", key="database_enabled", kind="toggle"},
            {label="Storage backend", key="storage_backend", default="json"},
            {label="Database driver", key="database_driver", default="sqlite"},
        })
        addSection("Playtime / UTime HUD", {
            {label="Enable playtime tracking", key="playtime_enabled", kind="toggle"},
            {label="Enable top-right HUD", key="playtime_hud_enabled", kind="toggle"},
            {label="HUD primary color hex", key="playtime_hud_color", default="4A90D9"},
            {label="HUD accent color hex", key="playtime_hud_accent", default="90AAE9"},
        })
        addSection("Safezones", {
            {label="Enable safezones", key="safezones_enabled", kind="toggle"},
            {label="Enable safezone screen UI", key="safezone_ui_enabled", kind="toggle"},
            {label="Default height", key="safezone_default_height", default="160"},
            {label="Default HUD color", key="safezone_ui_color", default="4A90D9"},
        })
        addSection("Large Scale Logs", {
            {label="Enable logs", key="logs_enabled", kind="toggle"},
            {label="Max entries per category", key="logs_max_entries", default="25000"},
            {label="Logs storage backend", key="logs_storage_backend", default="json"},
        })
        addSection("Notification Visibility", {
            {label="Notify warnings", key="notify_warn", kind="toggle"},
            {label="Notify rank changes", key="notify_rank", kind="toggle"},
            {label="Notify bring/goto", key="notify_bring", kind="toggle"},
            {label="Notify spectate", key="notify_spectate", kind="toggle"},
            {label="Notify safezone events", key="notify_safezone", kind="toggle"},
            {label="Notify playtime events", key="notify_playtime", kind="toggle"},
        })
    end)
end

local function reqMatrix() net.Start("DAdmin_PermissionMatrix_Request") net.SendToServer() end

function DAdmin.BuildPermissionsPanel(parent)
    parent:Clear()
    local UI, C = DAdmin.UI, DAdmin.UI.Colors
    local top=vgui.Create("DPanel", parent) top:Dock(TOP) top:SetTall(30) top.Paint=nil
    local search=vgui.Create("DTextEntry", top) search:Dock(FILL) search:DockMargin(0,3,6,3) search:SetPlaceholderText("Search permissions / commands...") UI.StyleTextEntry(search)
    local refresh=vgui.Create("DButton", top) refresh:Dock(RIGHT) refresh:SetWide(90) refresh:SetText("Refresh") UI.StyleButton(refresh,"primary")
    local scroll=vgui.Create("DScrollPanel", parent) scroll:Dock(FILL)
    local filter=""
    local function setPerm(rank, perm, enabled)
        net.Start("DAdmin_PermissionMatrix_Set") net.WriteString(rank) net.WriteString(perm) net.WriteBool(enabled) net.SendToServer()
        timer.Simple(.25, function() reqMatrix() end)
    end
    local function rebuild()
        if not IsValid(scroll) then return end
        scroll:Clear()
        local data = DAdmin.PermissionMatrixClient or {}
        local ranks = data.ranks or {}
        local perms = data.permissions or {}
        local matrix = data.matrix or {}

        local header = vgui.Create("DPanel", scroll)
        header:Dock(TOP)
        header:DockMargin(0,0,0,4)
        header:SetTall(28)
        header.Paint = function(_,w,h)
            surface.SetDrawColor(28,32,42,245) surface.DrawRect(0,0,w,h)
            draw.SimpleText("Permission", "DAdmin.Title", 8, h/2, C.blue, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end

        for _, perm in ipairs(perms) do
            if filter == "" or string.find(string.lower(perm), filter, 1, true) then
                local row=vgui.Create("DPanel", scroll) row:Dock(TOP) row:DockMargin(0,0,0,3) row:SetTall(34)
                row.Paint=function(_,w,h)
                    surface.SetDrawColor(18,20,28,235) surface.DrawRect(0,0,w,h)
                    surface.SetDrawColor(C.border) surface.DrawOutlinedRect(0,0,w,h,1)
                    draw.SimpleText(perm, "DAdmin.Normal", 8, h/2, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                end
                local holder=vgui.Create("DPanel", row) holder:Dock(RIGHT) holder:SetWide(math.max(260, #ranks*62)) holder.Paint=nil
                for _, r in ipairs(ranks) do
                    local b=vgui.Create("DButton", holder) b:Dock(LEFT) b:DockMargin(3,5,0,5) b:SetWide(58)
                    local on = matrix[r.id] and matrix[r.id][perm]
                    b:SetText((on and "ON " or "OFF ")..string.sub(r.id,1,5)); UI.StyleButton(b, on and "primary" or nil)
                    b.DoClick=function() setPerm(r.id, perm, not on) end
                end
            end
        end
    end
    refresh.DoClick=function() reqMatrix(); timer.Simple(.25,rebuild) end
    search.OnChange=function(s) filter=string.lower(s:GetValue() or ""); rebuild() end
    reqMatrix(); timer.Simple(.35,rebuild)
end


function DAdmin.BuildCommandsPanel(parent)
    parent:Clear()
    local UI, C = DAdmin.UI, DAdmin.UI.Colors
    local searchText, category = "", "All"
    local shell=vgui.Create("DPanel", parent) shell:Dock(FILL) shell.Paint=nil
    local left=vgui.Create("DScrollPanel", shell) left:Dock(LEFT) left:SetWide(155) left:DockMargin(0,0,6,0)
    local main=vgui.Create("DPanel", shell) main:Dock(FILL) main.Paint=nil
    local top=vgui.Create("DPanel", main) top:Dock(TOP) top:SetTall(30) top.Paint=nil
    local search=vgui.Create("DTextEntry", top) search:Dock(FILL) search:DockMargin(0,3,0,3) search:SetPlaceholderText("Search commands...") UI.StyleTextEntry(search)
    local list=vgui.Create("DScrollPanel", main) list:Dock(FILL)
    local function getCommands()
        local out={}
        if DAdmin.GetCommandList and isfunction(DAdmin.GetCommandList) then
            local ok, res = pcall(DAdmin.GetCommandList)
            if ok and istable(res) then out = res end
        end

        if table.Count(out) <= 0 then
            for k, c in pairs(DAdmin.Commands or {}) do
                if istable(c) then
                    c.name = c.name or c.command or c.id or k
                    c.description = c.description or c.desc or "No description."
                    c.category = c.category or "General"
                    out[#out+1] = c
                elseif isfunction(c) then
                    out[#out+1] = {
                        name = tostring(k),
                        description = "Legacy command",
                        category = "General",
                        run = c
                    }
                end
            end
        end

        local clean = {}
        for _, c in pairs(out or {}) do
            if istable(c) and isstring(c.name) then
                clean[#clean+1] = c
            end
        end

        table.sort(clean, function(a,b)
            return string.lower(a.name or "") < string.lower(b.name or "")
        end)

        return clean
    end
    local function runCommand(cmd)
        Derma_StringRequest("Run "..cmd.name, "Arguments separated by spaces. Leave blank for none.", "", function(val)
            net.Start("DAdmin_RunCommand")
            net.WriteString(cmd.name)
            net.WriteTable(string.Explode(" ", val or "", false))
            net.SendToServer()
        end)
    end
    local function rebuild()
        if not IsValid(left) or not IsValid(list) then return end
        left:Clear(); list:Clear()
        local cats={All=true}
        for _,cmd in ipairs(getCommands()) do
            cats[cmd.category or "General"] = true
        end
        local keys={}
        for k in pairs(cats) do keys[#keys+1]=k end
        table.sort(keys)
        for _,k in ipairs(keys) do
            local b=vgui.Create("DButton", left) b:Dock(TOP) b:DockMargin(0,0,0,4) b:SetTall(24) b:SetText(k) UI.StyleButton(b, category==k and "active" or nil)
            b.DoClick=function() category=k; rebuild() end
        end
        for _,cmd in ipairs(getCommands()) do
            local hay=string.lower((cmd.name or "").." "..(cmd.description or "").." "..(cmd.category or ""))
            if (category=="All" or category==(cmd.category or "General")) and (searchText=="" or string.find(hay, searchText, 1, true)) then
                local row=vgui.Create("DPanel", list) row:Dock(TOP) row:DockMargin(0,0,0,4) row:SetTall(46)
                row.Paint=function(_,w,h)
                    surface.SetDrawColor(18,20,28,235) surface.DrawRect(0,0,w,h)
                    surface.SetDrawColor(C.border) surface.DrawOutlinedRect(0,0,w,h,1)
                    draw.SimpleText(cmd.name or "command", "DAdmin.Title", 8, 9, C.blue)
                    draw.SimpleText(cmd.description or "No description.", "DAdmin.Small", 8, 28, C.textDim)
                end
                local exec=vgui.Create("DButton", row) exec:Dock(RIGHT) exec:DockMargin(0,8,8,8) exec:SetWide(86) exec:SetText("Run") UI.StyleButton(exec,"primary")
                exec.DoClick=function() runCommand(cmd) end
            end
        end
    end
    search.OnChange=function(s) searchText=string.lower(s:GetValue() or ""); rebuild() end
    rebuild()
end


-- DAdmin refined Commands + Permissions panels.
-- Kept here because cl_feature_panels.lua is loaded after the base UI panel files.

local function DAdmin_RefinedStyleRow(panel, C)
    panel.Paint = function(_, w, h)
        surface.SetDrawColor(12, 15, 24, 245)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(C.border)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end
end

local function DAdmin_RefinedGetCommands()
    local out = {}

    if DAdmin.Port and DAdmin.Port.GetCommands then
        for _, c in ipairs(DAdmin.Port.GetCommands() or {}) do
            if istable(c) and isstring(c.name) and c.name ~= "" then
                out[#out + 1] = {
                    name = tostring(c.name),
                    description = tostring(c.desc or c.description or "No description."),
                    category = tostring(c.cat or c.category or "General"),
                    permission = tostring(c.perm or c.permission or c.name),
                    usage = tostring(c.usage or ("dadmin " .. tostring(c.name))),
                    args = c.args or {},
                    hasTarget = c.hasTarget == true
                }
            end
        end
    end

    if #out <= 0 and DAdmin.GetCommandList and isfunction(DAdmin.GetCommandList) then
        local ok, list = pcall(DAdmin.GetCommandList)
        if ok and istable(list) then
            for _, c in pairs(list) do
                if istable(c) and isstring(c.name) and isfunction(c.run or c.execute) then
                    out[#out + 1] = {
                        name = tostring(c.name),
                        description = tostring(c.description or c.desc or "No description."),
                        category = tostring(c.category or "General"),
                        permission = tostring(c.permission or c.name),
                        usage = "dadmin " .. tostring(c.name),
                        args = c.args or c.arguments or {},
                        hasTarget = false
                    }
                end
            end
        end
    end

    if #out <= 0 then
        for name, c in pairs(DAdmin.Commands or {}) do
            if istable(c) and isstring(c.name or name) and isfunction(c.run or c.execute) then
                out[#out + 1] = {
                    name = tostring(c.name or name),
                    description = tostring(c.description or c.desc or "No description."),
                    category = tostring(c.category or "General"),
                    permission = tostring(c.permission or name),
                    usage = "dadmin " .. tostring(c.name or name),
                    args = c.args or c.arguments or {},
                    hasTarget = false
                }
            end
        end
    end

    table.sort(out, function(a, b) return string.lower(a.name or "") < string.lower(b.name or "") end)
    return out
end

function DAdmin.BuildCommandsPanel(parent)
    parent:Clear()
    local UI, C = DAdmin.UI, DAdmin.UI.Colors
    local selectedCat, searchText = "all", ""

    local shell = vgui.Create("DPanel", parent)
    shell:Dock(FILL)
    shell.Paint = nil

    local left = vgui.Create("DPanel", shell)
    left:Dock(LEFT)
    left:SetWide(160)
    left:DockMargin(0, 0, 6, 0)
    left.Paint = nil

    local categories = vgui.Create("DScrollPanel", left)
    categories:Dock(FILL)

    local main = vgui.Create("DPanel", shell)
    main:Dock(FILL)
    main.Paint = nil

    local top = vgui.Create("DPanel", main)
    top:Dock(TOP)
    top:SetTall(30)
    top.Paint = nil

    local search = vgui.Create("DTextEntry", top)
    search:Dock(FILL)
    search:DockMargin(0, 3, 0, 3)
    search:SetPlaceholderText("Search commands...")
    UI.StyleTextEntry(search)

    local list = vgui.Create("DScrollPanel", main)
    list:Dock(FILL)

    local function normCat(cat)
        cat = string.lower(tostring(cat or "general"))
        if cat == "player" then return "Player" end
        if cat == "movement" then return "Movement" end
        if cat == "moderation" then return "Moderation" end
        if cat == "admin" then return "Admin" end
        return string.upper(string.sub(cat, 1, 1)) .. string.sub(cat, 2)
    end

    local function commandMatches(cmd)
        local hay = string.lower((cmd.name or "") .. " " .. (cmd.description or "") .. " " .. (cmd.permission or "") .. " " .. (cmd.usage or ""))
        local cat = normCat(cmd.category)
        return (selectedCat == "all" or selectedCat == cat) and (searchText == "" or string.find(hay, searchText, 1, true) ~= nil)
    end

    local function runCommand(cmd)
        Derma_StringRequest("Run " .. cmd.name, cmd.usage or "Arguments separated by spaces.", "", function(val)
            local args = string.Explode(" ", val or "", false)
            if DAdmin.Port and DAdmin.Port.UIAction then
                DAdmin.Port.UIAction("command", { command = cmd.name, args = args })
            else
                net.Start("DAdmin_RunCommand")
                net.WriteString(cmd.name)
                net.WriteTable(args)
                net.SendToServer()
            end
        end)
    end

    local function rebuild()
        if not IsValid(categories) or not IsValid(list) then return end
        categories:Clear()
        list:Clear()

        local commands = DAdmin_RefinedGetCommands()
        local catSet = { All = "all" }
        for _, cmd in ipairs(commands) do
            local c = normCat(cmd.category)
            catSet[c] = c
        end

        local keys = {}
        for label in pairs(catSet) do keys[#keys + 1] = label end
        table.sort(keys, function(a, b)
            if a == "All" then return true end
            if b == "All" then return false end
            return a < b
        end)

        for _, label in ipairs(keys) do
            local id = catSet[label]
            local b = vgui.Create("DButton", categories)
            b:Dock(TOP)
            b:DockMargin(0, 0, 0, 4)
            b:SetTall(24)
            b:SetText(label)
            UI.StyleButton(b, selectedCat == id and "active" or nil)
            b.DoClick = function()
                selectedCat = id
                rebuild()
            end
        end

        local drawn = 0
        for _, cmd in ipairs(commands) do
            if commandMatches(cmd) then
                drawn = drawn + 1
                local row = vgui.Create("DPanel", list)
                row:Dock(TOP)
                row:DockMargin(0, 0, 0, 4)
                row:SetTall(48)
                DAdmin_RefinedStyleRow(row, C)

                row.PaintOver = function(_, w, h)
                    draw.SimpleText(cmd.name, "DAdmin.Title", 8, 13, C.blue, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                    draw.SimpleText(cmd.description or "No description.", "DAdmin.Small", 8, 31, C.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                    draw.SimpleText(cmd.permission or "", "DAdmin.Small", w - 104, 14, C.textDim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
                end

                local run = vgui.Create("DButton", row)
                run:Dock(RIGHT)
                run:DockMargin(0, 8, 8, 8)
                run:SetWide(86)
                run:SetText("Run")
                UI.StyleButton(run, "primary")
                run.DoClick = function() runCommand(cmd) end
            end
        end

        if drawn == 0 then
            local empty = vgui.Create("DLabel", list)
            empty:Dock(TOP)
            empty:DockMargin(8, 8, 8, 0)
            empty:SetFont("DAdmin.Normal")
            empty:SetTextColor(C.textDim)
            empty:SetText(#commands == 0 and "No commands were received from the server yet. Refresh or reopen the menu." or "No commands match your filter.")
            empty:SetTall(24)
        end
    end

    search.OnChange = function(s)
        searchText = string.lower(s:GetValue() or "")
        rebuild()
    end

    rebuild()
end

local function DAdmin_RefinedPermissionState()
    local groups = {}
    local categories = {}
    local matrix = {}

    if DAdmin.Port then
        groups = DAdmin.Port.GetPermissionGroups and (DAdmin.Port.GetPermissionGroups() or {}) or {}
        categories = DAdmin.Port.GetPermissionCategories and (DAdmin.Port.GetPermissionCategories() or {}) or {}
        matrix = DAdmin.Port.GetPermissionMatrix and (DAdmin.Port.GetPermissionMatrix() or {}) or {}
    end

    if #groups <= 0 then
        local data = DAdmin.PermissionMatrixClient or {}
        for _, r in ipairs(data.ranks or {}) do
            groups[#groups + 1] = { id = r.id, label = r.name or r.id }
        end
        local flat = {}
        for _, p in ipairs(data.permissions or {}) do flat[#flat + 1] = { id = p, label = p } end
        categories = { { name = "Permissions", perms = flat } }
        matrix = data.matrix or {}
    end

    return groups, categories, matrix
end

function DAdmin.BuildPermissionsPanel(parent)
    parent:Clear()
    local UI, C = DAdmin.UI, DAdmin.UI.Colors
    local filterText = ""

    local top = vgui.Create("DPanel", parent)
    top:Dock(TOP)
    top:SetTall(30)
    top.Paint = nil

    local search = vgui.Create("DTextEntry", top)
    search:Dock(FILL)
    search:DockMargin(0, 3, 6, 3)
    search:SetPlaceholderText("Search permissions / commands...")
    UI.StyleTextEntry(search)

    local refresh = vgui.Create("DButton", top)
    refresh:Dock(RIGHT)
    refresh:SetWide(90)
    refresh:SetText("Refresh")
    UI.StyleButton(refresh, "primary")

    local scroll = vgui.Create("DScrollPanel", parent)
    scroll:Dock(FILL)

    local function hasPerm(perms, id)
        if not istable(perms) then return false end
        if perms[id] == true then return true end
        for _, v in ipairs(perms) do
            if tostring(v) == tostring(id) then return true end
        end
        return false
    end

    local function setPerm(rank, perm, enabled)
        if DAdmin.Port and DAdmin.Port.UIAction then
            DAdmin.Port.UIAction("permission_toggle", { rank = rank, permission = perm, enabled = enabled })
            DAdmin.Port.UIAction("save_permissions", { rank = rank, permission = perm, enabled = enabled })
        else
            net.Start("DAdmin_PermissionMatrix_Set")
            net.WriteString(rank)
            net.WriteString(perm)
            net.WriteBool(enabled)
            net.SendToServer()
            timer.Simple(0.25, function() if reqMatrix then reqMatrix() end end)
        end
    end

    local function drawHeader(groups)
        local header = vgui.Create("DPanel", scroll)
        header:Dock(TOP)
        header:DockMargin(0, 0, 0, 4)
        header:SetTall(30)
        header.Paint = function(_, w, h)
            surface.SetDrawColor(16, 20, 31, 250)
            surface.DrawRect(0, 0, w, h)
            surface.SetDrawColor(C.border)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
            draw.SimpleText("Permission", "DAdmin.Title", 8, h / 2, C.blue, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            local rightW = math.max(320, #groups * 74)
            local x = w - rightW
            for i, g in ipairs(groups) do
                local cellW = math.floor(rightW / math.max(#groups, 1))
                draw.SimpleText(g.label or g.id, "DAdmin.Small", x + (i - 1) * cellW + cellW / 2, h / 2, C.textDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
        end
    end

    local function rebuild()
        if not IsValid(scroll) then return end
        scroll:Clear()

        local groups, categories, matrix = DAdmin_RefinedPermissionState()
        drawHeader(groups)

        for _, cat in ipairs(categories) do
            local visible = false
            for _, perm in ipairs(cat.perms or {}) do
                local id = tostring(perm.id or perm.name or "")
                local label = tostring(perm.label or id)
                if filterText == "" or string.find(string.lower(id .. " " .. label .. " " .. tostring(perm.usage or "")), filterText, 1, true) then
                    visible = true
                    break
                end
            end

            if visible then
                local section = vgui.Create("DPanel", scroll)
                section:Dock(TOP)
                section:DockMargin(0, 2, 0, 3)
                section:SetTall(24)
                section.Paint = function(_, w, h)
                    surface.SetDrawColor(20, 24, 34, 255)
                    surface.DrawRect(0, 0, w, h)
                    draw.SimpleText(cat.name or "Permissions", "DAdmin.Title", 8, h / 2, C.blue, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                end

                for _, perm in ipairs(cat.perms or {}) do
                    local id = tostring(perm.id or perm.name or "")
                    local label = tostring(perm.label or id)
                    if filterText == "" or string.find(string.lower(id .. " " .. label .. " " .. tostring(perm.usage or "")), filterText, 1, true) then
                        local row = vgui.Create("DPanel", scroll)
                        row:Dock(TOP)
                        row:DockMargin(0, 0, 0, 3)
                        row:SetTall(36)
                        DAdmin_RefinedStyleRow(row, C)

                        row.PaintOver = function(_, w, h)
                            draw.SimpleText(id, "DAdmin.Normal", 8, 11, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                            if label ~= id then
                                draw.SimpleText(label, "DAdmin.Small", 8, 26, C.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                            end
                        end

                        local holder = vgui.Create("DPanel", row)
                        holder:Dock(RIGHT)
                        holder:SetWide(math.max(320, #groups * 74))
                        holder.Paint = nil

                        for _, g in ipairs(groups) do
                            local on = hasPerm(matrix[g.id], id)
                            local b = vgui.Create("DButton", holder)
                            b:Dock(LEFT)
                            b:DockMargin(3, 6, 0, 6)
                            b:SetWide(70)
                            b:SetText((on and "ON " or "OFF ") .. tostring(g.id):sub(1, 5))
                            UI.StyleButton(b, on and "primary" or nil)
                            b.DoClick = function()
                                setPerm(g.id, id, not on)
                                if istable(matrix[g.id]) then
                                    if not on then
                                        matrix[g.id][id] = true
                                    else
                                        matrix[g.id][id] = nil
                                        for k, v in ipairs(matrix[g.id]) do
                                            if tostring(v) == id then table.remove(matrix[g.id], k) break end
                                        end
                                    end
                                end
                                rebuild()
                            end
                        end
                    end
                end
            end
        end
    end

    refresh.DoClick = function()
        if DAdmin.Port and DAdmin.Port.Refresh then DAdmin.Port.Refresh() end
        if reqMatrix then reqMatrix() end
        timer.Simple(0.25, function() if IsValid(parent) then rebuild() end end)
    end

    search.OnChange = function(s)
        filterText = string.lower(s:GetValue() or "")
        rebuild()
    end

    if reqMatrix then reqMatrix() end
    rebuild()
end


-- Final permission panel override: original compact matrix style with instant persisted toggles.
function DAdmin.BuildPermissionsPanel(parent)
    parent:Clear()
    local UI, C = DAdmin.UI, DAdmin.UI.Colors
    local filterText = ""

    local top = vgui.Create("DPanel", parent)
    top:Dock(TOP)
    top:SetTall(30)
    top.Paint = nil

    local search = vgui.Create("DTextEntry", top)
    search:Dock(FILL)
    search:DockMargin(0, 3, 6, 3)
    search:SetPlaceholderText("Search permissions / commands...")
    UI.StyleTextEntry(search)

    local refresh = vgui.Create("DButton", top)
    refresh:Dock(RIGHT)
    refresh:SetWide(90)
    refresh:SetText("Refresh")
    UI.StyleButton(refresh, "primary")

    local scroll = vgui.Create("DScrollPanel", parent)
    scroll:Dock(FILL)

    local function getState()
        local groups, cats, matrix = {}, {}, {}
        if DAdmin.Port then
            groups = DAdmin.Port.GetPermissionGroups and (DAdmin.Port.GetPermissionGroups() or {}) or {}
            cats = DAdmin.Port.GetPermissionCategories and (DAdmin.Port.GetPermissionCategories() or {}) or {}
            matrix = DAdmin.Port.GetPermissionMatrix and (DAdmin.Port.GetPermissionMatrix() or {}) or {}
        end
        if #groups <= 0 then
            local data = DAdmin.PermissionMatrixClient or {}
            for _, r in ipairs(data.ranks or {}) do groups[#groups + 1] = { id = r.id, label = r.name or r.id } end
            local flat = {}
            for _, p in ipairs(data.permissions or {}) do flat[#flat + 1] = { id = p, label = p } end
            cats = { { name = "Permissions", perms = flat } }
            matrix = data.matrix or {}
        end
        return groups, cats, matrix
    end

    local function hasPerm(perms, id)
        if not istable(perms) then return false end
        if perms[id] == true then return true end
        for _, v in ipairs(perms) do if tostring(v) == tostring(id) then return true end end
        return false
    end

    local function setPermInMatrix(matrix, rank, id, enabled)
        matrix[rank] = matrix[rank] or {}
        local perms = matrix[rank]
        for k, v in pairs(perms) do
            if tostring(k) == tostring(id) or tostring(v) == tostring(id) then
                if enabled then
                    perms[k] = (isnumber(k) and id or true)
                else
                    perms[k] = nil
                end
                return
            end
        end
        if enabled then perms[id] = true end
    end

    local function saveMatrix(matrix, rank, perm, enabled)
        if DAdmin.Port and DAdmin.Port.UIAction then
            DAdmin.Port.UIAction("save_permissions", { matrix = matrix, rank = rank, permission = perm, enabled = enabled })
        else
            net.Start("DAdmin_PermissionMatrix_Set")
            net.WriteString(rank)
            net.WriteString(perm)
            net.WriteBool(enabled)
            net.SendToServer()
        end
    end

    local function rebuild()
        if not IsValid(scroll) then return end
        scroll:Clear()

        local groups, categories, matrix = getState()
        local header = vgui.Create("DPanel", scroll)
        header:Dock(TOP)
        header:DockMargin(0, 0, 0, 4)
        header:SetTall(30)
        header.Paint = function(_, w, h)
            surface.SetDrawColor(16, 20, 31, 250)
            surface.DrawRect(0, 0, w, h)
            surface.SetDrawColor(C.border)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
            draw.SimpleText("Permission", "DAdmin.Title", 8, h / 2, C.blue, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            local rightW = math.max(320, #groups * 74)
            local cellW = math.floor(rightW / math.max(#groups, 1))
            local x = w - rightW
            for i, g in ipairs(groups) do
                draw.SimpleText(g.label or g.id, "DAdmin.Small", x + (i - 1) * cellW + cellW / 2, h / 2, C.textDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
        end

        for _, cat in ipairs(categories) do
            local visible = false
            for _, perm in ipairs(cat.perms or {}) do
                local id = tostring(perm.id or perm.name or "")
                local label = tostring(perm.label or id)
                local usage = tostring(perm.usage or "")
                if filterText == "" or string.find(string.lower(id .. " " .. label .. " " .. usage), filterText, 1, true) then visible = true break end
            end

            if visible then
                local sec = vgui.Create("DPanel", scroll)
                sec:Dock(TOP)
                sec:DockMargin(0, 2, 0, 3)
                sec:SetTall(24)
                sec.Paint = function(_, w, h)
                    surface.SetDrawColor(20, 24, 34, 255)
                    surface.DrawRect(0, 0, w, h)
                    draw.SimpleText(cat.name or "Permissions", "DAdmin.Title", 8, h / 2, C.blue, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                end

                for _, perm in ipairs(cat.perms or {}) do
                    local id = tostring(perm.id or perm.name or "")
                    local label = tostring(perm.label or id)
                    local usage = tostring(perm.usage or "")
                    if filterText == "" or string.find(string.lower(id .. " " .. label .. " " .. usage), filterText, 1, true) then
                        local row = vgui.Create("DPanel", scroll)
                        row:Dock(TOP)
                        row:DockMargin(0, 0, 0, 3)
                        row:SetTall(36)
                        row.Paint = function(_, w, h)
                            surface.SetDrawColor(12, 15, 24, 245)
                            surface.DrawRect(0, 0, w, h)
                            surface.SetDrawColor(C.border)
                            surface.DrawOutlinedRect(0, 0, w, h, 1)
                            draw.SimpleText(id, "DAdmin.Normal", 8, 11, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                            draw.SimpleText(label ~= id and label or usage, "DAdmin.Small", 8, 26, C.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                        end

                        local holder = vgui.Create("DPanel", row)
                        holder:Dock(RIGHT)
                        holder:SetWide(math.max(320, #groups * 74))
                        holder.Paint = nil

                        for _, g in ipairs(groups) do
                            local rank = tostring(g.id or "")
                            local on = hasPerm(matrix[rank], id)
                            local b = vgui.Create("DButton", holder)
                            b:Dock(LEFT)
                            b:DockMargin(3, 6, 0, 6)
                            b:SetWide(70)
                            b:SetText((on and "ON " or "OFF ") .. rank:sub(1, 5))
                            UI.StyleButton(b, on and "primary" or nil)
                            b.DoClick = function()
                                setPermInMatrix(matrix, rank, id, not on)
                                saveMatrix(matrix, rank, id, not on)
                                rebuild()
                            end
                        end
                    end
                end
            end
        end
    end

    refresh.DoClick = function()
        if DAdmin.Port and DAdmin.Port.Refresh then DAdmin.Port.Refresh() end
        if reqMatrix then reqMatrix() end
        timer.Simple(0.25, function() if IsValid(parent) then rebuild() end end)
    end

    search.OnChange = function(s)
        filterText = string.lower(s:GetValue() or "")
        rebuild()
    end

    if reqMatrix then reqMatrix() end
    rebuild()
end
