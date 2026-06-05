if SERVER then return end
DAdmin = DAdmin or {}
DAdmin._skipNextRefresh = false
DAdmin._lastRefreshTime = 0

net.Receive("DAdmin_UIState", function()
    local len = net.ReadUInt(32)
    if not len or len <= 0 then return end
    local compressed = net.ReadData(len)
    if not compressed then return end
    local json = util.Decompress(compressed)
    if not json then return end
    local state = util.JSONToTable(json)
    if not state then return end
    if DAdmin.Port and DAdmin.Port.SetState then
        DAdmin.Port.SetState(state)
    end
    -- Skip refresh if a panel requested it (e.g. permissions toggle)
    if DAdmin._skipNextRefresh then
        DAdmin._skipNextRefresh = false
        return
    end
    -- Debounce: don't refresh more than once per 0.5s
    local now = SysTime()
    if now - DAdmin._lastRefreshTime < 0.5 then return end
    DAdmin._lastRefreshTime = now
    if IsValid(DAdmin.Frame) and DAdmin.RefreshCurrentTab then
        DAdmin.RefreshCurrentTab()
    end
end)

net.Receive("dadmin_open_menu", function()
    local defaultTab = net.ReadString()
    if DAdmin and DAdmin.OpenMenu then
        DAdmin.OpenMenu(defaultTab ~= "" and defaultTab or nil)
    end
end)
