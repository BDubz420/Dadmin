-- DAdmin Screengrab Client Handler
if SERVER then return end

DAdmin = DAdmin or {}

local MAX_CHUNK = 60000
local CHUNK_DELAY = 0.08

net.Receive("DAdmin.Screengrab", function()
    local requestor = net.ReadEntity()
    if DAdmin.ScreengrabBusy then return end
    DAdmin.ScreengrabBusy = true

    hook.Add("PostRender", "DAdmin_ScreengrabCapture", function()
        hook.Remove("PostRender", "DAdmin_ScreengrabCapture")

        local data = render.Capture({
            format = "jpeg",
            quality = 55,
            x = 0,
            y = 0,
            w = ScrW(),
            h = ScrH()
        })

        if not data or #data == 0 then
            DAdmin.ScreengrabBusy = false
            return
        end

        local totalLen = #data
        local chunks = math.ceil(totalLen / MAX_CHUNK)

        net.Start("DAdmin.ScreengrabMeta")
        net.WriteUInt(totalLen, 32)
        net.WriteUInt(chunks, 16)
        net.SendToServer()

        for i = 1, chunks do
            local startByte = (i - 1) * MAX_CHUNK + 1
            local endByte = math.min(i * MAX_CHUNK, totalLen)
            local chunk = string.sub(data, startByte, endByte)

            timer.Simple(CHUNK_DELAY * i, function()
                net.Start("DAdmin.ScreengrabChunk")
                net.WriteUInt(i, 16)
                net.WriteUInt(#chunk, 32)
                net.WriteData(chunk, #chunk)
                net.SendToServer()
                if i == chunks then
                    DAdmin.ScreengrabBusy = false
                end
            end)
        end
    end)
end)

net.Receive("DAdmin.ScreengrabNotify", function()
    local msg = net.ReadString()
    if DAdmin.Msg then
        chat.AddText(Color(74, 144, 217), "[DAdmin] ", color_white, msg)
    end
end)
