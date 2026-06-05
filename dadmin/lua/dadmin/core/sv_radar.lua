-- DAdmin Radar System
DAdmin = DAdmin or {}
DAdmin.Radar = DAdmin.Radar or {}

util.AddNetworkString("dadmin_radar_alert")

local radarEvents = {}

function DAdmin.Radar.Trigger(eventType, ply, data)
    local alert = {
        event = eventType,
        player = ply:Nick(),
        steamid = ply:SteamID(),
        data = data,
        timestamp = os.time()
    }
    table.insert(radarEvents, alert)
    -- Broadcast to admins
    for _, admin in ipairs(player.GetAll()) do
        if DAdmin:IsAdmin(admin) then
            net.Start("dadmin_radar_alert")
            net.WriteTable(alert)
            net.Send(admin)
        end
    end
    -- Log
    DAdmin.Log("radar_alert", ply:Nick(), eventType, data)
end

function DAdmin.Radar.GetRecentAlerts(limit)
    local out = {}
    for i = #radarEvents, 1, -1 do
        table.insert(out, radarEvents[i])
        if #out >= (limit or 10) then break end
    end
    return out
end

-- Prop spam detector
local propCounts = {}
hook.Add("PlayerSpawnedProp", "DAdminRadarPropSpam", function(ply)
    local sid = ply:SteamID()
    propCounts[sid] = propCounts[sid] or {}
    table.insert(propCounts[sid], os.time())
    -- Remove old
    for i=#propCounts[sid],1,-1 do
        if os.time() - propCounts[sid][i] > 10 then table.remove(propCounts[sid],i) end
    end
    if #propCounts[sid] > 30 then
        DAdmin.Radar.Trigger("prop_spam", ply, {count=#propCounts[sid]})
        propCounts[sid] = {}
    end
end)

-- Mass kill detector
local killTimes = {}
hook.Add("PlayerDeath", "DAdminRadarMassKill", function(victim, inflictor, attacker)
    if not IsValid(attacker) or not attacker:IsPlayer() then return end
    local sid = attacker:SteamID()
    killTimes[sid] = killTimes[sid] or {}
    table.insert(killTimes[sid], os.time())
    for i=#killTimes[sid],1,-1 do
        if os.time() - killTimes[sid][i] > 10 then table.remove(killTimes[sid],i) end
    end
    if #killTimes[sid] >= 5 then
        DAdmin.Radar.Trigger("mass_kill", attacker, {kills=#killTimes[sid]})
        killTimes[sid] = {}
    end
end)

-- Command spam detector
local cmdCounts = {}
function DAdmin.Radar.TrackCommand(ply)
    local sid = ply:SteamID()
    cmdCounts[sid] = cmdCounts[sid] or {}
    table.insert(cmdCounts[sid], os.time())
    for i=#cmdCounts[sid],1,-1 do
        if os.time() - cmdCounts[sid][i] > 5 then table.remove(cmdCounts[sid],i) end
    end
    if #cmdCounts[sid] >= 10 then
        DAdmin.Radar.Trigger("command_spam", ply, {count=#cmdCounts[sid]})
        cmdCounts[sid] = {}
    end
end

-- Report spam detector
local reportCounts = {}
function DAdmin.Radar.TrackReport(ply)
    local sid = ply:SteamID()
    reportCounts[sid] = reportCounts[sid] or {}
    table.insert(reportCounts[sid], os.time())
    for i=#reportCounts[sid],1,-1 do
        if os.time() - reportCounts[sid][i] > 10 then table.remove(reportCounts[sid],i) end
    end
    if #reportCounts[sid] >= 5 then
        DAdmin.Radar.Trigger("report_spam", ply, {count=#reportCounts[sid]})
        reportCounts[sid] = {}
    end
end
