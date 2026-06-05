-- DAdmin Report Core
-- Phase 4: full report workflow: create -> claim -> sit -> resolve/dismiss.
if CLIENT then return end

DAdmin = DAdmin or {}
DAdmin.Reports = DAdmin.Reports or {}

local REPORT_FILE = "reports.json"
local reports = {}

local function newID(prefix)
    return (prefix or "report") .. "_" .. tostring(os.time()) .. "_" .. tostring(math.random(1000, 9999))
end

local function getName(steamid)
    local ply = DAdmin.Players and DAdmin.Players.FindBySteamID and DAdmin.Players.FindBySteamID(steamid)
    return IsValid(ply) and ply:Nick() or tostring(steamid or "Unknown")
end

local function findReport(reportID)
    reportID = tostring(reportID or "")
    for _, report in ipairs(reports) do
        if tostring(report.id) == reportID then return report end
    end
end

function DAdmin.Reports.Load()
    reports = (DAdmin.Storage and DAdmin.Storage.Load and DAdmin.Storage.Load(REPORT_FILE, {})) or {}
    return reports
end

function DAdmin.Reports.Save()
    if DAdmin.Storage and DAdmin.Storage.Save then
        DAdmin.Storage.Save(REPORT_FILE, reports)
    end
end

function DAdmin.Reports.Create(reporter, target, reason, priority)
    if not IsValid(reporter) then return false, "invalid reporter" end
    if not IsValid(target) then return false, "invalid target" end

    local report = {
        id = newID("report"),
        reporterSteamID = reporter:SteamID(),
        reporterName = reporter:Nick(),
        targetSteamID = target:SteamID(),
        targetName = target:Nick(),
        reason = tostring(reason or "No reason"),
        priority = tostring(priority or "medium"),
        timestamp = os.time(),
        status = "open",
        claimedBy = nil,
        claimedAt = nil,
        closedBy = nil,
        closedAt = nil,
        resolution = nil,
        caseID = nil,
        sitID = nil
    }

    table.insert(reports, 1, report)
    DAdmin.Reports.Save()

    if DAdmin.Cases and DAdmin.Cases.Create then
        local case = DAdmin.Cases.Create(report.targetSteamID, report.id, nil, report.reason)
        report.caseID = case and case.id or nil
        DAdmin.Reports.Save()
    end

    if DAdmin.History and DAdmin.History.Add then
        DAdmin.History.Add(report.reporterSteamID, "reports", { reportID = report.id, role = "reporter", targetSteamID = report.targetSteamID, reason = report.reason })
        DAdmin.History.Add(report.targetSteamID, "reports", { reportID = report.id, role = "target", reporterSteamID = report.reporterSteamID, reason = report.reason })
    end

    if DAdmin.Log then DAdmin.Log("report_created", reporter, target, report.reason) end
    if DAdmin.BroadcastReportUpdate then DAdmin.BroadcastReportUpdate() end

    return report
end

function DAdmin.Reports.GetAll()
    return reports
end

function DAdmin.Reports.Get(reportID)
    return findReport(reportID)
end

function DAdmin.Reports.Claim(admin, reportID)
    if not IsValid(admin) then return false, "invalid admin" end
    if DAdmin.HasPermission and not DAdmin.HasPermission(admin, "reports") then return false, "permission denied" end

    local report = findReport(reportID)
    if not report then return false, "report not found" end
    if report.status ~= "open" then return false, "report is not open" end

    report.status = "claimed"
    report.claimedBy = admin:SteamID()
    report.claimedByName = admin:Nick()
    report.claimedAt = os.time()

    if report.caseID and DAdmin.Cases and DAdmin.Cases.AddTimeline then
        DAdmin.Cases.AddTimeline(report.caseID, "report_claimed", admin, "Report claimed by " .. admin:Nick())
    end

    DAdmin.Reports.Save()
    if DAdmin.Log then DAdmin.Log("report_claimed", admin, report.targetSteamID, report.id) end
    if DAdmin.BroadcastReportUpdate then DAdmin.BroadcastReportUpdate() end
    return true
end

function DAdmin.Reports.Resolve(admin, reportID, resolution)
    if not IsValid(admin) then return false, "invalid admin" end
    local report = findReport(reportID)
    if not report then return false, "report not found" end
    if report.status == "resolved" then return false, "already resolved" end

    if report.claimedBy and report.claimedBy ~= admin:SteamID() and not (DAdmin.HasPermission and DAdmin.HasPermission(admin, "reports.override")) then
        return false, "report is claimed by another admin"
    end

    report.status = "resolved"
    report.closedBy = admin:SteamID()
    report.closedByName = admin:Nick()
    report.closedAt = os.time()
    report.resolution = tostring(resolution or "Resolved")

    if report.caseID and DAdmin.Cases and DAdmin.Cases.Close then
        DAdmin.Cases.Close(report.caseID, admin, report.resolution)
    end

    DAdmin.Metrics = DAdmin.Metrics or {}
    DAdmin.Metrics.reportsHandled = (DAdmin.Metrics.reportsHandled or 0) + 1

    DAdmin.Reports.Save()
    if DAdmin.Log then DAdmin.Log("report_resolved", admin, report.targetSteamID, report.resolution) end
    if DAdmin.BroadcastReportUpdate then DAdmin.BroadcastReportUpdate() end
    return true
end

function DAdmin.Reports.Dismiss(admin, reportID, reason)
    local report = findReport(reportID)
    if not report then return false, "report not found" end

    report.status = "dismissed"
    report.closedBy = IsValid(admin) and admin:SteamID() or "CONSOLE"
    report.closedByName = IsValid(admin) and admin:Nick() or "Console"
    report.closedAt = os.time()
    report.resolution = tostring(reason or "Dismissed")

    if report.caseID and DAdmin.Cases and DAdmin.Cases.Close then
        DAdmin.Cases.Close(report.caseID, admin, report.resolution)
    end

    DAdmin.Reports.Save()
    if DAdmin.Log then DAdmin.Log("report_dismissed", admin or "Console", report.targetSteamID, report.resolution) end
    if DAdmin.BroadcastReportUpdate then DAdmin.BroadcastReportUpdate() end
    return true
end

function DAdmin.Reports.Reopen(admin, reportID)
    if not IsValid(admin) then return false, "invalid admin" end
    if DAdmin.HasPermission and not DAdmin.HasPermission(admin, "reports") then return false, "permission denied" end

    local report = findReport(reportID)
    if not report then return false, "report not found" end

    if report.claimedBy and report.claimedBy ~= admin:SteamID() and not (DAdmin.HasPermission and DAdmin.HasPermission(admin, "reports.override")) then
        return false, "report is claimed by another admin"
    end

    report.status = "open"
    report.claimedBy = nil
    report.claimedByName = nil
    report.claimedAt = nil
    report.closedBy = nil
    report.closedByName = nil
    report.closedAt = nil
    report.resolution = nil

    if report.caseID and DAdmin.Cases and DAdmin.Cases.AddTimeline then
        DAdmin.Cases.AddTimeline(report.caseID, "report_reopened", admin, "Report reopened by " .. admin:Nick())
    end

    DAdmin.Reports.Save()
    if DAdmin.Log then DAdmin.Log("report_reopened", admin, report.targetSteamID, report.id) end
    if DAdmin.BroadcastReportUpdate then DAdmin.BroadcastReportUpdate() end
    return true
end

function DAdmin.Reports.SetPriority(admin, reportID, priority)
    if not IsValid(admin) then return false, "invalid admin" end
    if DAdmin.HasPermission and not DAdmin.HasPermission(admin, "reports") then return false, "permission denied" end

    priority = string.lower(tostring(priority or "medium"))
    if priority ~= "low" and priority ~= "medium" and priority ~= "high" then
        priority = "medium"
    end

    local report = findReport(reportID)
    if not report then return false, "report not found" end

    report.priority = priority

    if report.caseID and DAdmin.Cases and DAdmin.Cases.AddTimeline then
        DAdmin.Cases.AddTimeline(report.caseID, "report_priority", admin, "Priority set to " .. priority)
    end

    DAdmin.Reports.Save()
    if DAdmin.Log then DAdmin.Log("report_priority", admin, report.targetSteamID, priority) end
    if DAdmin.BroadcastReportUpdate then DAdmin.BroadcastReportUpdate() end
    return true
end

-- Legacy delete button now means safe dismissal; records are retained for audit.
function DAdmin.Reports.Delete(reportID, admin)
    return DAdmin.Reports.Dismiss(admin, reportID, "Dismissed")
end

DAdmin.Reports.Load()

DAdmin.RegisterCommand("report", {
    permission = "",
    description = "Report a player to online staff",
    category = "Reports",
    args = {
        { name = "target", type = "player" },
        { name = "reason", type = "string", optional = true }
    },
    run = function(ply, targets, reason)
        local target = targets and targets[1]
        if not IsValid(target) then DAdmin.Msg(ply, "No target found.") return false end
        local report = DAdmin.Reports.Create(ply, target, reason or "No reason")
        if report then
            DAdmin.Msg(ply, "Report submitted. ID: " .. tostring(report.id))
            for _, admin in ipairs(player.GetAll()) do
                if DAdmin.HasPermission and DAdmin.HasPermission(admin, "reports") then
                    DAdmin.Msg(admin, "New report: " .. ply:Nick() .. " reported " .. target:Nick() .. " - " .. tostring(reason or "No reason"))
                end
            end
        end
    end
})

DAdmin.RegisterCommand("claimreport", {
    permission = "reports",
    description = "Claim an open report",
    category = "Reports",
    args = {{ name = "reportid", type = "string" }},
    run = function(admin, reportID)
        local ok, err = DAdmin.Reports.Claim(admin, reportID)
        DAdmin.Msg(admin, ok and "Report claimed." or ("Could not claim report: " .. tostring(err)))
        return ok
    end
})

DAdmin.RegisterCommand("resolvereport", {
    permission = "reports",
    description = "Resolve a claimed report",
    category = "Reports",
    args = {{ name = "reportid", type = "string" }, { name = "resolution", type = "string", optional = true }},
    run = function(admin, reportID, resolution)
        local ok, err = DAdmin.Reports.Resolve(admin, reportID, resolution or "Resolved")
        DAdmin.Msg(admin, ok and "Report resolved." or ("Could not resolve report: " .. tostring(err)))
        return ok
    end
})

DAdmin.RegisterCommand("dismissreport", {
    permission = "reports",
    description = "Dismiss a report but keep its audit trail",
    category = "Reports",
    args = {{ name = "reportid", type = "string" }, { name = "reason", type = "string", optional = true }},
    run = function(admin, reportID, reason)
        local ok, err = DAdmin.Reports.Dismiss(admin, reportID, reason or "Dismissed")
        DAdmin.Msg(admin, ok and "Report dismissed." or ("Could not dismiss report: " .. tostring(err)))
        return ok
    end
})
