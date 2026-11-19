-- FERAL NOVA PRIME v28 / evidence-aware local mechanics, reversible leases
-- Disabled by default. Changes are reversible and server effects are NOT asserted.
-- Existing Endurance, HP/status recovery, escape, baby carry, ESP and climb modules own their states.
local Mechanics={}
local RS=game:GetService("ReplicatedStorage")
local Players=game:GetService("Players")
function Mechanics.attach(ctx)
    local M={
        alive=true,enabled={growth=false,carry=false,cooldown=false},
        profile=2,applied=0,status="Experimental mechanics OFF",
        featureApplied={growth=0,carry=0,cooldown=0},localLeaseOverwrites=0,
        lastFields={},
        localOnly=true,errors={},observed={},
    }
    local presets={
        {name="CONSERVATIVE",growth=2,carry=2,seconds=5},
        {name="BALANCED",growth=3,carry=3,seconds=1.5},
        {name="AGGRESSIVE",growth=6,carry=5,seconds=.5}
    }
    local original={}
    local cached={}
    local valid={growth=true,carry=true,cooldown=true}
    local function get(name)
        if cached[name] then return cached[name] end
        local world=RS:FindFirstChild("FeralWorld")
        local scriptNode=world and world:FindFirstChild(name)
        if not scriptNode or not scriptNode:IsA("ModuleScript") then
            M.errors[name]="module not found"
            return nil
        end
        local ok,value=pcall(require,scriptNode)
        if ok and type(value)=="table" then
            cached[name]=value
            M.errors[name]=nil
            return value
        end
        M.errors[name]=ok and "not a table" or tostring(value)
        return nil
    end
    local function lease(t,k,v)
        if type(t)~="table" or rawget(t,k)==nil or type(rawget(t,k))~=type(v) then return false end
        local previous=rawget(t,k)
        if previous==v then return false end
        local ok=pcall(function()t[k]=v end)
        if not ok or rawget(t,k)~=v then return false end
        original[#original+1]={t=t,k=k,previous=previous,wanted=v}
        return true
    end
    local function restore()
        for i=#original,1,-1 do
            local row=original[i]
            pcall(function()
                -- Do not overwrite a value subsequently changed by another controller.
                if rawget(row.t,row.k)==row.wanted then
                    row.t[row.k]=row.previous
                end
            end)
            original[i]=nil
        end
        M.applied=0
        M.featureApplied={growth=0,carry=0,cooldown=0}
        M.lastFields={}
    end
    local function recalc()
        if not M.alive then return false end
        restore()
        local p=presets[M.profile]
        local count=0
        local feature={growth=0,carry=0,cooldown=0}
        local changed={}
        local function change(t,k,v,which)
            if lease(t,k,v) then
                count+=1
                feature[which]+=1
                changed[#changed+1]=which.."."..k
            end
        end
        if M.enabled.growth then
            local species=get("Species")
            local growth=get("GrowthConfig")
            -- The public server can maintain Growth independently of these client inputs.
            local mins=species and species.ADULT_MINUTES
            if mins and type(mins.Eagle)=="number" then
                change(mins,"Eagle",math.max(.5,mins.Eagle/p.growth),"growth")
            elseif species and type(species.List)=="table" and type(species.List.Eagle)=="table" then
                local eagle=species.List.Eagle
                if type(eagle.growthMinutes)=="number" then
                    change(eagle,"growthMinutes",math.max(.5,eagle.growthMinutes/p.growth),"growth")
                end
            end
            if growth then
                if type(rawget(growth,"ELDER_RATE"))=="number" then change(growth,"ELDER_RATE",growth.ELDER_RATE*p.growth,"growth") end
                if type(rawget(growth,"CUB_BOOST"))=="number" then change(growth,"CUB_BOOST",math.max(growth.CUB_BOOST,p.growth),"growth") end
            end
        end
        if M.enabled.carry then
            local abilities=get("AbilityConfig")
            local talon=abilities and abilities.Talon
            if talon then
                change(talon,"CARRY_RATIO",p.carry,"carry")
                change(talon,"NO_ELDER_LIFT",false,"carry")
            end
        end
        if M.enabled.cooldown then
            local abilities=get("AbilityConfig")
            local talon=abilities and abilities.Talon
            if talon then
                for _,key in ipairs({"FLAT_COOLDOWN","COOLDOWN","MISS_COOLDOWN"}) do
                    if type(rawget(talon,key))=="number" then change(talon,key,p.seconds,"cooldown") end
                end
            end
            local flight=get("FlightConfig")
            local stoop=flight and flight.STOOP
            if stoop then
                for _,key in ipairs({"CD_PICK","CD_CANCEL","CD_EMPTY"}) do
                    if type(rawget(stoop,key))=="number" then change(stoop,key,p.seconds,"cooldown") end
                end
            end
        end
        M.applied=count
        M.featureApplied=feature
        M.lastFields=changed
        local enabledCount=(M.enabled.growth and 1 or 0)+(M.enabled.carry and 1 or 0)+(M.enabled.cooldown and 1 or 0)
        M.status=enabledCount==0 and "Experimental mechanics OFF"
            or (tostring(count).." local config fields changed; server effects unverified")
        return true
    end
    function M.setEnabled(feature,on)
        if not M.alive or not valid[feature] then return false end
        M.enabled[feature]=on==true
        return recalc()
    end
    function M.cyclePreset()
        if not M.alive then return nil end
        M.profile=M.profile%#presets+1
        recalc()
        return presets[M.profile]
    end
    function M.preset()
        return presets[M.profile]
    end
    function M.inspect()
        local intact=0
        local overwritten=0
        for _,row in ipairs(original) do
            if rawget(row.t,row.k)==row.wanted then intact+=1 else overwritten+=1 end
        end
        M.localLeaseOverwrites=overwritten
        return {intact=intact,overwritten=overwritten,
            features=M.featureApplied,fields=M.lastFields}
    end
    function M.report()
        local p=presets[M.profile]
        local inspection=M.inspect()
        local parts={
            "FERAL v25 EXPERIMENTAL MECHANICS / LOCAL CONFIG ONLY",
            "growth="..tostring(M.enabled.growth).." carry="..tostring(M.enabled.carry).." cooldown="..tostring(M.enabled.cooldown),
            "preset="..p.name.." growth_factor="..p.growth.." carry_ratio="..p.carry.." cooldown_seconds="..p.seconds,
            "locally_changed_fields="..M.applied,
            "local_fields_still_applied="..inspection.intact,
            "local_fields_overwritten="..inspection.overwritten,
            "growth_fields_changed="..M.featureApplied.growth,
            "carry_fields_changed="..M.featureApplied.carry,
            "cooldown_fields_changed="..M.featureApplied.cooldown,
            "changed_local_fields="..table.concat(M.lastFields,","),
            "NOTE=Any field marked applied is LOCAL ONLY, not a server-accepted mechanic.",
            "SERVER_GROWTH_ACCEPTANCE=UNVERIFIED",
            "SERVER_CARRY_ACCEPTANCE=UNVERIFIED",
            "SERVER_TALON_COOLDOWN_ACCEPTANCE=UNVERIFIED"
        }
        for name,err in pairs(M.errors) do parts[#parts+1]=name.."_error="..err end
        return table.concat(parts,"\n")
    end
    function M.close()
        if not M.alive then return end
        M.alive=false
        restore()
        M.enabled.growth=false
        M.enabled.carry=false
        M.enabled.cooldown=false
    end
    if type(ctx)=="table" then ctx.mechanics=M end
    return M
end
return Mechanics