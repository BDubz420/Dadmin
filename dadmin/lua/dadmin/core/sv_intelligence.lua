-- DAdmin Phase 8 - Intelligence + Risk Engine
-- Adds weighted anti-cheat scoring, decay windows, smarter escalation, and staff action analytics.
if CLIENT then return end

DAdmin = DAdmin or {}
DAdmin.Intel = DAdmin.Intel or {}

local RISK_FILE = "intel_risk_profiles.json"
local STAFF_FILE = "intel_staff_activity.json"
local CONFIG_FILE = "intel_config.json"

local riskProfiles = {}
local staffActivity = {}
local intelConfig = {}

local DEFAULT_CONFIG = {
    decay_seconds = 1800,
    auto_review_score = 45,
    auto_case_score = 65,
    auto_punish_score = 90,
    auto_punish_enabled = false,
    staff_abuse_window = 600,
    staff_abuse_threshold = 12,
    weights = {
        speedhack = 18,
        spinbot = 26,
        aimbot = 30,
        noclip_abuse = 22,
        propspam = 10,
        lua_exploit = 35,
        injection = 40,
        esp = 15,
        bhop = 8,
        crash = 35,
        warn = 6,
        kick = 10,
        ban = 18,
        mute = 4,
        gag = 4
    }
}

local function now() return os.time() end

local function copyDefaults(src)
    local out = {}
    for k, v in pairs(src) do
        out[k] = istable(v) and table.Copy(v) or v
    end
    return out
end

local function mergeDefaults(dst, src)
    dst = istable(dst) and dst or {}
    for k, v in pairs(src) do
        if dst[k] == nil then
            dst[k] = istable(v) and table.Copy(v) or v
        elseif istable(v) and istable(dst[k]) then
            mergeDefaults(dst[k], v)
        end
    end
    return dst
end

local function load()
    intelConfig = mergeDefaults(DAdmin.Storage and DAdmin.Storage.Load and DAdmin.Storage.Load(CONFIG_FILE, {}) or {}, DEFAULT_CONFIG)
    riskProfiles = DAdmin.Storage and DAdmin.Storage.Load and DAdmin.Storage.Load(RISK_FILE, {}) or {}
    staffActivity = DAdmin.Storage and DAdmin.Storage.Load and DAdmin.Storage.Load(STAFF_FILE, {}) or {}
end

local function saveConfig()
    if DAdmin.Storage and DAdmin.Storage.Save then DAdmin.Storage.Save(CONFIG_FILE, intelConfig) end
end

local function saveRisk()
    if DAdmin.Storage and DAdmin.Storage.Save then DAdmin.Storage.Save(RISK_FILE, riskProfiles) end
end

local function saveStaff()
    if DAdmin.Storage and DAdmin.Storage.Save then DAdmin.Storage.Save(STAFF_FILE, staffActivity) end
end

local function playerInfo(plyOrSteamID, fallbackName)
    if IsValid(plyOrSteamID) then
        return plyOrSteamID:SteamID(), plyOrSteamID:Nick()
    end
    return tostring(plyOrSteamID or ""), tostring(fallbackName or plyOrSteamID or "Unknown")
end

local function getProfile(steamid, name)
    steamid = tostring(steamid or "")
    if steamid == "" then return nil end
    riskProfiles[steamid] = riskProfiles[steamid] or {
        steamid = steamid,
        name = name or steamid,
        score = 0,
        level = "clean",
        firstSeen = now(),
        lastSeen = now(),
        offenses = {},
        windows = {},
        actions = {},
        review = false,
        caseID = nil
    }
    local p = riskProfiles[steamid]
    p.name = name or p.name or steamid
    p.offenses = istable(p.offenses) and p.offenses or {}
    p.windows = istable(p.windows) and p.windows or {}
    p.actions = istable(p.actions) and p.actions or {}
    return p
end

local function computeLevel(score)
    score = tonumber(score) or 0
    if score >= 90 then return "critical" end
    if score >= 65 then return "high" end
    if score >= 45 then return "review" end
    if score >= 20 then return "watch" end
    return "clean"
end

local function pruneWindow(list, cutoff)
    if not istable(list) then return {} end
    local out = {}
    for _, e in ipairs(list) do
        if tonumber(e.timestamp or 0) >= cutoff then out[#out + 1] = e end
    end
    return out
end

function DAdmin.Intel.Recalculate(steamid)
    local p = getProfile(steamid)
    if not p then return nil end
    local cutoff = now() - (tonumber(intelConfig.decay_seconds) or 1800)
    local score = 0
    local counts = {}

    for typ, list in pairs(p.windows or {}) do
        p.windows[typ] = pruneWindow(list, cutoff)
        counts[typ] = #p.windows[typ]
        local weight = tonumber((intelConfig.weights or {})[typ]) or 5
        for _, e in ipairs(p.windows[typ]) do
            local confidence = math.Clamp(tonumber(e.confidence or 50) or 50, 0, 100) / 100
            score = score + (weight * confidence)
        end
    end

    p.score = math.Clamp(math.floor(score), 0, 100)
    p.level = computeLevel(p.score)
    p.counts = counts
    p.lastSeen = now()
    p.review = p.score >= (tonumber(intelConfig.auto_review_score) or 45)

    if p.score >= (tonumber(intelConfig.auto_case_score) or 65) and DAdmin.Cases and DAdmin.Cases.FindOpenForPlayer and not p.caseID then
        local existing = DAdmin.Cases.FindOpenForPlayer(steamid)
        if existing then
            p.caseID = existing.id
            DAdmin.Cases.AddTimeline(existing.id, "intel_linked", "System", "Risk score " .. tostring(p.score))
        elseif DAdmin.Cases.Create then
            local c = DAdmin.Cases.Create(steamid, nil, "SYSTEM", "Intelligence review: risk score " .. tostring(p.score))
            p.caseID = c and c.id or nil
        end
    end

    return p
end

function DAdmin.Intel.RecordOffense(plyOrSteamID, offenseType, confidence, details, source)
    local steamid, name = playerInfo(plyOrSteamID, istable(details) and details.playerName or nil)
    if steamid == "" then return nil end

    offenseType = string.lower(tostring(offenseType or "unknown"))
    local p = getProfile(steamid, name)
    local entry = {
        id = "offense_" .. tostring(now()) .. "_" .. tostring(math.random(1000, 9999)),
        type = offenseType,
        confidence = math.Clamp(tonumber(confidence or 50) or 50, 0, 100),
        details = istable(details) and (details.details or details.reason or util.TableToJSON(details) or "") or tostring(details or ""),
        source = tostring(source or "manual"),
        timestamp = now(),
        time = os.date("%H:%M:%S")
    }

    p.offenses[#p.offenses + 1] = entry
    if #p.offenses > 100 then table.remove(p.offenses, 1) end
    p.windows[offenseType] = p.windows[offenseType] or {}
    table.insert(p.windows[offenseType], entry)

    DAdmin.Intel.Recalculate(steamid)

    if DAdmin.History and DAdmin.History.Add then
        DAdmin.History.Add(steamid, "intel", {
            type = offenseType,
            confidence = entry.confidence,
            details = entry.details,
            score = p.score,
            level = p.level
        })
    end

    if DAdmin.Log then
        DAdmin.Log("intel_flag", "System", steamid, offenseType .. " risk=" .. tostring(p.score))
    end

    if intelConfig.auto_punish_enabled and p.score >= (tonumber(intelConfig.auto_punish_score) or 90) then
        local target = player.GetBySteamID(steamid)
        if IsValid(target) and DAdmin.Punishments and DAdmin.Punishments.Kick then
            DAdmin.Punishments.Kick(nil, target, "DAdmin Guard: critical risk score " .. tostring(p.score))
            p.actions[#p.actions + 1] = { action = "auto_kick", timestamp = now(), score = p.score }
        end
    end

    saveRisk()
    if DAdmin.BroadcastIntelUpdate then DAdmin.BroadcastIntelUpdate() end
    return p, entry
end

function DAdmin.Intel.GetProfile(steamid)
    return riskProfiles[tostring(steamid or "")]
end

function DAdmin.Intel.GetProfiles(limit)
    local out = {}
    for _, p in pairs(riskProfiles or {}) do out[#out + 1] = p end
    table.sort(out, function(a,b) return (tonumber(a.score) or 0) > (tonumber(b.score) or 0) end)
    limit = tonumber(limit) or 50
    while #out > limit do table.remove(out) end
    return out
end

function DAdmin.Intel.ResetProfile(actor, steamid)
    steamid = tostring(steamid or "")
    if steamid == "" then return false end
    riskProfiles[steamid] = nil
    saveRisk()
    if DAdmin.Log then DAdmin.Log("intel_reset", actor or "System", steamid, "risk profile reset") end
    return true
end

function DAdmin.Intel.GetConfig()
    return intelConfig
end

function DAdmin.Intel.SetConfig(cfg)
    if not istable(cfg) then return false end
    intelConfig.auto_punish_enabled = cfg.auto_punish_enabled ~= nil and tobool(cfg.auto_punish_enabled) or intelConfig.auto_punish_enabled
    intelConfig.auto_review_score = math.Clamp(tonumber(cfg.auto_review_score or intelConfig.auto_review_score) or 45, 1, 100)
    intelConfig.auto_case_score = math.Clamp(tonumber(cfg.auto_case_score or intelConfig.auto_case_score) or 65, 1, 100)
    intelConfig.auto_punish_score = math.Clamp(tonumber(cfg.auto_punish_score or intelConfig.auto_punish_score) or 90, 1, 100)
    intelConfig.decay_seconds = math.Clamp(tonumber(cfg.decay_seconds or intelConfig.decay_seconds) or 1800, 60, 86400)
    if istable(cfg.weights) then
        intelConfig.weights = intelConfig.weights or {}
        for k, v in pairs(cfg.weights) do intelConfig.weights[tostring(k)] = math.Clamp(tonumber(v) or 5, 0, 100) end
    end
    saveConfig()
    return true
end

local function staffKey(actor)
    if IsValid(actor) then return actor:SteamID(), actor:Nick() end
    return tostring(actor or "SYSTEM"), tostring(actor or "System")
end

function DAdmin.Intel.RecordStaffAction(actor, action, target, details)
    local sid, name = staffKey(actor)
    if sid == "" then return end
    staffActivity[sid] = staffActivity[sid] or { steamid = sid, name = name, actions = {}, flags = {} }
    local rec = staffActivity[sid]
    rec.name = name
    rec.actions = istable(rec.actions) and rec.actions or {}
    rec.flags = istable(rec.flags) and rec.flags or {}

    local entry = {
        action = tostring(action or "unknown"),
        target = IsValid(target) and target:SteamID() or tostring(target or ""),
        targetName = IsValid(target) and target:Nick() or tostring(target or ""),
        details = tostring(details or ""),
        timestamp = now(),
        time = os.date("%H:%M:%S")
    }
    table.insert(rec.actions, 1, entry)
    while #rec.actions > 200 do table.remove(rec.actions) end

    local cutoff = now() - (tonumber(intelConfig.staff_abuse_window) or 600)
    local recent = 0
    for _, a in ipairs(rec.actions) do
        if tonumber(a.timestamp or 0) >= cutoff then recent = recent + 1 end
    end
    rec.recentCount = recent

    if recent >= (tonumber(intelConfig.staff_abuse_threshold) or 12) then
        local flag = { timestamp = now(), action = "high_action_rate", count = recent, window = intelConfig.staff_abuse_window }
        table.insert(rec.flags, 1, flag)
        if DAdmin.Log then DAdmin.Log("staff_flag", "System", sid, "High action rate: " .. tostring(recent)) end
    end

    saveStaff()
end

function DAdmin.Intel.GetStaffActivity(limit)
    local out = {}
    for _, rec in pairs(staffActivity or {}) do out[#out + 1] = rec end
    table.sort(out, function(a,b) return (tonumber(a.recentCount) or 0) > (tonumber(b.recentCount) or 0) end)
    limit = tonumber(limit) or 30
    while #out > limit do table.remove(out) end
    return out
end

function DAdmin.Intel.GetSnapshot()
    local profiles = DAdmin.Intel.GetProfiles(40)
    local counts = { clean = 0, watch = 0, review = 0, high = 0, critical = 0 }
    for _, p in ipairs(profiles) do counts[p.level or "clean"] = (counts[p.level or "clean"] or 0) + 1 end
    return {
        config = intelConfig,
        profiles = profiles,
        staff = DAdmin.Intel.GetStaffActivity(30),
        counts = counts
    }
end

load()

-- Hook guard alerts into weighted scoring without rewriting existing guard detectors.
timer.Simple(0, function()
    if DAdmin.Guard and DAdmin.Guard.AddAlert and not DAdmin.Guard._Phase8IntelWrapped then
        local oldAddAlert = DAdmin.Guard.AddAlert
        DAdmin.Guard.AddAlert = function(data)
            local alert = oldAddAlert(data)
            if alert then
                DAdmin.Intel.RecordOffense(alert.steamid, alert.type, alert.confidence, alert.details, "guard")
            end
            return alert
        end
        DAdmin.Guard._Phase8IntelWrapped = true
    end

    if DAdmin.Log and not DAdmin._Phase8LogWrapped then
        local oldLog = DAdmin.Log
        DAdmin.Log = function(action, admin, target, reason, ...)
            if IsValid(admin) then
                DAdmin.Intel.RecordStaffAction(admin, action, target, reason)
            end
            return oldLog(action, admin, target, reason, ...)
        end
        DAdmin._Phase8LogWrapped = true
    end
end)

timer.Create("DAdmin_Intel_Decay", 60, 0, function()
    local changed = false
    for steamid in pairs(riskProfiles or {}) do
        local old = riskProfiles[steamid].score
        DAdmin.Intel.Recalculate(steamid)
        if old ~= riskProfiles[steamid].score then changed = true end
    end
    if changed then saveRisk() end
end)

DAdmin.RegisterCommand("risk", {
    permission = "guard",
    description = "Show a player's intelligence risk profile.",
    category = "Guard",
    args = {{ name = "target", type = "player" }},
    run = function(admin, targets)
        local t = istable(targets) and targets[1] or targets
        if not IsValid(t) then DAdmin.Msg(admin, "No target.") return false end
        local p = DAdmin.Intel.GetProfile(t:SteamID()) or DAdmin.Intel.RecordOffense(t, "manual_check", 0, "profile opened", "manual")
        DAdmin.Msg(admin, t:Nick() .. " risk: " .. tostring(p.score or 0) .. " [" .. tostring(p.level or "clean") .. "]")
        return true
    end
})

DAdmin.RegisterCommand("resetrisk", {
    permission = "guard.admin",
    description = "Reset a player's intelligence risk profile.",
    category = "Guard",
    args = {{ name = "target", type = "player" }},
    run = function(admin, targets)
        local t = istable(targets) and targets[1] or targets
        if not IsValid(t) then DAdmin.Msg(admin, "No target.") return false end
        DAdmin.Intel.ResetProfile(admin, t:SteamID())
        DAdmin.Msg(admin, "Reset risk profile for " .. t:Nick())
        return true
    end
})
