-- DAdmin Moderation Case System
-- Phase 5: cases link reports, sits, punishments, warnings, logs, and history.
if CLIENT then return end

DAdmin = DAdmin or {}
DAdmin.Cases = DAdmin.Cases or {}

local CASE_FILE = "cases.json"
local MAX_CASES = 2000
local cases = {}

local function now() return os.time() end
local function newID(prefix)
    return (prefix or "case") .. "_" .. tostring(now()) .. "_" .. tostring(math.random(1000, 9999))
end

local function actorInfo(actor)
    if IsValid(actor) then return actor:Nick(), actor:SteamID() end
    if isstring(actor) then return actor, actor end
    if istable(actor) then return tostring(actor.name or actor.admin or "System"), tostring(actor.steamid or actor.adminSteamID or "SYSTEM") end
    return "System", "SYSTEM"
end

local function findCase(caseID)
    caseID = tostring(caseID or "")
    for _, c in ipairs(cases) do
        if tostring(c.id) == caseID then return c end
    end
end

local function ensureCaseShape(c)
    c.timeline = istable(c.timeline) and c.timeline or {}
    c.links = istable(c.links) and c.links or {}
    c.links.reports = istable(c.links.reports) and c.links.reports or {}
    c.links.sits = istable(c.links.sits) and c.links.sits or {}
    c.links.punishments = istable(c.links.punishments) and c.links.punishments or {}
    c.links.warnings = istable(c.links.warnings) and c.links.warnings or {}
    c.links.logs = istable(c.links.logs) and c.links.logs or {}
    c.status = c.status or "open"
    c.created = c.created or now()
    return c
end

function DAdmin.Cases.Load()
    cases = (DAdmin.Storage and DAdmin.Storage.Load and DAdmin.Storage.Load(CASE_FILE, {})) or {}
    for _, c in ipairs(cases) do ensureCaseShape(c) end
    return cases
end

function DAdmin.Cases.Save()
    if DAdmin.Storage and DAdmin.Storage.Save then
        return DAdmin.Storage.Save(CASE_FILE, cases)
    end
end

function DAdmin.Cases.Create(playerSteamID, reportID, adminSteamID, reason)
    local case = ensureCaseShape({
        id = newID("case"),
        playerSteamID = tostring(playerSteamID or ""),
        reportID = reportID and tostring(reportID) or nil,
        adminSteamID = adminSteamID and tostring(adminSteamID) or nil,
        reason = tostring(reason or ""),
        status = "open",
        created = now(),
        closed = nil,
        resolution = nil,
        timeline = {},
        links = {}
    })

    if case.reportID then table.insert(case.links.reports, 1, case.reportID) end
    table.insert(cases, 1, case)
    DAdmin.Cases.AddTimeline(case.id, "case_opened", adminSteamID or "System", reason or "")
    DAdmin.Cases.Save()

    if DAdmin.History and DAdmin.History.Add and case.playerSteamID ~= "" then
        DAdmin.History.Add(case.playerSteamID, "cases", {
            caseID = case.id,
            reportID = case.reportID,
            adminSteamID = case.adminSteamID,
            reason = case.reason,
            status = case.status
        })
        DAdmin.History.Link(case.playerSteamID, "cases", case.id)
    end

    if DAdmin.BroadcastCaseUpdate then DAdmin.BroadcastCaseUpdate() end
    return case
end

function DAdmin.Cases.AddTimeline(caseID, action, actor, details)
    local case = findCase(caseID)
    if not case then return false end
    ensureCaseShape(case)

    local name, steamid = actorInfo(actor)
    local entry = {
        id = "timeline_" .. tostring(now()) .. "_" .. tostring(math.random(1000, 9999)),
        timestamp = now(),
        action = tostring(action or "event"),
        actor = name,
        actorSteamID = steamid,
        details = tostring(details or "")
    }

    table.insert(case.timeline, 1, entry)

    if DAdmin.History and DAdmin.History.Add and case.playerSteamID and case.playerSteamID ~= "" then
        DAdmin.History.Add(case.playerSteamID, "cases", {
            caseID = case.id,
            timelineID = entry.id,
            action = entry.action,
            actor = entry.actor,
            actorSteamID = entry.actorSteamID,
            details = entry.details,
            status = case.status
        })
    end

    DAdmin.Cases.Save()
    if DAdmin.BroadcastCaseUpdate then DAdmin.BroadcastCaseUpdate() end
    return true, entry
end

function DAdmin.Cases.AddLink(caseID, linkType, value, actor, details)
    local case = findCase(caseID)
    if not case then return false, "case not found" end
    ensureCaseShape(case)

    linkType = tostring(linkType or "logs")
    case.links[linkType] = istable(case.links[linkType]) and case.links[linkType] or {}
    table.insert(case.links[linkType], 1, value)

    DAdmin.Cases.AddTimeline(caseID, "linked_" .. linkType, actor or "System", details or tostring(value))
    DAdmin.Cases.Save()
    return true
end

function DAdmin.Cases.AttachPunishment(caseID, punishment, actor)
    if not istable(punishment) then return false, "invalid punishment" end
    return DAdmin.Cases.AddLink(caseID, "punishments", punishment, actor, punishment.type or punishment.id or "punishment")
end

function DAdmin.Cases.AttachWarning(caseID, warn, actor)
    if not istable(warn) then return false, "invalid warning" end
    return DAdmin.Cases.AddLink(caseID, "warnings", warn, actor, warn.reason or warn.id or "warning")
end

function DAdmin.Cases.Close(caseID, admin, resolution)
    local case = findCase(caseID)
    if not case or case.status == "closed" then return false end

    case.status = "closed"
    case.closed = now()
    case.resolution = tostring(resolution or "Closed")
    DAdmin.Cases.AddTimeline(caseID, "case_closed", admin, case.resolution)

    if DAdmin.History and DAdmin.History.Add and case.playerSteamID and case.playerSteamID ~= "" then
        DAdmin.History.Add(case.playerSteamID, "cases", {
            caseID = case.id,
            status = "closed",
            resolution = case.resolution,
            closed = case.closed
        })
    end

    if DAdmin.Log then DAdmin.Log("case_closed", admin, case.playerSteamID, case.resolution) end
    DAdmin.Cases.Save()
    return true
end

function DAdmin.Cases.GetAll()
    return cases
end

function DAdmin.Cases.Get(caseID)
    return findCase(caseID)
end

function DAdmin.Cases.FindByReport(reportID)
    reportID = tostring(reportID or "")
    for _, case in ipairs(cases) do
        if tostring(case.reportID or "") == reportID then return case end
        if istable(case.links) and istable(case.links.reports) then
            for _, id in ipairs(case.links.reports) do
                if tostring(id) == reportID then return case end
            end
        end
    end
end

function DAdmin.Cases.FindOpenForPlayer(steamid)
    steamid = tostring(steamid or "")
    for _, case in ipairs(cases) do
        if tostring(case.playerSteamID or "") == steamid and case.status ~= "closed" then return case end
    end
end

function DAdmin.Cases.Prune()
    local removed = 0
    while #cases > MAX_CASES do
        table.remove(cases)
        removed = removed + 1
    end
    if removed > 0 then DAdmin.Cases.Save() end
    return removed
end

DAdmin.Cases.Load()

DAdmin.RegisterCommand("case", {
    permission = "cases",
    description = "Show case status by case id",
    category = "Moderation",
    args = {{ name = "caseid", type = "string" }},
    run = function(admin, caseID)
        local c = DAdmin.Cases.Get(caseID)
        if not c then DAdmin.Msg(admin, "Case not found.") return false end
        DAdmin.Msg(admin, "Case " .. c.id .. " [" .. tostring(c.status) .. "] target=" .. tostring(c.playerSteamID) .. " reason=" .. tostring(c.reason or ""))
        return true
    end
})

DAdmin.RegisterCommand("closecase", {
    permission = "cases.close",
    description = "Close a moderation case",
    category = "Moderation",
    args = {{ name = "caseid", type = "string" }, { name = "resolution", type = "string", optional = true }},
    run = function(admin, caseID, resolution)
        local ok = DAdmin.Cases.Close(caseID, admin, resolution or "Closed")
        DAdmin.Msg(admin, ok and "Case closed." or "Could not close case.")
        return ok
    end
})


-- Phase 8: case coordination helpers.
function DAdmin.Cases.CanEdit(admin, caseID)
    if DAdmin.StaffControl and DAdmin.StaffControl.CanEditCase then
        return DAdmin.StaffControl.CanEditCase(admin, caseID)
    end
    return true
end

function DAdmin.Cases.Merge(admin, fromCaseID, intoCaseID)
    local from = DAdmin.Cases.Get(fromCaseID)
    local into = DAdmin.Cases.Get(intoCaseID)
    if not from or not into or from == into then return false, "invalid cases" end
    local ok, err = DAdmin.Cases.CanEdit(admin, intoCaseID)
    if not ok then return false, err end

    ensureCaseShape(from)
    ensureCaseShape(into)
    into.links = into.links or {}
    for linkType, values in pairs(from.links or {}) do
        into.links[linkType] = into.links[linkType] or {}
        for _, v in ipairs(values) do table.insert(into.links[linkType], 1, v) end
    end
    for _, e in ipairs(from.timeline or {}) do table.insert(into.timeline, e) end
    from.status = "merged"
    from.mergedInto = into.id
    DAdmin.Cases.AddTimeline(into.id, "case_merged", admin, tostring(from.id) .. " merged into this case")
    DAdmin.Cases.AddTimeline(from.id, "case_merged_out", admin, "Merged into " .. tostring(into.id))
    DAdmin.Cases.Save()
    return true
end

function DAdmin.Cases.Split(admin, caseID, reason)
    local old = DAdmin.Cases.Get(caseID)
    if not old then return false, "case not found" end
    local ok, err = DAdmin.Cases.CanEdit(admin, caseID)
    if not ok then return false, err end
    local newCase = DAdmin.Cases.Create(old.playerSteamID, nil, IsValid(admin) and admin:SteamID() or "SYSTEM", reason or ("Split from " .. tostring(caseID)))
    if newCase then
        DAdmin.Cases.AddTimeline(old.id, "case_split", admin, "Created " .. tostring(newCase.id))
        DAdmin.Cases.AddTimeline(newCase.id, "case_split_from", admin, "Split from " .. tostring(old.id))
    end
    return true, newCase
end

DAdmin.RegisterCommand("mergecase", {
    permission = "cases.close",
    description = "Merge one case into another case.",
    category = "Moderation",
    args = {{ name = "from", type = "string" }, { name = "into", type = "string" }},
    run = function(admin, fromID, intoID)
        local ok, err = DAdmin.Cases.Merge(admin, fromID, intoID)
        DAdmin.Msg(admin, ok and "Cases merged." or tostring(err))
        return ok
    end
})

DAdmin.RegisterCommand("splitcase", {
    permission = "cases",
    description = "Create a split child case from an existing case.",
    category = "Moderation",
    args = {{ name = "caseid", type = "string" }, { name = "reason", type = "string", optional = true }},
    run = function(admin, caseID, reason)
        local ok, result = DAdmin.Cases.Split(admin, caseID, reason)
        DAdmin.Msg(admin, ok and ("Created case " .. tostring(result and result.id or "")) or tostring(result))
        return ok
    end
})
