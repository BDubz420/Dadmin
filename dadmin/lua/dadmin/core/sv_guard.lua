-- DAdmin Guard / Anti-Cheat Detection Backend
-- Phase 5 rewrite: modular, throttled, configurable, and log-aware.
if CLIENT then return end

DAdmin = DAdmin or {}
DAdmin.Guard = DAdmin.Guard or {}
DAdmin.Radar = DAdmin.Radar or {}

local CONFIG_FILE = "guard_config.json"
local ALERTS_FILE = "guard_alerts.json"
local STATE_FILE = "guard_state.json"

local guardConfig = {}
local guardAlerts = {}
local guardStats = {}
local alertCooldowns = {}
local playerState = {}
local saveAlertsQueued = false
local saveConfigQueued = false
local saveStateQueued = false

local MODULES = {
    speedhack = {
        name = "Speedhack Detection",
        severity = "high",
        interval = 0.35,
        cooldown = 7,
        threshold = 1450,
        description = "Checks horizontal player speed against max server movement."
    },
    spinbot = {
        name = "Anti-aim / Spinbot",
        severity = "high",
        interval = 0.25,
        cooldown = 6,
        threshold = 1440,
        description = "Detects repeated impossible yaw rotation rates."
    },
    bhop = {
        name = "Bhop Automation",
        severity = "medium",
        interval = 0.1,
        cooldown = 10,
        threshold = 10,
        description = "Tracks repeated perfectly timed jump chains."
    },
    noclip_abuse = {
        name = "No-clip Abuse",
        severity = "medium",
        interval = 0,
        cooldown = 8,
        threshold = 1,
        description = "Blocks unauthorized noclip attempts."
    },
    propspam = {
        name = "Prop Spam",
        severity = "medium",
        interval = 0,
        cooldown = 8,
        threshold = 16,
        description = "Detects excessive prop spawning inside a short window."
    },
    toolspam = {
        name = "Tool Spam",
        severity = "medium",
        interval = 0,
        cooldown = 8,
        threshold = 24,
        description = "Detects excessive toolgun usage."
    },
    chatspam = {
        name = "Chat Spam",
        severity = "low",
        interval = 0,
        cooldown = 8,
        threshold = 8,
        description = "Detects repeated chat flooding."
    },
    crash = {
        name = "Crash / Stress Attempt",
        severity = "high",
        interval = 0,
        cooldown = 12,
        threshold = 1,
        description = "Flags behavior commonly used to overload the server."
    },
    lua_exploit = {
        name = "Lua Exploit Signals",
        severity = "high",
        interval = 0,
        cooldown = 20,
        threshold = 1,
        description = "Records suspicious client/network exploit signals when seen."
    },
    aimbot = {
        name = "Aimbot Heuristics",
        severity = "medium",
        interval = 0.25,
        cooldown = 12,
        threshold = 118,
        description = "Low-noise heuristic for impossible snap angle changes while attacking."
    },
    esp = {
        name = "ESP / Wallhack Heuristics",
        severity = "low",
        interval = 1.0,
        cooldown = 20,
        threshold = 1,
        description = "Placeholder signal bucket for visibility/knowledge events."
    }
}

local DEFAULT_CONFIG = {
    enabled = true,
    autoban = false,
    autoban_threshold = 95,
    alert_cooldown = 6,
    max_alerts = 500,
    notify_staff = true,
    speedhack_threshold = 1450,
    spinbot_threshold = 1440,
    bhop_threshold = 10,
    noclip_abuse_threshold = 1,
    propspam_threshold = 16,
    propspam_window = 3,
    propspam_restrict_seconds = 12,
    propspam_freeze_existing = true,
    propspam_remove_new = true,
    propspam_total_prop_limit = 45,
    propspam_cleanup_on_limit = true,
    toolspam_threshold = 24,
    toolspam_window = 2,
    chatspam_threshold = 8,
    chatspam_window = 5,
    speedhack = true,
    spinbot = true,
    bhop = true,
    noclip_abuse = true,
    propspam = true,
    toolspam = true,
    chatspam = true,
    crash = true,
    lua_exploit = true,
    aimbot = true,
    esp = false
}

local staticGuard = DAdmin.StaticConfig and DAdmin.StaticConfig.Guard or {}
for k, v in pairs(staticGuard.modules or {}) do
    if DEFAULT_CONFIG[k] ~= nil then DEFAULT_CONFIG[k] = v end
end
for _, k in ipairs({"enabled", "notify_staff", "autoban", "autoban_threshold", "alert_cooldown", "max_alerts"}) do
    if staticGuard[k] ~= nil then DEFAULT_CONFIG[k] = staticGuard[k] end
end


local function storageLoad(path, fallback)
    if DAdmin.Storage and DAdmin.Storage.Load then
        return DAdmin.Storage.Load(path, fallback)
    end
    return fallback
end

local function storageSave(path, data)
    if DAdmin.Storage and DAdmin.Storage.Save then
        DAdmin.Storage.Save(path, data)
    end
end

local function queueSave(which)
    if which == "config" then
        if saveConfigQueued then return end
        saveConfigQueued = true
        timer.Simple(0.5, function()
            saveConfigQueued = false
            storageSave(CONFIG_FILE, guardConfig)
        end)
    elseif which == "state" then
        if saveStateQueued then return end
        saveStateQueued = true
        timer.Simple(1.0, function()
            saveStateQueued = false
            storageSave(STATE_FILE, guardStats)
        end)
    else
        if saveAlertsQueued then return end
        saveAlertsQueued = true
        timer.Simple(1.5, function()
            saveAlertsQueued = false
            storageSave(ALERTS_FILE, guardAlerts)
        end)
    end
end

local function loadAll()
    guardConfig = storageLoad(CONFIG_FILE, {}) or {}
    for k, v in pairs(DEFAULT_CONFIG) do
        if guardConfig[k] == nil then guardConfig[k] = v end
    end
    guardAlerts = storageLoad(ALERTS_FILE, {}) or {}
    guardStats = storageLoad(STATE_FILE, {}) or {}
    guardStats.modules = guardStats.modules or {}
end

loadAll()

local function getModuleThreshold(key)
    local module = MODULES[key] or {}
    return tonumber(guardConfig[tostring(key) .. "_threshold"] or module.threshold or 0) or 0
end

local function getModuleWindow(key)
    if key == "propspam" then
        return math.Clamp(tonumber(guardConfig.propspam_window or 3) or 3, 1, 30)
    end
    if key == "toolspam" then
        return math.Clamp(tonumber(guardConfig.toolspam_window or 2) or 2, 1, 30)
    end
    if key == "chatspam" then
        return math.Clamp(tonumber(guardConfig.chatspam_window or 5) or 5, 1, 60)
    end
    return 0
end

local function canIgnore(ply)
    if not IsValid(ply) then return true end
    if ply:IsBot() then return true end
    if not ply:Alive() then return true end
    if ply:GetMoveType() == MOVETYPE_NOCLIP then return true end
    if ply:InVehicle() then return true end
    if ply:GetNWBool("InSit", false) then return true end
    return false
end

local function sid(ply)
    return IsValid(ply) and (ply:SteamID() or tostring(ply:UserID())) or "unknown"
end

local function addMegaLog(category, action, actor, target, details, data)
    if DAdmin.MegaLogs and DAdmin.MegaLogs.Add then
        DAdmin.MegaLogs.Add(category or "guard", action or "guard", actor or "System", target or "System", details or "", data or {})
    elseif DAdmin.Log then
        DAdmin.Log(action or "guard", actor or "System", target or "System", details or "")
    end
end

local function notifyStaff(msg)
    if guardConfig.notify_staff == false then return end
    for _, admin in ipairs(player.GetAll()) do
        if IsValid(admin) and DAdmin.HasPermission and (DAdmin.HasPermission(admin, "guard") or DAdmin.HasPermission(admin, "guard.admin")) then
            admin:ChatPrint("[DAdmin Guard] " .. msg)
        end
    end
end

local function moduleEnabled(key)
    return guardConfig.enabled ~= false and guardConfig[key] ~= false
end

local function bumpStats(key)
    guardStats.total = (tonumber(guardStats.total or 0) or 0) + 1
    guardStats.today = guardStats.today or os.date("%Y-%m-%d")
    if guardStats.today ~= os.date("%Y-%m-%d") then
        guardStats.today = os.date("%Y-%m-%d")
        guardStats.todayCount = 0
    end
    guardStats.todayCount = (tonumber(guardStats.todayCount or 0) or 0) + 1
    guardStats.modules = guardStats.modules or {}
    guardStats.modules[key] = (tonumber(guardStats.modules[key] or 0) or 0) + 1
    queueSave("state")
end

local function getTrackedProps(ply)
    local id = sid(ply)
    playerState[id] = playerState[id] or {}
    playerState[id].spawnedProps = playerState[id].spawnedProps or {}
    return playerState[id], playerState[id].spawnedProps
end

local function cleanTrackedProps(list)
    local count = 0
    for i = #list, 1, -1 do
        if not IsValid(list[i]) then
            table.remove(list, i)
        else
            count = count + 1
        end
    end
    return count
end

local function freezeTrackedProps(ply)
    local _, props = getTrackedProps(ply)
    for _, ent in ipairs(props) do
        if IsValid(ent) then
            local phys = ent:GetPhysicsObject()
            if IsValid(phys) then
                phys:EnableMotion(false)
                phys:Sleep()
            end
        end
    end
end

local function startPropRestriction(ply, reason, confidence, escalate)
    if not IsValid(ply) then return end
    local st, props = getTrackedProps(ply)
    st.propRestrictedUntil = CurTime() + math.Clamp(tonumber(guardConfig.propspam_restrict_seconds or 12) or 12, 1, 120)

    if guardConfig.propspam_freeze_existing ~= false then
        freezeTrackedProps(ply)
    end

    DAdmin.Guard.AddAlert({
        type = escalate and "crash" or "propspam",
        player = ply,
        playerName = ply:Nick(),
        steamid = sid(ply),
        confidence = confidence,
        details = reason
    })

    if guardConfig.propspam_cleanup_on_limit ~= false and cleanTrackedProps(props) >= (tonumber(guardConfig.propspam_total_prop_limit or 45) or 45) then
        for _, ent in ipairs(props) do
            if IsValid(ent) then ent:Remove() end
        end
        st.spawnedProps = {}
        notifyStaff(ply:Nick() .. "'s props were cleaned up by Guard.")
    end
end

function DAdmin.Guard.GetModules()
    local out = {}
    for key, info in pairs(MODULES) do
        out[#out + 1] = {
            key = key,
            name = info.name,
            severity = info.severity,
            interval = info.interval,
            threshold = getModuleThreshold(key),
            window = getModuleWindow(key),
            description = info.description,
            enabled = moduleEnabled(key),
            count = guardStats.modules and guardStats.modules[key] or 0
        }
    end
    table.SortByMember(out, "name", true)
    return out
end

function DAdmin.Guard.GetConfig()
    return table.Copy(guardConfig or {})
end

function DAdmin.Guard.SetConfig(cfg)
    if not istable(cfg) then return end
    for k in pairs(DEFAULT_CONFIG) do
        if cfg[k] ~= nil then
            if isnumber(DEFAULT_CONFIG[k]) then
                guardConfig[k] = tonumber(cfg[k]) or DEFAULT_CONFIG[k]
            else
                guardConfig[k] = tobool(cfg[k])
            end
        end
    end
    guardConfig.autoban_threshold = math.Clamp(tonumber(guardConfig.autoban_threshold or 95) or 95, 50, 100)
    guardConfig.alert_cooldown = math.Clamp(tonumber(guardConfig.alert_cooldown or 6) or 6, 1, 120)
    guardConfig.max_alerts = math.Clamp(tonumber(guardConfig.max_alerts or 500) or 500, 50, 5000)
    guardConfig.propspam_threshold = math.Clamp(tonumber(guardConfig.propspam_threshold or 16) or 16, 4, 200)
    guardConfig.propspam_window = math.Clamp(tonumber(guardConfig.propspam_window or 3) or 3, 1, 30)
    guardConfig.propspam_restrict_seconds = math.Clamp(tonumber(guardConfig.propspam_restrict_seconds or 12) or 12, 1, 120)
    guardConfig.propspam_total_prop_limit = math.Clamp(tonumber(guardConfig.propspam_total_prop_limit or 45) or 45, 10, 500)
    guardConfig.toolspam_threshold = math.Clamp(tonumber(guardConfig.toolspam_threshold or 24) or 24, 4, 200)
    guardConfig.toolspam_window = math.Clamp(tonumber(guardConfig.toolspam_window or 2) or 2, 1, 30)
    guardConfig.chatspam_threshold = math.Clamp(tonumber(guardConfig.chatspam_threshold or 8) or 8, 2, 50)
    guardConfig.chatspam_window = math.Clamp(tonumber(guardConfig.chatspam_window or 5) or 5, 1, 60)
    queueSave("config")
end

function DAdmin.Guard.GetStats()
    return table.Copy(guardStats or {})
end

function DAdmin.Guard.AddAlert(data)
    if not istable(data) then return end
    local key = tostring(data.type or "unknown")
    if not moduleEnabled(key) then return end

    local module = MODULES[key] or {}
    local steamid = tostring(data.steamid or "")
    local confidence = math.Clamp(tonumber(data.confidence or 0) or 0, 0, 100)
    local cooldown = tonumber(data.cooldown or module.cooldown or guardConfig.alert_cooldown or 6) or 6
    local cooldownKey = steamid .. ":" .. key

    if alertCooldowns[cooldownKey] and alertCooldowns[cooldownKey] > CurTime() then return end
    alertCooldowns[cooldownKey] = CurTime() + cooldown

    local alert = {
        id = "guard_" .. tostring(os.time()) .. "_" .. tostring(math.random(100000, 999999)),
        type = key,
        title = tostring(data.title or module.name or key),
        severity = tostring(data.severity or module.severity or "medium"),
        playerName = tostring(data.playerName or "Unknown"),
        steamid = steamid,
        confidence = confidence,
        details = tostring(data.details or ""),
        status = "flagged",
        time = os.date("%H:%M:%S"),
        date = os.date("%Y-%m-%d"),
        timestamp = os.time()
    }

    table.insert(guardAlerts, 1, alert)
    local maxAlerts = tonumber(guardConfig.max_alerts or 500) or 500
    while #guardAlerts > maxAlerts do table.remove(guardAlerts) end

    bumpStats(key)
    queueSave("alerts")

    addMegaLog("guard", key, "DAdmin Guard", IsValid(data.player) and data.player or alert.steamid, alert.details, alert)
    notifyStaff(alert.playerName .. " flagged for " .. alert.title .. " (" .. tostring(alert.confidence) .. "%)")

    if guardConfig.autoban and alert.confidence >= (tonumber(guardConfig.autoban_threshold or 95) or 95) and alert.severity == "high" then
        local target = data.player
        if not IsValid(target) and DAdmin.Players and DAdmin.Players.FindBySteamID then
            target = DAdmin.Players.FindBySteamID(alert.steamid)
        end
        if IsValid(target) and DAdmin.Punishments and DAdmin.Punishments.Ban then
            DAdmin.Punishments.Ban(nil, target, 0, "DAdmin Guard: " .. alert.title .. " (" .. tostring(alert.confidence) .. "%)")
            alert.status = "banned"
            addMegaLog("guard", "autoban", "DAdmin Guard", target, "Auto-ban for " .. alert.title, alert)
            queueSave("alerts")
        end
    end

    if DAdmin.BroadcastLogUpdate then DAdmin.BroadcastLogUpdate() end
    return alert
end

function DAdmin.Guard.DismissAlert(alertID)
    alertID = tostring(alertID or "")
    for i, alert in ipairs(guardAlerts or {}) do
        if tostring(alert.id) == alertID then
            table.remove(guardAlerts, i)
            queueSave("alerts")
            return true
        end
    end
    return false
end

function DAdmin.Guard.ClearAlerts()
    guardAlerts = {}
    queueSave("alerts")
end

function DAdmin.Guard.GetAlerts(limit)
    limit = math.Clamp(tonumber(limit or 50) or 50, 1, 500)
    local out = {}
    for i = 1, math.min(#guardAlerts, limit) do
        out[#out + 1] = table.Copy(guardAlerts[i])
    end
    return out
end

function DAdmin.Guard.GetState()
    return {
        config = DAdmin.Guard.GetConfig(),
        modules = DAdmin.Guard.GetModules(),
        alerts = DAdmin.Guard.GetAlerts(100),
        stats = DAdmin.Guard.GetStats()
    }
end

DAdmin.Radar.GetRecentAlerts = function(limit)
    return DAdmin.Guard.GetAlerts(limit or 10)
end

-- Movement checks
timer.Create("DAdmin_Guard_MovementCheck", 0.25, 0, function()
    if guardConfig.enabled == false then return end
    local now = CurTime()

    for _, ply in ipairs(player.GetAll()) do
        local id = sid(ply)
        local st = playerState[id] or {}
        local pos = ply:GetPos()
        local ang = ply:EyeAngles()
        local vel = ply:GetVelocity()

        if canIgnore(ply) then
            st.pos = pos
            st.posTime = now
            st.ang = Angle(ang.pitch, ang.yaw, ang.roll)
            st.angTime = now
            st.snapHits = 0
            st.bhopChain = 0
            playerState[id] = st
        else

            if moduleEnabled("speedhack") and st.pos and st.posTime then
                local dt = now - st.posTime
                if dt > 0.05 and dt <= 0.6 and ply:OnGround() then
                    local delta = pos - st.pos
                    delta.z = 0
                    local speed = delta:Length() / dt
                    local allowed = math.max(ply:GetRunSpeed() or 400, ply:GetWalkSpeed() or 200) + 450
                    if speed > math.max(getModuleThreshold("speedhack"), allowed) then
                        DAdmin.Guard.AddAlert({
                            type = "speedhack",
                            player = ply,
                            playerName = ply:Nick(),
                            steamid = id,
                            confidence = math.Clamp(math.floor((speed / math.max(allowed, 1)) * 35), 55, 99),
                            details = string.format("Measured %.0f u/s, allowed approx %.0f u/s", speed, allowed)
                        })
                    end
                end
            end

            if moduleEnabled("spinbot") and st.ang and st.angTime then
                local dt = now - st.angTime
                if dt > 0.05 and dt <= 0.5 then
                    local yawRate = math.abs(math.AngleDifference(ang.yaw, st.ang.yaw)) / dt
                    local pitchBad = math.abs(ang.pitch) > 89.5
                    if yawRate > getModuleThreshold("spinbot") or pitchBad then
                        DAdmin.Guard.AddAlert({
                            type = "spinbot",
                            player = ply,
                            playerName = ply:Nick(),
                            steamid = id,
                            confidence = pitchBad and 96 or math.Clamp(math.floor((yawRate / 1440) * 55), 55, 98),
                            details = pitchBad and ("Invalid pitch: " .. tostring(math.Round(ang.pitch, 2))) or string.format("Yaw rate %.0f deg/s", yawRate)
                        })
                    end
                end
            end

            if moduleEnabled("aimbot") and st.ang and ply:KeyDown(IN_ATTACK) then
                    local dt = now - (st.angTime or now)
                if dt > 0.05 and dt <= 0.35 then
                    local yawDelta = math.abs(math.AngleDifference(ang.yaw, st.ang.yaw))
                    local pitchDelta = math.abs(math.AngleDifference(ang.pitch, st.ang.pitch))
                    local snap = yawDelta + pitchDelta
                    if snap > getModuleThreshold("aimbot") and vel:Length2D() < 80 then
                        st.snapHits = (st.snapHits or 0) + 1
                        if st.snapHits >= 3 then
                            DAdmin.Guard.AddAlert({
                                type = "aimbot",
                                player = ply,
                                playerName = ply:Nick(),
                                steamid = id,
                                confidence = math.Clamp(60 + st.snapHits * 8, 60, 92),
                                details = string.format("%d repeated attack snaps, last %.0f degrees", st.snapHits, snap)
                            })
                            st.snapHits = 0
                        end
                    else
                        st.snapHits = math.max((st.snapHits or 0) - 1, 0)
                    end
                end
            end

            if moduleEnabled("bhop") then
                if ply:KeyDown(IN_JUMP) and ply:OnGround() then
                    if not st.jumpHeld then
                        local gap = now - (st.lastGroundJump or 0)
                        st.lastGroundJump = now
                        if gap > 0.05 and gap < 0.32 and vel:Length2D() > 240 then
                            st.bhopChain = (st.bhopChain or 0) + 1
                        else
                            st.bhopChain = math.max((st.bhopChain or 0) - 1, 0)
                        end
                        if st.bhopChain >= getModuleThreshold("bhop") then
                            DAdmin.Guard.AddAlert({
                                type = "bhop",
                                player = ply,
                                playerName = ply:Nick(),
                                steamid = id,
                                confidence = math.Clamp(55 + st.bhopChain * 3, 55, 90),
                                details = tostring(st.bhopChain) .. " near-perfect ground jumps"
                            })
                            st.bhopChain = 0
                        end
                    end
                    st.jumpHeld = true
                else
                    st.jumpHeld = false
                end
            end

            st.pos = pos
            st.posTime = now
            st.ang = Angle(ang.pitch, ang.yaw, ang.roll)
            st.angTime = now
            playerState[id] = st
        end
    end
end)

local function bucketHit(ply, key, window, limit, details)
    if not IsValid(ply) or not moduleEnabled(key) then return end
    local id = sid(ply)
    playerState[id] = playerState[id] or {}
    local st = playerState[id]
    local bkey = key .. "_bucket"
    local bucket = st[bkey] or { count = 0, reset = CurTime() + window }
    if CurTime() > bucket.reset then
        bucket.count = 0
        bucket.reset = CurTime() + window
    end
    bucket.count = bucket.count + 1
    st[bkey] = bucket

    if bucket.count > limit then
        if key == "propspam" then
            startPropRestriction(
                ply,
                details and details(bucket.count, window) or (tostring(bucket.count) .. " props spawned in " .. tostring(window) .. "s"),
                math.Clamp(math.floor((bucket.count / limit) * 65), 60, 99),
                false
            )
        else
            DAdmin.Guard.AddAlert({
                type = key,
                player = ply,
                playerName = ply:Nick(),
                steamid = id,
                confidence = math.Clamp(math.floor((bucket.count / limit) * 65), 55, 99),
                details = details and details(bucket.count, window) or (tostring(bucket.count) .. " events in " .. tostring(window) .. "s")
            })
        end
        bucket.count = 0
        bucket.reset = CurTime() + window
    end
end

hook.Add("PlayerNoClip", "DAdmin_Guard_NoclipAbuse", function(ply, desiredState)
    if not moduleEnabled("noclip_abuse") or not desiredState then return end
    if DAdmin.HasPermission and DAdmin.HasPermission(ply, "noclip") then return end
    DAdmin.Guard.AddAlert({
        type = "noclip_abuse",
        player = ply,
        playerName = ply:Nick(),
        steamid = sid(ply),
        confidence = 92,
        details = "Attempted noclip without permission"
    })
    return false
end)

hook.Add("PlayerSpawnProp", "DAdmin_Guard_BlockRestrictedProps", function(ply)
    if not moduleEnabled("propspam") then return end
    local st = playerState[sid(ply)]
    if st and st.propRestrictedUntil and st.propRestrictedUntil > CurTime() and guardConfig.propspam_remove_new ~= false then
        if DAdmin.Msg then
            DAdmin.Msg(ply, "Guard is temporarily blocking your prop spawns due to prop spam.")
        end
        return false
    end
end)

hook.Add("PlayerSpawnedProp", "DAdmin_Guard_PropSpam", function(ply, _, ent)
    local st, props = getTrackedProps(ply)
    if IsValid(ent) then
        props[#props + 1] = ent
    end
    cleanTrackedProps(props)

    bucketHit(ply, "propspam", getModuleWindow("propspam"), getModuleThreshold("propspam"), function(count, window)
        return tostring(count) .. " props spawned in " .. tostring(window) .. " seconds"
    end)

    local propCount = cleanTrackedProps(props)
    if propCount >= (tonumber(guardConfig.propspam_total_prop_limit or 45) or 45) then
        startPropRestriction(
            ply,
            tostring(propCount) .. " active props owned after rapid spawning",
            math.Clamp(70 + math.floor(propCount / 4), 70, 99),
            true
        )
    end
end)

hook.Add("CanTool", "DAdmin_Guard_ToolSpam", function(ply)
    bucketHit(ply, "toolspam", getModuleWindow("toolspam"), getModuleThreshold("toolspam"), function(count, window)
        return tostring(count) .. " toolgun actions in " .. tostring(window) .. " seconds"
    end)
end)

hook.Add("PlayerSay", "DAdmin_Guard_ChatSpam", function(ply, text)
    bucketHit(ply, "chatspam", getModuleWindow("chatspam"), getModuleThreshold("chatspam"), function(count, window)
        return tostring(count) .. " chat messages in " .. tostring(window) .. " seconds"
    end)
end)

hook.Add("PlayerDisconnected", "DAdmin_Guard_Cleanup", function(ply)
    if not ply then return end
    local id = sid(ply)
    playerState[id] = nil
    for k in pairs(alertCooldowns) do
        if string.StartWith(k, id .. ":") then alertCooldowns[k] = nil end
    end
end)

concommand.Add("dadmin_guard_test", function(ply, _, args)
    if IsValid(ply) and DAdmin.HasPermission and not DAdmin.HasPermission(ply, "guard.admin") then return end
    local target = IsValid(ply) and ply or player.GetAll()[1]
    DAdmin.Guard.AddAlert({
        type = args and args[1] or "lua_exploit",
        player = target,
        playerName = IsValid(target) and target:Nick() or "Console",
        steamid = IsValid(target) and target:SteamID() or "CONSOLE",
        confidence = 88,
        details = "Manual test alert"
    })
end)
