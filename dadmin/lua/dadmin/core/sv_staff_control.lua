-- DAdmin Phase 8 - Staff Control / Case Ownership
-- Adds active staff tracking, claim locks, and case coordination helpers.
if CLIENT then return end

DAdmin = DAdmin or {}
DAdmin.StaffControl = DAdmin.StaffControl or {}

local ACTIVE_FILE = "staff_control.json"
local active = {}
local locks = {}

local function now() return os.time() end
local function save()
    if DAdmin.Storage and DAdmin.Storage.Save then DAdmin.Storage.Save(ACTIVE_FILE, active) end
end
local function load()
    active = DAdmin.Storage and DAdmin.Storage.Load and DAdmin.Storage.Load(ACTIVE_FILE, {}) or {}
end

local function actorInfo(ply)
    if IsValid(ply) then
        return ply:SteamID(), ply:Nick()
    end
    return tostring(ply or "SYSTEM"), tostring(ply or "System")
end

function DAdmin.StaffControl.Touch(ply, state)
    if not IsValid(ply) then return end
    local sid = ply:SteamID()
    active[sid] = active[sid] or {}
    active[sid].steamid = sid
    active[sid].name = ply:Nick()
    active[sid].rank = DAdmin.GetUserRank and DAdmin.GetUserRank(ply) or "user"
    active[sid].lastSeen = now()
    active[sid].state = state or active[sid].state or "active"
    save()
end

function DAdmin.StaffControl.GetActive()
    local out = {}
    local cutoff = now() - 600
    for sid, rec in pairs(active or {}) do
        if tonumber(rec.lastSeen or 0) >= cutoff then out[#out + 1] = rec end
    end
    table.sort(out, function(a,b) return tostring(a.name) < tostring(b.name) end)
    return out
end

function DAdmin.StaffControl.ClaimCase(ply, caseID, force)
    local case = DAdmin.Cases and DAdmin.Cases.Get and DAdmin.Cases.Get(caseID)
    if not case then return false, "Case not found." end
    local sid, name = actorInfo(ply)
    if case.claimedBy and case.claimedBy ~= sid and not force then
        return false, "Case already claimed by " .. tostring(case.claimedByName or case.claimedBy)
    end
    case.claimedBy = sid
    case.claimedByName = name
    case.claimedAt = now()
    locks[tostring(case.id)] = { steamid = sid, name = name, timestamp = now() }
    if DAdmin.Cases.AddTimeline then DAdmin.Cases.AddTimeline(case.id, "case_claimed", ply, "Claimed by " .. name) end
    if DAdmin.Cases.Save then DAdmin.Cases.Save() end
    if DAdmin.Log then DAdmin.Log("case_claim", ply, case.playerSteamID or case.id, case.id) end
    return true
end

function DAdmin.StaffControl.ReleaseCase(ply, caseID)
    local case = DAdmin.Cases and DAdmin.Cases.Get and DAdmin.Cases.Get(caseID)
    if not case then return false, "Case not found." end
    local sid = IsValid(ply) and ply:SteamID() or tostring(ply or "SYSTEM")
    if case.claimedBy and case.claimedBy ~= sid and not (DAdmin.HasPermission and DAdmin.HasPermission(ply, "reports.override")) then
        return false, "Only the owner or override staff can release this case."
    end
    case.claimedBy = nil
    case.claimedByName = nil
    case.claimedAt = nil
    locks[tostring(case.id)] = nil
    if DAdmin.Cases.AddTimeline then DAdmin.Cases.AddTimeline(case.id, "case_released", ply, "Released") end
    if DAdmin.Cases.Save then DAdmin.Cases.Save() end
    return true
end

function DAdmin.StaffControl.CanEditCase(ply, caseID)
    if not IsValid(ply) then return true end
    local case = DAdmin.Cases and DAdmin.Cases.Get and DAdmin.Cases.Get(caseID)
    if not case then return false, "Case not found." end
    if not case.claimedBy or case.claimedBy == ply:SteamID() then return true end
    if DAdmin.HasPermission and DAdmin.HasPermission(ply, "reports.override") then return true end
    return false, "Case is claimed by " .. tostring(case.claimedByName or case.claimedBy)
end

function DAdmin.StaffControl.GetLocks()
    return locks
end

load()

hook.Add("PlayerInitialSpawn", "DAdmin_StaffControlJoin", function(ply)
    timer.Simple(2, function()
        if IsValid(ply) and DAdmin.HasPermission and DAdmin.HasPermission(ply, "menu") then
            DAdmin.StaffControl.Touch(ply, "online")
        end
    end)
end)

hook.Add("PlayerDisconnected", "DAdmin_StaffControlLeave", function(ply)
    if not IsValid(ply) then return end
    local sid = ply:SteamID()
    if active[sid] then active[sid].state = "offline"; active[sid].lastSeen = now(); save() end
end)

timer.Create("DAdmin_StaffControlPulse", 30, 0, function()
    for _, ply in ipairs(player.GetAll()) do
        if DAdmin.HasPermission and DAdmin.HasPermission(ply, "menu") then
            DAdmin.StaffControl.Touch(ply, "online")
        end
    end
end)

DAdmin.RegisterCommand("claimcase", {
    permission = "cases",
    description = "Claim ownership of a moderation case.",
    category = "Moderation",
    args = {{ name = "caseid", type = "string" }},
    run = function(admin, caseID)
        local ok, err = DAdmin.StaffControl.ClaimCase(admin, caseID)
        DAdmin.Msg(admin, ok and "Case claimed." or err)
        return ok
    end
})

DAdmin.RegisterCommand("releasecase", {
    permission = "cases",
    description = "Release ownership of a moderation case.",
    category = "Moderation",
    args = {{ name = "caseid", type = "string" }},
    run = function(admin, caseID)
        local ok, err = DAdmin.StaffControl.ReleaseCase(admin, caseID)
        DAdmin.Msg(admin, ok and "Case released." or err)
        return ok
    end
})
