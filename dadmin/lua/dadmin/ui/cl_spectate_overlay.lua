if SERVER then return end

DAdmin = DAdmin or {}
DAdmin.UI = DAdmin.UI or {}
DAdmin.Spectate = DAdmin.Spectate or {}

local UI = DAdmin.UI
local spec = DAdmin.Spectate

spec.active = false
spec.target = nil
spec.targetName = ""
spec.targetSteamID = ""
spec.startTime = 0

function DAdmin.Spectate.Start(targetPly)
    if not IsValid(targetPly) then return end
    spec.active = true
    spec.target = targetPly
    spec.targetName = targetPly:Nick()
    spec.targetSteamID = targetPly:SteamID()
    spec.startTime = CurTime()
end

function DAdmin.Spectate.Stop()
    spec.active = false
    spec.target = nil
    spec.targetName = ""
    spec.targetSteamID = ""
    spec.startTime = 0
end

function DAdmin.Spectate.IsActive()
    return spec.active and IsValid(spec.target)
end

local function formatDuration(seconds)
    seconds = math.floor(seconds)
    local m = math.floor(seconds / 60)
    local s = seconds % 60
    return string.format("%02d:%02d", m, s)
end

hook.Add("HUDPaint", "DAdmin_SpectateOverlay", function()
    if not DAdmin.Spectate.IsActive() then return end

    local C = UI.Colors
    local target = spec.target
    local w, h = ScrW(), ScrH()
    local elapsed = CurTime() - spec.startTime

    surface.SetDrawColor(0, 0, 0, 180)
    surface.DrawRect(0, 0, w, 36)

    surface.SetDrawColor(C.blue.r, C.blue.g, C.blue.b, 255)
    surface.DrawRect(0, 34, w, 2)

    draw.SimpleText("SPECTATING", "DAdmin.Title", 12, 18, C.red, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    draw.SimpleText(spec.targetName, "DAdmin.Normal", 108, 18, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    draw.SimpleText("(" .. spec.targetSteamID .. ")", "DAdmin.Small", 108 + surface.GetTextSize(spec.targetName) + 8, 18, C.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    draw.SimpleText(formatDuration(elapsed), "DAdmin.Mono", w - 12, 18, C.yellow, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

    if IsValid(target) then
        local hp = math.max(target:Health(), 0)
        local armor = math.max(target:Armor(), 0)

        surface.SetDrawColor(0, 0, 0, 180)
        surface.DrawRect(0, h - 52, w, 52)
        surface.SetDrawColor(C.blue.r, C.blue.g, C.blue.b, 255)
        surface.DrawRect(0, h - 52, w, 2)

        draw.SimpleText("Health: " .. tostring(hp), "DAdmin.Normal", 12, h - 38, hp > 30 and C.green or C.red, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Armor: " .. tostring(armor), "DAdmin.Normal", 12, h - 20, C.blue, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

        local barW = 200
        local barH = 6
        local barX = 120
        surface.SetDrawColor(C.bg3)
        surface.DrawRect(barX, h - 42, barW, barH)
        surface.SetDrawColor(hp > 30 and C.green or C.red)
        surface.DrawRect(barX, h - 42, math.Clamp(hp / 100, 0, 1) * barW, barH)

        surface.SetDrawColor(C.bg3)
        surface.DrawRect(barX, h - 24, barW, barH)
        surface.SetDrawColor(C.blue)
        surface.DrawRect(barX, h - 24, math.Clamp(armor / 100, 0, 1) * barW, barH)

        local weapon = target:GetActiveWeapon()
        local weaponName = IsValid(weapon) and (weapon:GetPrintName() or weapon:GetClass()) or "None"
        draw.SimpleText("Weapon: " .. weaponName, "DAdmin.Normal", 340, h - 38, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

        local pos = target:GetPos()
        draw.SimpleText(string.format("Pos: %.0f, %.0f, %.0f", pos.x, pos.y, pos.z), "DAdmin.Small", 340, h - 20, C.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

        local vel = math.floor(target:GetVelocity():Length())
        draw.SimpleText("Speed: " .. tostring(vel), "DAdmin.Normal", w - 12, h - 38, vel > 500 and C.red or C.text, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

        local ping = target:Ping()
        draw.SimpleText("Ping: " .. tostring(ping) .. "ms", "DAdmin.Small", w - 12, h - 20, ping > 100 and C.red or C.green, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end

    draw.SimpleText("Press F6 or type !unspectate to stop", "DAdmin.Small", w / 2, h - 60, Color(180, 180, 180, 180), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end)

hook.Add("PlayerBindPress", "DAdmin_SpectateStop", function(ply, bind, pressed)
    if not pressed then return end
    if DAdmin.Spectate.IsActive() and bind == "gm_showteam" then
        DAdmin.Port.UIAction("command", { command = "unspectate", args = {} })
        DAdmin.Spectate.Stop()
        return true
    end
end)

net.Receive("DAdmin_SpectateStart", function()
    local target = net.ReadEntity()
    if IsValid(target) then
        DAdmin.Spectate.Start(target)
    end
end)

net.Receive("DAdmin_SpectateStop", function()
    DAdmin.Spectate.Stop()
end)
