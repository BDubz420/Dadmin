DAdmin = DAdmin or {}
DAdmin.Boot = DAdmin.Boot or {}

local prefix = "[DAdmin] "

local function printLine(msg)
    MsgC(Color(0,200,255), prefix, Color(255,255,255), msg .. "\n")
end

function DAdmin.Boot.Start(title)

    MsgC(Color(0,200,255),
[[

==============================
        DADMIN SYSTEM
==============================

]])

    printLine("Boot sequence started")

end


function DAdmin.Boot.Section(name)
    MsgC(Color(0,200,255), "\n[DAdmin] ", Color(180,180,180), name .. "\n")
end


function DAdmin.Boot.Success(msg)
    MsgC(Color(0,200,255), prefix, Color(120,255,120), "✓ ", Color(255,255,255), msg .. "\n")
end


function DAdmin.Boot.Warn(msg)
    MsgC(Color(0,200,255), prefix, Color(255,200,0), "⚠ ", Color(255,255,255), msg .. "\n")
end


function DAdmin.Boot.Error(msg)
    MsgC(Color(0,200,255), prefix, Color(255,80,80), "✖ ", Color(255,255,255), msg .. "\n")
end


function DAdmin.Boot.Finish(commandCount, moduleCount)

    MsgC(Color(0,200,255), "\n[DAdmin] ", Color(120,255,120), "SYSTEM READY\n")

    if commandCount then
        printLine("Loaded " .. commandCount .. " commands")
    end

    if moduleCount then
        printLine("Loaded " .. moduleCount .. " modules")
    end

end