-- DAdmin Core System
-- Phase 1: single source of truth + compatibility bridge for older DADMIN files.

DAdmin = DAdmin or {}
DADMIN = DADMIN or DAdmin

DAdmin.Version = DAdmin.Version or "phase1-core"
DAdmin.Commands = DAdmin.Commands or {}
DAdmin.CommandAliases = DAdmin.CommandAliases or {}
DAdmin.Permissions = DAdmin.Permissions or {}
DAdmin.PermissionCache = DAdmin.PermissionCache or {}
DAdmin.Ranks = DAdmin.Ranks or {}
DAdmin.Users = DAdmin.Users or {}
DAdmin.LoadedFiles = DAdmin.LoadedFiles or {}
DAdmin.Modules = DAdmin.Modules or {}

local function validPlayer(ply)
    return IsValid and IsValid(ply) and ply:IsPlayer()
end



function DAdmin.RegisterModule(name, data)
    if not isstring(name) or name == "" then return false end
    name = string.lower(name)
    data = istable(data) and data or {}
    data.name = name
    data.enabled = data.enabled ~= false
    DAdmin.Modules[name] = data
    if data.enabled and isfunction(data.Init) then
        local ok, err = pcall(data.Init, data)
        if not ok then
            ErrorNoHalt("[DAdmin] Module '" .. name .. "' Init failed: " .. tostring(err) .. "\n")
            data.enabled = false
            return false
        end
    end
    return true
end

function DAdmin.GetModule(name)
    return DAdmin.Modules and DAdmin.Modules[string.lower(tostring(name or ""))]
end

function DAdmin.SetModuleEnabled(name, enabled)
    local mod = DAdmin.GetModule(name)
    if not mod then return false end
    enabled = not not enabled
    if mod.enabled == enabled then return true end
    mod.enabled = enabled
    local fn = enabled and mod.Init or mod.Shutdown
    if isfunction(fn) then pcall(fn, mod) end
    return true
end

function DAdmin.SafeInclude(path)
    if DAdmin.LoadedFiles[path] then return true end
    if SERVER then AddCSLuaFile(path) end

    local ok, err = pcall(include, path)
    if not ok then
        ErrorNoHalt("[DAdmin] Failed to include " .. tostring(path) .. ": " .. tostring(err) .. "\n")
        return false
    end

    DAdmin.LoadedFiles[path] = true
    return true
end

if not DAdmin.Msg then
    function DAdmin.Msg(target, msg)
        print("[DAdmin] " .. tostring(msg or ""))
    end
end

function DAdmin.InvalidatePermissionCache(ply)
    if not ply then
        DAdmin.PermissionCache = {}
        return
    end

    local steamid = isstring(ply) and ply or (validPlayer(ply) and ply:SteamID())
    if steamid then DAdmin.PermissionCache[steamid] = nil end
end

function DAdmin.GetPlayerSteamID(plyOrSteamID)
    if isstring(plyOrSteamID) then return plyOrSteamID end
    if validPlayer(plyOrSteamID) then return plyOrSteamID:SteamID() end
    return nil
end

function DAdmin.IsConsole(ply)
    return not validPlayer(ply)
end

-- Compatibility layer for files still written against DADMIN.
DADMIN = DAdmin
DADMIN.Commands = DAdmin.Commands
DADMIN.Ranks = DAdmin.Ranks
DADMIN.Permissions = DAdmin.Permissions

function DADMIN:IsAdmin(ply)
    return DAdmin.HasPermission and DAdmin.HasPermission(ply, "admin")
end

function DADMIN:GetRank(ply)
    return DAdmin.GetPlayerRank and DAdmin.GetPlayerRank(ply)
end

function DADMIN:HasPermission(ply, permission)
    return DAdmin.HasPermission and DAdmin.HasPermission(ply, permission)
end
