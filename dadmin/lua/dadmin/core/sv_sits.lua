-- DAdmin Sit Core
-- Phase 4: staff sit lifecycle with bring/freeze/return.
if CLIENT then return end

DAdmin = DAdmin or {}
DAdmin.Sits = DAdmin.Sits or {}
DAdmin.ReturnPositions = DAdmin.ReturnPositions or {}

local sits = {}

local function newID()
    return "sit_" .. tostring(os.time()) .. "_" .. tostring(math.random(1000, 9999))
end

local function getRestrictionSources(ply)
    if not IsValid(ply) then return {} end
    ply.DAdminSpawnRestrictionSources = ply.DAdminSpawnRestrictionSources or {}
    return ply.DAdminSpawnRestrictionSources
end

local function getFreezeSources(ply)
    if not IsValid(ply) then return {} end
    ply.DAdminFreezeSources = ply.DAdminFreezeSources or {}
    return ply.DAdminFreezeSources
end

local function hasEntries(tbl)
    return next(tbl or {}) ~= nil
end

function DAdmin.SetSpawnRestricted(ply, source, enabled)
    if not IsValid(ply) then return end
    source = tostring(source or "generic")

    local sources = getRestrictionSources(ply)
    if enabled then
        sources[source] = true
    else
        sources[source] = nil
    end

    local active = hasEntries(sources)
    ply:SetNWBool("DAdminSpawnRestricted", active)
    if not active then
        ply.DAdminSpawnRestrictionSources = nil
    end
end

function DAdmin.SetPlayerFrozenState(ply, source, enabled)
    if not IsValid(ply) then return end
    source = tostring(source or "generic")

    local sources = getFreezeSources(ply)
    if enabled then
        sources[source] = true
        if ply:InVehicle() then ply:ExitVehicle() end
    else
        sources[source] = nil
    end

    local active = hasEntries(sources)
    ply:SetNWBool("DAdminFrozen", active)
    ply:Freeze(active)

    if not active then
        ply.DAdminFreezeSources = nil
    end
end

function DAdmin.IsPlayerSpawnRestricted(ply)
    if not IsValid(ply) then return false end
    return ply:GetNWBool("DAdminSpawnRestricted", false)
        or ply:GetNWBool("DAdminFrozen", false)
        or ply:GetNWBool("InSit", false)
end

local function safePos(ply)
    return IsValid(ply) and ply:GetPos() or nil
end

local function resolveOne(admin, raw)
    if IsValid(raw) then return raw end
    local targets = DAdmin.Players and DAdmin.Players.ResolveTarget and DAdmin.Players.ResolveTarget(admin, raw) or {}
    return targets[1]
end

function DAdmin.Sits.Start(admin, target, reportID)
    if not IsValid(admin) then return false, "invalid admin" end
    if not IsValid(target) then return false, "invalid target" end
    if admin == target then return false, "cannot start a sit with yourself" end
    if DAdmin.Sits.GetByAdmin(admin) then return false, "you already have an active sit" end

    for _, activeSit in pairs(sits) do
        if activeSit.status == "active" and activeSit.targetSteamID == target:SteamID() then
            return false, "target is already in an active sit"
        end
    end

    local id = newID()
    local sit = {
        id = id,
        adminSteamID = admin:SteamID(),
        adminName = admin:Nick(),
        targetSteamID = target:SteamID(),
        targetName = target:Nick(),
        reportID = reportID and tostring(reportID) or nil,
        caseID = nil,
        startTime = os.time(),
        endTime = nil,
        status = "active",
        adminReturn = safePos(admin),
        targetReturn = safePos(target)
    }

    local report = reportID and DAdmin.Reports and DAdmin.Reports.Get and DAdmin.Reports.Get(reportID)
    if report then
        if report.status == "open" and DAdmin.Reports.Claim then DAdmin.Reports.Claim(admin, reportID) end
        sit.caseID = report.caseID
        report.sitID = id
    elseif DAdmin.Cases and DAdmin.Cases.Create then
        local case = DAdmin.Cases.Create(target:SteamID(), nil, admin:SteamID(), "Staff sit")
        sit.caseID = case and case.id or nil
    end

    sits[id] = sit
    DAdmin.ReturnPositions[target] = sit.targetReturn
    DAdmin.ReturnPositions[admin] = sit.adminReturn

    target:SetPos(admin:GetPos() + admin:GetForward() * 90)
    target:SetNWBool("InSit", true)
    admin:SetNWBool("InSit", true)
    DAdmin.SetSpawnRestricted(target, "sit", true)
    DAdmin.SetSpawnRestricted(admin, "sit", true)
    DAdmin.SetPlayerFrozenState(target, "sit", true)
    target.DAdminSitInvincible = id
    target:GodEnable()

    if DAdmin.Cases and sit.caseID then
        if DAdmin.Cases.AddLink then DAdmin.Cases.AddLink(sit.caseID, "sits", id, admin, "Sit started with " .. target:Nick()) end
        if DAdmin.Cases.AddTimeline then DAdmin.Cases.AddTimeline(sit.caseID, "sit_started", admin, "Sit started with " .. target:Nick()) end
    end

    if DAdmin.History and DAdmin.History.Add then
        DAdmin.History.Add(target:SteamID(), "sits", { sitID = id, adminSteamID = admin:SteamID(), reportID = sit.reportID, status = "started" })
    end

    DAdmin.Metrics = DAdmin.Metrics or {}
    DAdmin.Metrics.sitsStarted = (DAdmin.Metrics.sitsStarted or 0) + 1

    if DAdmin.Log then DAdmin.Log("sit_started", admin, target, sit.reportID or "") end
    if DAdmin.BroadcastReportUpdate then DAdmin.BroadcastReportUpdate() end
    return sit
end

function DAdmin.Sits.End(admin, sitID, resolution)
    sitID = tostring(sitID or "")
    local sit = sits[sitID]
    if not sit or sit.status ~= "active" then return false, "sit not active" end

    local target = DAdmin.Players and DAdmin.Players.FindBySteamID and DAdmin.Players.FindBySteamID(sit.targetSteamID)
    local sitAdmin = DAdmin.Players and DAdmin.Players.FindBySteamID and DAdmin.Players.FindBySteamID(sit.adminSteamID)
    if IsValid(target) then
        target:SetNWBool("InSit", false)
        DAdmin.SetPlayerFrozenState(target, "sit", false)
        DAdmin.SetSpawnRestricted(target, "sit", false)
        if target.DAdminSitInvincible == sitID then target.DAdminSitInvincible = nil target:GodDisable() end
        if sit.targetReturn then target:SetPos(sit.targetReturn) end
    end
    if IsValid(sitAdmin) then
        sitAdmin:SetNWBool("InSit", false)
        DAdmin.SetSpawnRestricted(sitAdmin, "sit", false)
    end

    sit.status = "resolved"
    sit.endTime = os.time()
    sit.resolution = tostring(resolution or "Sit ended")

    if sit.caseID and DAdmin.Cases and DAdmin.Cases.AddTimeline then
        DAdmin.Cases.AddTimeline(sit.caseID, "sit_ended", admin, sit.resolution)
    end

    if DAdmin.History and DAdmin.History.Add then
        DAdmin.History.Add(sit.targetSteamID, "sits", { sitID = sit.id, adminSteamID = sit.adminSteamID, reportID = sit.reportID, status = "ended", resolution = sit.resolution })
    end

    if sit.reportID and DAdmin.Reports and DAdmin.Reports.Resolve then
        DAdmin.Reports.Resolve(admin, sit.reportID, sit.resolution)
    end

    DAdmin.Metrics = DAdmin.Metrics or {}
    DAdmin.Metrics.sitsResolved = (DAdmin.Metrics.sitsResolved or 0) + 1

    sits[sitID] = nil
    if DAdmin.Log then DAdmin.Log("sit_ended", admin, sit.targetSteamID, sit.resolution) end
    if DAdmin.BroadcastReportUpdate then DAdmin.BroadcastReportUpdate() end
    return true
end

function DAdmin.Sits.GetActive()
    return sits
end

function DAdmin.Sits.GetByAdmin(admin)
    if not IsValid(admin) then return nil end
    for _, sit in pairs(sits) do
        if sit.adminSteamID == admin:SteamID() and sit.status == "active" then return sit end
    end
end

hook.Add("PlayerDisconnected", "DAdmin_SitDisconnectCleanup", function(ply)
    for id, sit in pairs(sits) do
        if sit.targetSteamID == ply:SteamID() or sit.adminSteamID == ply:SteamID() then
            local target = DAdmin.Players and DAdmin.Players.FindBySteamID and DAdmin.Players.FindBySteamID(sit.targetSteamID)
            local admin = DAdmin.Players and DAdmin.Players.FindBySteamID and DAdmin.Players.FindBySteamID(sit.adminSteamID)
            if IsValid(target) then
                target:SetNWBool("InSit", false)
                DAdmin.SetPlayerFrozenState(target, "sit", false)
                DAdmin.SetSpawnRestricted(target, "sit", false)
                if target.DAdminSitInvincible == id then
                    target.DAdminSitInvincible = nil
                    target:GodDisable()
                end
            end
            if IsValid(admin) then
                admin:SetNWBool("InSit", false)
                DAdmin.SetSpawnRestricted(admin, "sit", false)
            end
            sit.status = "interrupted"
            sit.endTime = os.time()
            if DAdmin.Log then DAdmin.Log("sit_interrupted", "System", ply:SteamID(), id) end
            sits[id] = nil
        end
    end
end)

DAdmin.RegisterCommand("startsit", {
    permission = "reports",
    description = "Start a staff sit with a player",
    category = "Reports",
    aliases = {"sit"},
    args = {
        { name = "target", type = "player" },
        { name = "reportid", type = "string", optional = true }
    },
    run = function(admin, targets, reportID)
        local target = targets and targets[1]
        local sit, err = DAdmin.Sits.Start(admin, target, reportID)
        DAdmin.Msg(admin, sit and ("Sit started: " .. sit.id) or ("Could not start sit: " .. tostring(err)))
        return sit ~= false
    end
})

DAdmin.RegisterCommand("endsit", {
    permission = "reports",
    description = "End your active staff sit or a sit by ID",
    category = "Reports",
    aliases = {"unsit"},
    args = {
        { name = "sitid", type = "string", optional = true },
        { name = "resolution", type = "string", optional = true }
    },
    run = function(admin, sitID, resolution)
        if not sitID or sitID == "" then
            local active = DAdmin.Sits.GetByAdmin(admin)
            sitID = active and active.id or nil
        end
        local ok, err = DAdmin.Sits.End(admin, sitID, resolution or "Resolved in staff sit")
        DAdmin.Msg(admin, ok and "Sit ended." or ("Could not end sit: " .. tostring(err)))
        return ok
    end
})


hook.Add("EntityTakeDamage", "DAdminSitInvincible", function(ent)
    if IsValid(ent) and ent:IsPlayer() and ent.DAdminSitInvincible then return true end
end)

local function blockRestrainedSpawn(ply, thing)
    if not DAdmin.IsPlayerSpawnRestricted(ply) then return end
    if DAdmin.Msg then
        DAdmin.Msg(ply, "You cannot spawn " .. tostring(thing or "items") .. " while frozen or in a sit.")
    end
    return false
end

hook.Add("PlayerSpawnProp", "DAdmin_BlockRestrainedProps", function(ply)
    return blockRestrainedSpawn(ply, "props")
end)

hook.Add("PlayerSpawnRagdoll", "DAdmin_BlockRestrainedRagdolls", function(ply)
    return blockRestrainedSpawn(ply, "ragdolls")
end)

hook.Add("PlayerSpawnEffect", "DAdmin_BlockRestrainedEffects", function(ply)
    return blockRestrainedSpawn(ply, "effects")
end)

hook.Add("PlayerSpawnSENT", "DAdmin_BlockRestrainedSENTs", function(ply)
    return blockRestrainedSpawn(ply, "entities")
end)

hook.Add("PlayerSpawnVehicle", "DAdmin_BlockRestrainedVehicles", function(ply)
    return blockRestrainedSpawn(ply, "vehicles")
end)
