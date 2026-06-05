-- DAdmin Screengrab Command
if CLIENT then return end

DAdmin = DAdmin or {}
DAdmin.Screengrabs = DAdmin.Screengrabs or {}

local function feedback(admin, msg, symbol)
    symbol = symbol or ""
    if IsValid(admin) then DAdmin.Msg(admin, symbol .. " " .. msg) else print("[DAdmin] " .. symbol .. " " .. msg) end
end

util.AddNetworkString("DAdmin.Screengrab")
util.AddNetworkString("DAdmin.ScreengrabMeta")
util.AddNetworkString("DAdmin.ScreengrabChunk")
util.AddNetworkString("DAdmin.ScreengrabNotify")
util.AddNetworkString("DAdmin.ScreengrabResult")

local pendingGrabs = {}

DAdmin.RegisterCommand("screengrab", {
    permission = "screengrab",
    description = "Capture a screenshot from a player",
    category = "Moderation",
    args = {
        { name = "target", type = "player" }
    },
    run = function(admin, targets)
        for _, ply in ipairs(targets) do
            pendingGrabs[ply:SteamID()] = {
                requestor = admin,
                target = ply,
                chunks = {},
                expectedChunks = 0,
                totalSize = 0,
                startTime = CurTime()
            }
            net.Start("DAdmin.Screengrab")
            net.WriteEntity(admin)
            net.Send(ply)
            feedback(admin, "Screengrab requested from " .. ply:Nick())
            DAdmin.Log("screengrab", admin, ply)
        end
    end
})

net.Receive("DAdmin.ScreengrabMeta", function(_, ply)
    if not IsValid(ply) then return end
    local sid = ply:SteamID()
    local grab = pendingGrabs[sid]
    if not grab then return end

    grab.totalSize = net.ReadUInt(32)
    grab.expectedChunks = net.ReadUInt(16)

    if IsValid(grab.requestor) then
        feedback(grab.requestor, "Receiving screenshot from " .. ply:Nick() .. " (" .. tostring(grab.expectedChunks) .. " chunks)")
    end
end)

net.Receive("DAdmin.ScreengrabChunk", function(_, ply)
    if not IsValid(ply) then return end
    local sid = ply:SteamID()
    local grab = pendingGrabs[sid]
    if not grab then return end

    local index = net.ReadUInt(16)
    local len = net.ReadUInt(32)
    local data = net.ReadData(len)

    grab.chunks[index] = data

    local received = 0
    for _ in pairs(grab.chunks) do received = received + 1 end

    if received >= grab.expectedChunks then
        local parts = {}
        for i = 1, grab.expectedChunks do
            parts[#parts + 1] = grab.chunks[i] or ""
        end
        local fullData = table.concat(parts)

        local fileName = "dadmin/screengrabs/" .. sid:gsub(":", "_") .. "_" .. tostring(os.time()) .. ".jpg"
        file.CreateDir("dadmin/screengrabs")
        file.Write(fileName, fullData)

        DAdmin.Screengrabs[sid] = DAdmin.Screengrabs[sid] or {}
        table.insert(DAdmin.Screengrabs[sid], 1, {
            file = fileName,
            time = os.date("%Y-%m-%d %H:%M:%S"),
            timestamp = os.time(),
            size = #fullData
        })

        if IsValid(grab.requestor) then
            feedback(grab.requestor, "Screenshot saved from " .. ply:Nick() .. " (" .. tostring(#fullData) .. " bytes)")

            net.Start("DAdmin.ScreengrabResult")
            net.WriteString(fileName)
            net.WriteString(ply:Nick())
            net.WriteString(sid)
            net.Send(grab.requestor)
        end

        pendingGrabs[sid] = nil
    end
end)

timer.Create("DAdmin_ScreengrabCleanup", 30, 0, function()
    local now = CurTime()
    for sid, grab in pairs(pendingGrabs) do
        if now - grab.startTime > 30 then
            if IsValid(grab.requestor) then
                feedback(grab.requestor, "Screengrab timed out for " .. (IsValid(grab.target) and grab.target:Nick() or sid))
            end
            pendingGrabs[sid] = nil
        end
    end
end)
