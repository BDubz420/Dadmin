DAdmin = DAdmin or {}

util.AddNetworkString("DAdmin_ChatNotify")
util.AddNetworkString("DAdmin_ReportNotify")

local function getConfig()
    return DAdmin.Config or {}
end

local function getPrefixColor()
    local hex = getConfig().prefix_color or "4A90D9"
    local r = tonumber("0x" .. string.sub(hex, 1, 2)) or 74
    local g = tonumber("0x" .. string.sub(hex, 3, 4)) or 144
    local b = tonumber("0x" .. string.sub(hex, 5, 6)) or 217
    return Color(r, g, b)
end

local function normalizedChatText(text)
    text = string.lower(tostring(text or ""))
    text = string.gsub(text, "[%p%c]", " ")
    text = string.Trim(string.gsub(text, "%s+", " "))
    return text
end

local function blockedPhrases()
    local raw = tostring(getConfig().chat_blocked_phrases or "")
    local out = {}
    for line in string.gmatch(raw, "[^\r\n]+") do
        line = normalizedChatText(line)
        if line ~= "" then out[#out + 1] = line end
    end
    return out
end

local function findBlockedPhrase(text)
    if getConfig().chat_protection_enabled ~= true then return nil end
    local haystack = normalizedChatText(text)
    if haystack == "" then return nil end

    for _, phrase in ipairs(blockedPhrases()) do
        if string.find(haystack, phrase, 1, true) then
            return phrase
        end
    end
end

function DAdmin.Msg(ply, text)
    if not IsValid(ply) then
        print("[DAdmin] " .. tostring(text))
        return
    end
    net.Start("DAdmin_ChatNotify")
    net.WriteString(tostring(text))
    net.WriteUInt(0, 2)
    net.Send(ply)
end

function DAdmin.MsgAll(text)
    net.Start("DAdmin_ChatNotify")
    net.WriteString(tostring(text))
    net.WriteUInt(0, 2)
    net.Broadcast()
end

function DAdmin.ChatLogAction(action, admin, target, details)
    local cfg = getConfig()
    if not cfg.chat_log_commands and not cfg.chat_log_permissions then return end

    local isPermAction = (action == "permissions" or action == "rank" or action == "setrank" or action == "toggle_rank_setting")
    if isPermAction and not cfg.chat_log_permissions then return end
    if not isPermAction and not cfg.chat_log_commands then return end

    local adminName = IsEntity(admin) and IsValid(admin) and admin:Nick() or tostring(admin or "System")
    local targetName = IsEntity(target) and IsValid(target) and target:Nick() or tostring(target or "-")
    local msg = adminName .. " " .. tostring(action) .. " " .. targetName
    if details and details ~= "" then msg = msg .. " (" .. tostring(details) .. ")" end

    for _, ply in ipairs(player.GetAll()) do
        if DAdmin.Security and DAdmin.Security.CanUseMenu and DAdmin.Security.CanUseMenu(ply) then
            net.Start("DAdmin_ChatNotify")
            net.WriteString(msg)
            net.WriteUInt(1, 2)
            net.Send(ply)
        end
    end
end

function DAdmin.NotifyReportToAdmins(report)
    for _, ply in ipairs(player.GetAll()) do
        local cfg = getConfig()
        if cfg.notify_report ~= false and (ply:IsAdmin() or (DAdmin.HasPermission and DAdmin.HasPermission(ply, "reports"))) then
            net.Start("DAdmin_ReportNotify")
            net.WriteTable(report or {})
            net.Send(ply)
        end
    end
end

hook.Add("PlayerSay", "DAdmin.ChatCommands", function(ply, text)
    if not isstring(text) then return end
    text = string.Trim(text)
    if text == "!menu" or text == "!dadmin" or text == "/dadmin" then
        if IsValid(ply) and DAdmin.Security and DAdmin.Security.CanUseMenu and DAdmin.Security.CanUseMenu(ply) then
            net.Start("dadmin_open_menu")
            net.WriteString("")
            net.Send(ply)
        end
        return ""
    end
    if string.sub(text, 1, 1) ~= "!" then return end

    local args = string.Explode(" ", string.sub(text, 2))
    local cmdName = table.remove(args, 1)
    if not cmdName then return "" end

    if DAdmin.RunCommand then
        DAdmin.RunCommand(ply, cmdName, args)
    else
        DAdmin.Msg(ply, "RunCommand is unavailable.")
    end
    return ""
end)

hook.Add("PlayerSay", "DAdmin.ChatProtection", function(ply, text, teamChat)
    if not IsValid(ply) or not isstring(text) then return end
    if string.sub(text, 1, 1) == "!" then return end

    local matched = findBlockedPhrase(text)
    if not matched then return end

    if DAdmin.MegaLogs then
        DAdmin.MegaLogs.Add("chat", "blocked_message", ply, teamChat and "team" or "global", text, { phrase = matched })
    elseif DAdmin.Log then
        DAdmin.Log("blocked_chat", ply, matched, text)
    end

    if DAdmin.Msg then
        DAdmin.Msg(ply, "That message was blocked by chat protection.")
    end

    return getConfig().chat_protection_block ~= false and "" or nil
end)

hook.Add("PlayerInitialSpawn", "DAdmin.MOTDOnJoin", function(ply)
    timer.Simple(3, function()
        if not IsValid(ply) then return end
        local cfg = getConfig()
        if cfg.motd_on_join and cfg.motd and cfg.motd ~= "" then
            net.Start("DAdmin_ChatNotify")
            net.WriteString(cfg.motd)
            net.WriteUInt(2, 2)
            net.Send(ply)
        end
        if DAdmin.Security and DAdmin.Security.CanUseMenu and DAdmin.Security.CanUseMenu(ply) then
            net.Start("DAdmin_ChatNotify")
            net.WriteString("DAdmin v2.2.0 loaded. Type !dadmin to open the admin menu.")
            net.WriteUInt(1, 2)
            net.Send(ply)
        end
    end)
end)
