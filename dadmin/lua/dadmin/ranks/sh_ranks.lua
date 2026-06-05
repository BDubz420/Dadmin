-- Compatibility shim: the canonical rank system now lives in dadmin/core/sh_ranks.lua.
DAdmin = DAdmin or {}
DADMIN = DAdmin
DADMIN.Ranks = DAdmin.Ranks or {}

function DADMIN.Ranks:Get(ply)
    return DAdmin.GetPlayerRank and DAdmin.GetPlayerRank(ply) or (DAdmin.Ranks and DAdmin.Ranks.user)
end

if SERVER then
    function DADMIN.Ranks:Set(ply, rank)
        return DAdmin.SetUserRank and DAdmin.SetUserRank(ply, rank)
    end

    function DADMIN.Ranks:Load(ply)
        if IsValid(ply) then ply.DAdminRank = DAdmin.GetUserRank(ply) end
        return self:Get(ply)
    end

    function DADMIN.Ranks:Save(ply)
        if IsValid(ply) then return DAdmin.SaveUsers and DAdmin.SaveUsers() end
    end
end
