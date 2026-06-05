if CLIENT then return end

DAdmin = DAdmin or {}
DAdmin.SafeZones = DAdmin.SafeZones or {}
DAdmin.SafeZones.File = "safezones.json"
DAdmin.SafeZones.Zones = DAdmin.SafeZones.Zones or {}

util.AddNetworkString("DAdmin_SafeZones_Request")
util.AddNetworkString("DAdmin_SafeZones_Send")
util.AddNetworkString("DAdmin_SafeZones_Save")
util.AddNetworkString("DAdmin_SafeZones_Delete")
util.AddNetworkString("DAdmin_SafeZones_Inside")
util.AddNetworkString("DAdmin_SafeZones_Message")

local function cfg()
    return DAdmin.GetFeatureConfig and DAdmin.GetFeatureConfig() or {}
end

local function can(ply, perm)
    if not IsValid(ply) then return false end
    if DAdmin.HasPermission then
        return DAdmin.HasPermission(ply, perm or "safezones.view")
    end
    return ply:IsAdmin()
end

local function notify(ply, msg)
    if not IsValid(ply) then return end
    net.Start("DAdmin_SafeZones_Message")
        net.WriteString(tostring(msg or ""))
    net.Send(ply)
end

local function vtab(v)
    return { x = math.Round(v.x, 2), y = math.Round(v.y, 2), z = math.Round(v.z, 2) }
end

local function vec(t)
    if isvector(t) then return t end
    t = istable(t) and t or {}
    return Vector(tonumber(t.x or t[1] or 0) or 0, tonumber(t.y or t[2] or 0) or 0, tonumber(t.z or t[3] or 0) or 0)
end

local function defaultSettings()
    local c = cfg()
    return table.Copy(c.safezone_default_settings or {
        god = true,
        block_damage = true,
        strip_weapons = false,
        prevent_fire = true,
        prevent_props = true,
        prevent_sents = true,
        prevent_vehicles = true,
        prevent_npcs = true,
        freeze_props = false,
        no_collide_props = false,
        prevent_physgun = false,
        show_ui = true,
        hud_color = "4A90D9"
    })
end

local function mergeSettings(data)
    local out = defaultSettings()
    if istable(data) then
        for k, v in pairs(data) do out[k] = v == true end
        if data.hud_color then out.hud_color = tostring(data.hud_color) end
    end
    return out
end

local function cleanZone(z)
    z = istable(z) and z or {}
    local corners = {}
    for i = 1, 4 do
        local v = vec(z.corners and z.corners[i] or z["corner" .. i])
        corners[i] = vtab(v)
    end

    local id = tostring(z.id or "")
    if id == "" or id == "new" then
        id = "zone_" .. os.time() .. "_" .. math.random(1000, 9999)
    end

    local settings = mergeSettings(z.settings or {})
    local color = tostring(z.color or settings.hud_color or cfg().safezone_ui_color or "4A90D9")

    return {
        id = id,
        name = string.sub(tostring(z.name or "Safe Zone"), 1, 64),
        corners = corners,
        height = math.Clamp(tonumber(z.height or cfg().safezone_default_height or 160) or 160, 8, 8192),
        settings = settings,
        color = color,
        created = tonumber(z.created or os.time()) or os.time(),
        updated = os.time()
    }
end

local function loadZones()
    DAdmin.SafeZones.Zones = DAdmin.Storage and DAdmin.Storage.Load and DAdmin.Storage.Load(DAdmin.SafeZones.File, {}) or {}
    if not istable(DAdmin.SafeZones.Zones) then DAdmin.SafeZones.Zones = {} end
    for id, z in pairs(table.Copy(DAdmin.SafeZones.Zones)) do
        local clean = cleanZone(z)
        clean.id = tostring(z.id or id)
        DAdmin.SafeZones.Zones[clean.id] = clean
        if clean.id ~= id then DAdmin.SafeZones.Zones[id] = nil end
    end
end

local function saveZones()
    if DAdmin.Storage and DAdmin.Storage.Save then
        DAdmin.Storage.Save(DAdmin.SafeZones.File, DAdmin.SafeZones.Zones or {})
    end
end

loadZones()

function DAdmin.SafeZones.GetAll()
    return DAdmin.SafeZones.Zones or {}
end

local function zoneBounds(z)
    local minx, miny, minz, maxx, maxy
    for i = 1, 4 do
        local p = vec(z.corners and z.corners[i])
        minx = math.min(minx or p.x, p.x)
        miny = math.min(miny or p.y, p.y)
        minz = math.min(minz or p.z, p.z)
        maxx = math.max(maxx or p.x, p.x)
        maxy = math.max(maxy or p.y, p.y)
    end

    local height = tonumber(z.height or 160) or 160
    return Vector(minx or 0, miny or 0, minz or 0), Vector(maxx or 0, maxy or 0, (minz or 0) + height)
end

function DAdmin.SafeZones.Contains(z, pos)
    if not istable(z) or not isvector(pos) then return false end
    local mn, mx = zoneBounds(z)
    return pos.x >= mn.x and pos.x <= mx.x
        and pos.y >= mn.y and pos.y <= mx.y
        and pos.z >= mn.z and pos.z <= mx.z
end

function DAdmin.SafeZones.GetZoneAtPos(pos)
    if cfg().safezones_enabled == false then return nil end
    for _, z in pairs(DAdmin.SafeZones.Zones or {}) do
        if DAdmin.SafeZones.Contains(z, pos) then return z end
    end
end

function DAdmin.SafeZones.GetPlayerZone(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return nil end
    return DAdmin.SafeZones.GetZoneAtPos(ply:GetPos())
end

local function sendZones(ply)
    if not IsValid(ply) then return end
    net.Start("DAdmin_SafeZones_Send")
        net.WriteTable({ zones = DAdmin.SafeZones.Zones or {}, config = cfg() })
    net.Send(ply)
end

local function broadcastZones()
    for _, ply in ipairs(player.GetAll()) do
        if can(ply, "safezones.view") then sendZones(ply) end
    end
end

net.Receive("DAdmin_SafeZones_Request", function(_, ply)
    if not can(ply, "safezones.view") then return end
    sendZones(ply)
end)

net.Receive("DAdmin_SafeZones_Save", function(_, ply)
    if not can(ply, "safezones.manage") and not can(ply, "safezones.edit") then return end

    local incoming = net.ReadTable() or {}
    if incoming.id and DAdmin.SafeZones.Zones[tostring(incoming.id)] == nil and not can(ply, "safezones.create") and not can(ply, "safezones.manage") then
        return
    end

    local z = cleanZone(incoming)
    DAdmin.SafeZones.Zones[z.id] = z
    saveZones()
    broadcastZones()

    if DAdmin.MegaLogs then DAdmin.MegaLogs.Add("safezones", "save", ply, z.name, "Saved safezone " .. z.id) end
    notify(ply, "Saved safezone: " .. z.name)
end)

net.Receive("DAdmin_SafeZones_Delete", function(_, ply)
    if not can(ply, "safezones.delete") and not can(ply, "safezones.manage") then return end
    local id = tostring(net.ReadString() or "")
    local old = DAdmin.SafeZones.Zones[id]
    if not old then return end

    DAdmin.SafeZones.Zones[id] = nil
    saveZones()
    broadcastZones()

    if DAdmin.MegaLogs then DAdmin.MegaLogs.Add("safezones", "delete", ply, old.name or id, "Deleted safezone " .. id) end
    notify(ply, "Deleted safezone: " .. tostring(old.name or id))
end)

local playerState = {}

local function sendInside(ply, z)
    net.Start("DAdmin_SafeZones_Inside")
        net.WriteTable(z or {})
    net.Send(ply)
end

local function restorePlayer(ply, state)
    if not IsValid(ply) then return end

    if state.safezoneGod then
        if not state.hadGod then ply:GodDisable() end
    end

    if state.stripped then
        for _, class in ipairs(state.weapons or {}) do
            if isstring(class) and class ~= "" and not ply:HasWeapon(class) then
                ply:Give(class)
            end
        end
    end

    ply.DAdminSafeZoneActive = nil
end

local function applyPlayerZone(ply, z)
    local sid = ply:SteamID64() or ply:SteamID() or tostring(ply)
    local old = playerState[sid]
    local oldId = old and old.zoneId or ""

    if z and oldId == z.id then
        local settings = z.settings or {}
        if settings.god and not ply:HasGodMode() then ply:GodEnable() end
        return
    end

    if old then restorePlayer(ply, old) end

    if not z then
        playerState[sid] = nil
        sendInside(ply, nil)
        return
    end

    local settings = z.settings or {}
    local state = {
        zoneId = z.id,
        hadGod = ply.HasGodMode and ply:HasGodMode() or false,
        safezoneGod = false,
        stripped = false,
        weapons = {}
    }

    if settings.god then
        state.safezoneGod = true
        ply:GodEnable()
    end

    if settings.strip_weapons then
        for _, wep in ipairs(ply:GetWeapons()) do
            if IsValid(wep) then state.weapons[#state.weapons + 1] = wep:GetClass() end
        end
        ply:StripWeapons()
        state.stripped = true
    end

    ply.DAdminSafeZoneActive = z.id
    playerState[sid] = state
    sendInside(ply, z)

    if DAdmin.MegaLogs then DAdmin.MegaLogs.Add("safezones", "enter", ply, z.name, "Entered safezone " .. z.id) end
end

timer.Create("DAdminSafeZones_PlayerState", 0.25, 0, function()
    if cfg().safezones_enabled == false then return end
    for _, ply in ipairs(player.GetAll()) do
        applyPlayerZone(ply, DAdmin.SafeZones.GetPlayerZone(ply))
    end
end)

hook.Add("PlayerDisconnected", "DAdminSafeZones_CleanupPlayer", function(ply)
    local sid = ply:SteamID64() or ply:SteamID() or tostring(ply)
    playerState[sid] = nil
end)

hook.Add("PlayerDeath", "DAdminSafeZones_ClearOnDeath", function(ply)
    local sid = ply:SteamID64() or ply:SteamID() or tostring(ply)
    playerState[sid] = nil
end)

hook.Add("EntityTakeDamage", "DAdminSafeZones_DamageRules", function(ent, dmg)
    if cfg().safezones_enabled == false then return end

    if IsValid(ent) and ent:IsPlayer() then
        local z = DAdmin.SafeZones.GetPlayerZone(ent)
        if z and (z.settings or {}).block_damage then return true end
    end

    local attacker = dmg:GetAttacker()
    if IsValid(attacker) and attacker:IsPlayer() then
        local z = DAdmin.SafeZones.GetPlayerZone(attacker)
        if z and (z.settings or {}).prevent_fire then return true end
    end
end)

local function blockSpawnInZone(ply, key)
    local z = DAdmin.SafeZones.GetPlayerZone(ply)
    if z and (z.settings or {})[key] then
        notify(ply, "You cannot spawn that inside " .. tostring(z.name or "this safezone") .. ".")
        return false
    end
end

hook.Add("PlayerSpawnProp", "DAdminSafeZones_BlockProps", function(ply) return blockSpawnInZone(ply, "prevent_props") end)
hook.Add("PlayerSpawnRagdoll", "DAdminSafeZones_BlockRagdolls", function(ply) return blockSpawnInZone(ply, "prevent_props") end)
hook.Add("PlayerSpawnEffect", "DAdminSafeZones_BlockEffects", function(ply) return blockSpawnInZone(ply, "prevent_props") end)
hook.Add("PlayerSpawnSENT", "DAdminSafeZones_BlockSENTs", function(ply) return blockSpawnInZone(ply, "prevent_sents") end)
hook.Add("PlayerSpawnVehicle", "DAdminSafeZones_BlockVehicles", function(ply) return blockSpawnInZone(ply, "prevent_vehicles") end)
hook.Add("PlayerSpawnNPC", "DAdminSafeZones_BlockNPCs", function(ply) return blockSpawnInZone(ply, "prevent_npcs") end)

local function applyEntityRules(ply, ent)
    if not IsValid(ply) or not IsValid(ent) then return end
    local z = DAdmin.SafeZones.GetPlayerZone(ply)
    if not z then return end
    local s = z.settings or {}

    if s.freeze_props then
        timer.Simple(0, function()
            if not IsValid(ent) then return end
            local phys = ent:GetPhysicsObject()
            if IsValid(phys) then
                phys:EnableMotion(false)
                phys:Sleep()
            end
        end)
    end

    if s.no_collide_props then
        ent:SetCollisionGroup(COLLISION_GROUP_WORLD)
    end
end

hook.Add("PlayerSpawnedProp", "DAdminSafeZones_PropRules", applyEntityRules)
hook.Add("PlayerSpawnedRagdoll", "DAdminSafeZones_RagdollRules", applyEntityRules)
hook.Add("PlayerSpawnedEffect", "DAdminSafeZones_EffectRules", applyEntityRules)
hook.Add("PlayerSpawnedSENT", "DAdminSafeZones_SENTRules", applyEntityRules)
hook.Add("PlayerSpawnedVehicle", "DAdminSafeZones_VehicleRules", applyEntityRules)

hook.Add("PhysgunPickup", "DAdminSafeZones_PhysgunRules", function(ply, ent)
    if DAdmin.Security and DAdmin.Security.CanUseMenu and DAdmin.Security.CanUseMenu(ply) then return end
    if DAdmin.HasPermission and (DAdmin.HasPermission(ply, "safezones.manage") or DAdmin.HasPermission(ply, "physgun_freeze")) then return end
    local z = DAdmin.SafeZones.GetPlayerZone(ply)
    if z and (z.settings or {}).prevent_physgun then return false end
end)
