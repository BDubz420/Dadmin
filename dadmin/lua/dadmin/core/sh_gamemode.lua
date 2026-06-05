DAdmin = DAdmin or {}
DAdmin.Gamemode = DAdmin.Gamemode or {}

local PROFILES = {
    darkrp = {
        id = "darkrp",
        name = "DarkRP",
        family = "roleplay",
        features = {
            jobs = true, teams = true, money = true, salary = true, arrests = true,
            warrants = true, wanted = true, shipments = true, doors = true,
            ttt = false, sandbox = false
        },
        playerColumns = {
            { key = "name", label = "Name", width = 0.25 },
            { key = "rank", label = "Rank", width = 0.16 },
            { key = "job", label = "Job", width = 0.22 },
            { key = "wallet", label = "$", width = 0.09 },
            { key = "health", label = "HP", width = 0.08 },
            { key = "ping", label = "Ping", width = 0.09 },
            { key = "time", label = "Time", width = 0.11 },
        }
    },

    sandbox = {
        id = "sandbox",
        name = "Sandbox",
        family = "sandbox",
        features = {
            jobs = false, teams = false, money = false, salary = false, arrests = false,
            warrants = false, wanted = false, shipments = false, doors = false,
            ttt = false, sandbox = true, propTools = true, cleanup = true
        },
        playerColumns = {
            { key = "name", label = "Name", width = 0.32 },
            { key = "rank", label = "Rank", width = 0.20 },
            { key = "health", label = "HP", width = 0.12 },
            { key = "armor", label = "Armor", width = 0.12 },
            { key = "ping", label = "Ping", width = 0.12 },
            { key = "time", label = "Time", width = 0.12 },
        }
    },

    terrortown = {
        id = "terrortown",
        name = "Trouble in Terrorist Town",
        family = "ttt",
        aliases = { "ttt", "terrortown" },
        features = {
            jobs = false, teams = false, money = false, arrests = false,
            ttt = true, karma = true, rounds = true, sandbox = false
        },
        playerColumns = {
            { key = "name", label = "Name", width = 0.28 },
            { key = "rank", label = "Rank", width = 0.17 },
            { key = "role", label = "Role", width = 0.16 },
            { key = "karma", label = "Karma", width = 0.12 },
            { key = "health", label = "HP", width = 0.10 },
            { key = "ping", label = "Ping", width = 0.08 },
            { key = "time", label = "Time", width = 0.09 },
        }
    },

    murder = {
        id = "murder",
        name = "Murder",
        family = "murder",
        features = { jobs = false, teams = false, money = false, arrests = false, murder = true },
        playerColumns = {
            { key = "name", label = "Name", width = 0.34 },
            { key = "rank", label = "Rank", width = 0.20 },
            { key = "role", label = "Role", width = 0.16 },
            { key = "health", label = "HP", width = 0.10 },
            { key = "ping", label = "Ping", width = 0.10 },
            { key = "time", label = "Time", width = 0.10 },
        }
    },

    prophunt = {
        id = "prophunt",
        name = "Prop Hunt",
        family = "prophunt",
        aliases = { "prop_hunt", "prophunt", "ph" },
        features = { jobs = false, teams = true, money = false, arrests = false, propHunt = true },
        playerColumns = {
            { key = "name", label = "Name", width = 0.30 },
            { key = "rank", label = "Rank", width = 0.18 },
            { key = "team", label = "Team", width = 0.18 },
            { key = "health", label = "HP", width = 0.10 },
            { key = "ping", label = "Ping", width = 0.10 },
            { key = "time", label = "Time", width = 0.14 },
        }
    },

    cinema = {
        id = "cinema",
        name = "Cinema",
        family = "cinema",
        features = { jobs = false, teams = false, money = false, arrests = false, media = true },
        playerColumns = {
            { key = "name", label = "Name", width = 0.36 },
            { key = "rank", label = "Rank", width = 0.22 },
            { key = "health", label = "HP", width = 0.12 },
            { key = "ping", label = "Ping", width = 0.12 },
            { key = "time", label = "Time", width = 0.18 },
        }
    }
}

local function shallowCopy(t)
    local out = {}
    for k, v in pairs(t or {}) do
        out[k] = istable(v) and table.Copy(v) or v
    end
    return out
end

function DAdmin.Gamemode.GetID()
    local id = ""
    if engine and engine.ActiveGamemode then id = tostring(engine.ActiveGamemode() or "") end
    if id == "" and gmod and gmod.GetGamemode then
        local gm = gmod.GetGamemode()
        id = tostring((gm and (gm.FolderName or gm.Name)) or "")
    end
    return string.lower(id ~= "" and id or "sandbox")
end

local function matchProfile(id)
    id = string.lower(tostring(id or "sandbox"))
    if id == "darkrp" or DarkRP then return "darkrp" end
    if id == "sandbox" then return "sandbox" end
    if id == "terrortown" or id == "ttt" then return "terrortown" end
    for key, profile in pairs(PROFILES) do
        if key == id then return key end
        for _, alias in ipairs(profile.aliases or {}) do
            if string.find(id, string.lower(alias), 1, true) then return key end
        end
    end
    if string.find(id, "darkrp", 1, true) or DarkRP then return "darkrp" end
    if string.find(id, "murder", 1, true) then return "murder" end
    if string.find(id, "prop", 1, true) and string.find(id, "hunt", 1, true) then return "prophunt" end
    if string.find(id, "cinema", 1, true) then return "cinema" end
    return "sandbox"
end

function DAdmin.Gamemode.GetProfile()
    local rawID = DAdmin.Gamemode.GetID()
    local key = matchProfile(rawID)
    local profile = shallowCopy(PROFILES[key] or PROFILES.sandbox)
    profile.raw = rawID
    profile.detected = key
    profile.features = table.Copy(profile.features or {})
    profile.playerColumns = table.Copy(profile.playerColumns or PROFILES.sandbox.playerColumns)
    return profile
end

function DAdmin.Gamemode.HasFeature(feature)
    local p = DAdmin.Gamemode.GetProfile()
    return p.features and p.features[feature] == true
end

function DAdmin.Gamemode.GetPlayerColumns()
    return DAdmin.Gamemode.GetProfile().playerColumns or PROFILES.sandbox.playerColumns
end

function DAdmin.Gamemode.GetFeatureFlags()
    return DAdmin.Gamemode.GetProfile().features or {}
end
