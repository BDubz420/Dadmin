-- DAdmin Security / Production Hardening
-- Phase 6: net rate limiting, payload sanity, permission gates, and guarded execution.
if CLIENT then return end

DAdmin = DAdmin or {}
DAdmin.Security = DAdmin.Security or {}

DAdmin.Security.Rate = DAdmin.Security.Rate or {}
DAdmin.Security.DefaultWindow = 2
DAdmin.Security.DefaultBurst = 20
DAdmin.Security.MaxTableKeys = 128
DAdmin.Security.MaxStringLength = 512
DAdmin.Security.MaxDepth = 6

local function sid(ply)
    if IsValid(ply) and ply.SteamID then return ply:SteamID() end
    return "console"
end

function DAdmin.Security.RateLimit(ply, key, burst, window)
    if not IsValid(ply) then return true end
    key = tostring(key or "generic")
    burst = tonumber(burst or DAdmin.Security.DefaultBurst) or DAdmin.Security.DefaultBurst
    window = tonumber(window or DAdmin.Security.DefaultWindow) or DAdmin.Security.DefaultWindow

    local now = CurTime()
    local bucketKey = sid(ply) .. ":" .. key
    local bucket = DAdmin.Security.Rate[bucketKey]

    if not bucket or now > bucket.reset then
        DAdmin.Security.Rate[bucketKey] = { count = 1, reset = now + window }
        return true
    end

    bucket.count = bucket.count + 1
    if bucket.count > burst then
        return false
    end

    return true
end

function DAdmin.Security.IsSafeString(value, maxLen)
    return isstring(value) and #value <= (maxLen or DAdmin.Security.MaxStringLength)
end

function DAdmin.Security.SanitizeTable(value, depth, seen)
    if value == nil then return nil end

    local t = type(value)
    if t == "number" then return math.Clamp(value, -2147483648, 2147483647) end
    if t == "boolean" then return value end
    if t == "string" then
        value = string.sub(value, 1, DAdmin.Security.MaxStringLength)
        value = string.gsub(value, "%z", "")
        return value
    end
    if IsEntity and IsEntity(value) then
        return IsValid(value) and (value.SteamID and value:SteamID() or tostring(value)) or nil
    end
    if t ~= "table" then return nil end

    depth = (depth or 0) + 1
    if depth > DAdmin.Security.MaxDepth then return {} end

    seen = seen or {}
    if seen[value] then return {} end
    seen[value] = true

    local out = {}
    local n = 0
    for k, v in pairs(value) do
        n = n + 1
        if n > DAdmin.Security.MaxTableKeys then break end

        local kt = type(k)
        if kt == "string" or kt == "number" then
            local cleanKey = kt == "string" and string.sub(k, 1, 64) or k
            local cleanValue = DAdmin.Security.SanitizeTable(v, depth, seen)
            if cleanValue ~= nil then out[cleanKey] = cleanValue end
        end
    end

    seen[value] = nil
    return out
end

function DAdmin.Security.CanUseMenu(ply)
    return IsValid(ply) and (
        ply:IsAdmin()
        or ply:IsSuperAdmin()
        or (DAdmin.HasPermission and DAdmin.HasPermission(ply, "menu"))
        or (DAdmin.HasPermission and DAdmin.HasPermission(ply, "admin"))
    )
end

function DAdmin.Security.RequirePermission(ply, permission)
    if not permission or permission == "" then return true end
    return DAdmin.HasPermission and DAdmin.HasPermission(ply, permission)
end

function DAdmin.Security.CheckNet(ply, key, opts)
    opts = opts or {}
    if not IsValid(ply) then return false, "invalid player" end

    if opts.menu ~= false and not DAdmin.Security.CanUseMenu(ply) then
        return false, "no menu access"
    end

    if not DAdmin.Security.RateLimit(ply, key, opts.burst or 8, opts.window or 1) then
        -- Silently drop rate-limited UI/net spam. Admin workflows should feel instant;
        -- protection remains active without noisy chat feedback.
        return false, "rate limited"
    end

    if opts.permission and not DAdmin.Security.RequirePermission(ply, opts.permission) then
        return false, "permission denied"
    end

    return true
end

function DAdmin.Security.SafeCall(label, fn, ...)
    local args = {...}
    local ok, result = xpcall(function()
        return fn(unpack(args))
    end, debug.traceback)

    if not ok then
        ErrorNoHalt("[DAdmin] " .. tostring(label or "SafeCall") .. " failed:\n" .. tostring(result) .. "\n")
        return false, result
    end

    return true, result
end

hook.Add("PlayerDisconnected", "DAdmin.Security.CleanupRateLimit", function(ply)
    local id = sid(ply)
    for key in pairs(DAdmin.Security.Rate or {}) do
        if string.sub(key, 1, #id + 1) == id .. ":" then
            DAdmin.Security.Rate[key] = nil
        end
    end
end)
