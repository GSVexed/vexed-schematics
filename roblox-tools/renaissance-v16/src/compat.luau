-- Interface capabilities are separate from compiler-specific closure layouts.
-- 2415 evidence: Hippo/HUD/Needs programs identical to 2412; Wolf tryBite,
-- biteCooldown and toggleFeed instructions unchanged. See compatibility.json.
local Compat = {}
local layouts = {
    [2412]={wolfTiming=true,feedTiming=true,hippoFinish=true,hippoMovement=true,debugStamina=true},
    [2415]={wolfTiming=true,feedTiming=true,hippoFinish=true,hippoMovement=true,debugStamina=false},
}
function Compat.layout(version,name)
    return layouts[version]~=nil and layouts[version][name]==true
end
function Compat.known(version) return layouts[version]~=nil end
function Compat.has(b,name)
    local finite=b.Core.finite
    if name=="wolfTiming" or name=="feedTiming" or name=="hippoFinish" then
        return Compat.layout(game.PlaceVersion,name)
    elseif name=="debugStamina" then
        if Compat.layout(game.PlaceVersion,name) then return true end
        if game.PlaceVersion~=2415 or type(b.RunService.IsStudio)~="function" then return false end
        local ok,studio=pcall(b.RunService.IsStudio,b.RunService)
        return ok and studio==true
    elseif name=="biteCadence" then
        local s=b:config("Species")
        return type(s)=="table" and type(s.biteCooldown)=="function" and type(s.DEFAULT)=="string"
    elseif name=="coneBonus" then
        local c=b:config("CombatConfig")
        return type(c)=="table" and finite(c.CONE) and type(c.BITE_CONE_ADD)=="table"
            and type(c.coneFor)=="function"
    elseif name=="hippoMovement" then
        -- The movement owner independently checks scaled/List fields and the
        -- exact reversible SPEED_CAP before each lease. Only its arithmetic
        -- layout is versioned here; charging diagnostics need extra fields.
        return Compat.layout(game.PlaceVersion,"hippoMovement")
    elseif name=="hippoProfile" then
        local c=b:config("AbilityConfig") or b:config("AbilityConfigBase")
        local p=c and c.CrusherBite
        if type(p)~="table" then return false end
        for _,key in ipairs({"CHARGE_TIME","MULT_START","MULT_MAX","CURVE","OVERHOLD"}) do
            if not finite(p[key]) then return false end
        end
        if p.CHARGE_TIME<=0 or p.CHARGE_TIME>30 or p.MULT_START<0 or p.MULT_MAX<p.MULT_START
            or p.CURVE<=0 or p.CURVE>8 or p.OVERHOLD<0 or p.OVERHOLD>60 then return false end
        return true
    elseif name=="hudGait" then
        -- Each actual Frame/Cap/UIStroke relationship is validated by the painter.
        return Compat.known(game.PlaceVersion)
    end
    return false
end
return Compat
