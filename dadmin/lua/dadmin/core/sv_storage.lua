-- DAdmin Persistence System
-- Phase 5: versioned JSON persistence, backups, migration helpers, and maintenance.
if CLIENT then return end

DAdmin = DAdmin or {}
DAdmin.Storage = DAdmin.Storage or {}

DAdmin.Storage.Root = "dadmin"
DAdmin.Storage.SchemaVersion = 5
DAdmin.Storage.DataSets = DAdmin.Storage.DataSets or {}
DAdmin.Storage.LastErrors = DAdmin.Storage.LastErrors or {}

file.CreateDir(DAdmin.Storage.Root)
file.CreateDir(DAdmin.Storage.Root .. "/backups")

local function pathFor(fileName)
    fileName = tostring(fileName or "")
    return DAdmin.Storage.Root .. "/" .. fileName
end

local function backupPath(fileName)
    return DAdmin.Storage.Root .. "/backups/" .. string.Replace(tostring(fileName or "data.json"), "/", "_") .. ".bak"
end

local function isJsonScalar(v)
    local t = type(v)
    return t == "nil" or t == "boolean" or t == "number" or t == "string"
end

local function cleanForJson(value, seen)
    if isJsonScalar(value) then return value end
    if IsEntity and IsEntity(value) then return IsValid(value) and (value.SteamID and value:SteamID() or tostring(value)) or nil end
    if isvector and isvector(value) then return { x = value.x, y = value.y, z = value.z, __type = "Vector" } end
    if isangle and isangle(value) then return { p = value.p, y = value.y, r = value.r, __type = "Angle" } end
    if not istable(value) then return nil end

    seen = seen or {}
    if seen[value] then return nil end
    seen[value] = true

    local out = {}
    for k, v in pairs(value) do
        if not isfunction(v) then
            local ck = isJsonScalar(k) and k or tostring(k)
            local cv = cleanForJson(v, seen)
            if cv ~= nil then out[ck] = cv end
        end
    end
    seen[value] = nil
    return out
end

function DAdmin.Storage.Clean(data)
    return cleanForJson(data or {})
end

function DAdmin.Storage.Save(fileName, data)
    if not fileName then return false, "missing file name" end

    local fullPath = pathFor(fileName)
    if file.Exists(fullPath, "DATA") then
        local old = file.Read(fullPath, "DATA") or ""
        file.Write(backupPath(fileName), old)
    end

    local payload = {
        __dadmin = true,
        schema = DAdmin.Storage.SchemaVersion,
        savedAt = os.time(),
        data = cleanForJson(data or {})
    }

    local ok, json = pcall(util.TableToJSON, payload, true)
    if not ok or not json then
        local err = "failed to encode " .. tostring(fileName)
        DAdmin.Storage.LastErrors[fileName] = err
        ErrorNoHalt("[DAdmin] " .. err .. "\n")
        return false, err
    end

    file.Write(fullPath, json)
    return true
end

function DAdmin.Storage.Load(fileName, default)
    default = default or {}
    local fullPath = pathFor(fileName)
    if not file.Exists(fullPath, "DATA") then return table.Copy(default) end

    local raw = file.Read(fullPath, "DATA")
    local data = raw and util.JSONToTable(raw)

    if not data then
        local bak = backupPath(fileName)
        if file.Exists(bak, "DATA") then
            data = util.JSONToTable(file.Read(bak, "DATA") or "")
            if data then ErrorNoHalt("[DAdmin] Restored " .. tostring(fileName) .. " from backup.\n") end
        end
    end

    if not data then
        DAdmin.Storage.LastErrors[fileName] = "failed to decode"
        return table.Copy(default)
    end

    -- Phase 5 wrapper support; old Phase 4 files are raw tables.
    if istable(data) and data.__dadmin == true then
        return istable(data.data) and data.data or table.Copy(default)
    end

    return istable(data) and data or table.Copy(default)
end

function DAdmin.Storage.RegisterDataSet(name, fileName, getter, setter, default, opts)
    DAdmin.Storage.DataSets[name] = {
        fileName = fileName,
        getter = getter,
        setter = setter,
        default = default or {},
        opts = opts or {}
    }
end

function DAdmin.Storage.LoadDataSet(name)
    local ds = DAdmin.Storage.DataSets[name]
    if not ds then return false end
    local data = DAdmin.Storage.Load(ds.fileName, ds.default)
    if isfunction(ds.setter) then ds.setter(data) end
    return data
end

function DAdmin.Storage.SaveDataSet(name)
    local ds = DAdmin.Storage.DataSets[name]
    if not ds or not isfunction(ds.getter) then return false end
    return DAdmin.Storage.Save(ds.fileName, ds.getter() or {})
end

function DAdmin.Storage.PruneList(list, max)
    max = tonumber(max or 0) or 0
    if max <= 0 or not istable(list) then return 0 end
    local removed = 0
    while #list > max do
        table.remove(list)
        removed = removed + 1
    end
    return removed
end

function DAdmin.Storage.Maintenance()
    local removed = 0

    if DAdmin.Logs then removed = removed + DAdmin.Storage.PruneList(DAdmin.Logs, 1500) end

    if DAdmin.History and DAdmin.History.Prune then
        removed = removed + (DAdmin.History.Prune() or 0)
    end

    if DAdmin.Cases and DAdmin.Cases.Prune then
        removed = removed + (DAdmin.Cases.Prune() or 0)
    end

    if DAdmin.Punishments and DAdmin.Punishments.PruneExpired then
        DAdmin.Punishments.PruneExpired()
    end

    return removed
end

-- Legacy compatibility helpers used by older files.
function DAdmin.LoadRanks()
    DAdmin.Ranks = DAdmin.Storage.Load("ranks.json", DAdmin.Ranks or {}) or {}
    return DAdmin.Ranks
end

function DAdmin.SaveRanks()
    return DAdmin.Storage.Save("ranks.json", DAdmin.Ranks or {})
end

function DAdmin.LoadUsers()
    DAdmin.Users = DAdmin.Storage.Load("users.json", DAdmin.Users or {}) or {}
    return DAdmin.Users
end

function DAdmin.SaveUsers()
    return DAdmin.Storage.Save("users.json", DAdmin.Users or {})
end

function DAdmin.LoadBans()
    DAdmin.Bans = DAdmin.Storage.Load("bans.json", DAdmin.Bans or {}) or {}
    return DAdmin.Bans
end

function DAdmin.SaveBans()
    return DAdmin.Storage.Save("bans.json", DAdmin.Bans or {})
end

function DAdmin.LoadLogs()
    DAdmin.Logs = DAdmin.Storage.Load("logs.json", DAdmin.Logs or {}) or {}
    return DAdmin.Logs
end

function DAdmin.SaveLogs()
    return DAdmin.Storage.Save("logs.json", DAdmin.Logs or {})
end

DAdmin.LoadRanks()
DAdmin.LoadUsers()
DAdmin.LoadBans()
DAdmin.LoadLogs()


local function attachStorageMethods()
    DAdmin.Ranks = DAdmin.Ranks or {}
    DAdmin.Ranks.Save = function() return DAdmin.SaveRanks() end
    DAdmin.Ranks.Load = function() return DAdmin.LoadRanks() end

    DAdmin.Users = DAdmin.Users or {}
    DAdmin.Users.Save = function() return DAdmin.SaveUsers() end
    DAdmin.Users.Load = function() return DAdmin.LoadUsers() end

    DAdmin.Logs = DAdmin.Logs or {}
    DAdmin.Logs.Load = function() return DAdmin.LoadLogs() end
end

attachStorageMethods()

timer.Create("DAdmin_StorageMaintenance", 300, 0, function()
    if DAdmin.Storage then DAdmin.Storage.Maintenance() end
end)

concommand.Add("dadmin_storage_maintenance", function(ply)
    if IsValid(ply) and DAdmin.HasPermission and not DAdmin.HasPermission(ply, "admin") then return end
    local removed = DAdmin.Storage.Maintenance()
    if IsValid(ply) and DAdmin.Msg then DAdmin.Msg(ply, "Storage maintenance complete. Removed " .. tostring(removed) .. " old entries.") end
end)
