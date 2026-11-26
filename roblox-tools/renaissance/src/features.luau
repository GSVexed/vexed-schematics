-- Every shared client-config mutation goes through one lease manager.
local Features = {}
-- Native tables can alias the same consumption profile in several paths.
-- Coalesce equal intents before the strict lease manager reserves a field.
-- Conflicting values remain an error; never silently choose the last value.
function Features.uniquePlan(plan)
    local result,seen={},{}
    for _,item in ipairs(plan) do
        if type(item.target)~="table" or item.key==nil then return nil,"invalid stamina field" end
        local fields=seen[item.target]
        if not fields then fields={};seen[item.target]=fields end
        local previous=fields[item.key]
        if previous then
            if previous.value~=item.value or previous.kind~=item.kind then
                return nil,"conflicting aliased stamina field: "..tostring(item.key)
            end
        else
            fields[item.key]=item;table.insert(result,item)
        end
    end
    return result
end
function Features.new(Core, bridge, registry)
    local f = { leases = Core.leases(), originalCombat = nil, combat = nil, flag = nil,
        nextReconcile = 0, configIdentity = {}, failures = {} }
    local function entry(target, key, value, kind)
        return { target = target, key = key, value = value, kind = kind }
    end
    local function numeric(t, keys)
        if type(t) ~= "table" then return false end
        for _, key in ipairs(keys) do if not Core.finite(t[key]) then return false end end
        return true
    end
    function f:releaseFlag()
        local flag = self.flag
        self.flag = nil
        if flag then bridge:restoreAttribute(flag.char, "WolfDbgNoStamina", true, flag.before) end
    end
    function f:flagCharacter(s, on)
        if self.flag and (not on or self.flag.char ~= s.char) then self:releaseFlag() end
        if on and s.alive then
            if not self.flag then
                self.flag = { char = s.char, before = bridge:attribute(s.char, "WolfDbgNoStamina") }
            end
            return bridge:setAttribute(s.char, "WolfDbgNoStamina", true)
        end
        return not on
    end
    function f:plan(id)
        local n = bridge:config("NeedsConfig")
        if id == "reach" then
            local c = bridge:config("CombatConfig")
            if not numeric(c, { "REACH", "HIT_SCALE", "CONE", "SLACK", "MAX_DY" })
                or type(c.bodyGap) ~= "function" then return nil, "CombatConfig schema unavailable" end
            local original = {}
            for k, v in pairs(c) do original[k] = v end
            -- Keep stock-reference hints conservative even if a native helper
            -- closes over the shared config table that we are about to tune.
            if type(c.coneFor) == "function" then
                local stock = c.coneFor
                original.coneFor = function(char)
                    local ok,value = pcall(stock,char)
                    return ok and Core.finite(value) and math.min(value,original.CONE) or original.CONE
                end
            end
            self.originalCombat, self.combat = original, c
            local nativeCone = c.coneFor
            local desiredCone = math.max(c.CONE,170)
            local plan = {
                entry(c,"REACH",math.min(c.REACH*1.50,3.2),"number"),
                entry(c,"HIT_SCALE",math.min(c.HIT_SCALE*1.30,2.1),"number"),
                entry(c,"CONE",desiredCone,"number"),
                entry(c,"SLACK",c.SLACK+.75,"number"),
                entry(c,"MAX_DY",math.min(c.MAX_DY*1.50,4.5),"number"),
                entry(c,"bodyGap",function(part,flat)
                    local char = part and part.Parent
                    if char and not bridge:combatEligible(char) then return math.huge end
                    local gap = original.bodyGap(part,flat)
                    return Core.finite(gap) and gap-.90 or gap
                end,"function"),
            }
            -- FeralBiteLocal is predictive presentation, not a hit acknowledgement.
            -- Preserve the native FeralHit response effects; remove premature impacts.
            if type(c.HIT2) == "table" and type(c.HIT2.PREDICT) == "boolean" then
                table.insert(plan,entry(c.HIT2,"PREDICT",false,"boolean"))
            end
            table.insert(plan,entry(c,"coneFor",function(char)
                local value = desiredCone
                if type(nativeCone) == "function" then
                    local ok,native = pcall(nativeCone,char)
                    if ok and Core.finite(native) then value = math.max(value,native) end
                end
                return value
            end))
            -- A single candidate selected from the shared snapshot feeds both
            -- climb aim and the guide; no extra tree scan or hit request.
            table.insert(plan, entry(c,"biteLook",function(char, forward)
                local native = forward
                if type(original.biteLook) == "function" then
                    local ok,value = pcall(original.biteLook,char,forward)
                    if ok and typeof(value) == "Vector3" then native = value end
                end
                local target = bridge.reachTarget
                local root = char and char:FindFirstChild("HumanoidRootPart")
                if target and target.char and target.char.Parent and target.root.Parent and root
                    and bridge:combatEligible(target.char) then
                    local diff = target.root.Position-root.Position
                    if bridge.predictionActive and char==bridge.player.Character then
                        diff=bridge:leadPoint({char=char,root=root},target)-root.Position
                    end
                    local flat = Vector3.new(diff.X,0,diff.Z)
                    local look = Vector3.new(native.X,0,native.Z)
                    if diff.Magnitude <= 45 and flat.Magnitude > .05
                        and (bridge.predictionActive or target.sameTree or look.Magnitude < .01 or look.Unit:Dot(flat.Unit) < .3) then
                        return flat.Unit
                    end
                end
                return native
            end))
            table.insert(plan, entry(c,"dyMult",function(char)
                local native = 1
                if type(original.dyMult) == "function" then
                    local ok,value = pcall(original.dyMult,char)
                    if ok and Core.finite(value) and value > 0 then native = value end
                end
                if bridge:isClimbing(char) and bridge.treeTarget and bridge.treeTarget.sameTree then
                    return math.min(native*2.50,3.5)
                end
                return native*1.35
            end))
            return plan
        elseif id == "stamina" then
            if not numeric(n, { "STAMINA_REGEN", "STAMINA_REGEN_DELAY", "STAMINA_SPRINT_DRAIN",
                "STAMINA_JUMP_COST", "STAMINA_LOW_NEEDS" }) then return nil, "NeedsConfig stamina schema unavailable" end
            local plan = {
                entry(n,"STAMINA_REGEN",n.STAMINA_REGEN*3,"number"),
                entry(n,"STAMINA_REGEN_DELAY",0,"number"),
                entry(n,"STAMINA_SPRINT_DRAIN",0,"number"),
                entry(n,"STAMINA_JUMP_COST",0,"number"),
                entry(n,"STAMINA_LOW_NEEDS",1,"number"),
            }
            local flight = bridge:config("FlightConfig")
            if numeric(flight, { "FLAP_DRAIN" }) then table.insert(plan,entry(flight,"FLAP_DRAIN",0,"number")) end
            -- v2412 WolfController has distinct swim, climb and venom paths.
            -- Change only recognised consumption inputs; preserve native
            -- species abilities, immunity, resource values and damage rules.
            local function zero(t,key)
                if type(t)=="table" and Core.finite(t[key]) and t[key]>=0 then
                    table.insert(plan,entry(t,key,0,"number"))
                end
            end
            zero(n,"SWIM_DRAIN_MULT");zero(n,"WATER_DRAIN_NONSWIM")
            -- v2412 NeedsConfig.BURST has its own finite DRAIN scalar.
            -- Keep native start eligibility, speed, animation and stamina values.
            zero(n.BURST,"DRAIN")
            local passive=bridge:config("PassiveConfig")
            local climber=passive and passive.CLIMBER
            if type(climber)=="table" then
                for level=1,3 do
                    local profile=type(climber.levels)=="table" and climber.levels[level]
                    if type(profile)=="table" then
                        zero(profile,"drain")
                        if profile.stamina=="drain" then table.insert(plan,entry(profile,"stamina","walk","string")) end
                    end
                end
                if type(climber.CLIMB_SPRINT)=="table" then
                    for species,profile in pairs(climber.CLIMB_SPRINT) do
                        if type(species)=="string" then zero(profile,"DRAIN") end
                    end
                end
            end
            local venom=bridge:config("VenomConfig")
            for _,key in ipairs({"SPRINT_DRAIN","OTHER_DRAIN","BITE_DRAIN"}) do zero(venom,key) end
            local status=bridge:config("StatusConfig")
            for _,key in ipairs({"STAMINA_BASE","STAMINA_PER_POINT"}) do zero(status and status.VENOM,key) end
            return Features.uniquePlan(plan)
        elseif id == "attackSpeed" then
            local species=bridge:config("Species")
            if game.PlaceVersion~=2412 or type(species)~="table" or type(species.biteCooldown)~="function" then
                return nil,"compatible native bite cadence unavailable"
            end
            local original=species.biteCooldown
            local wrapper=function(name,growth,...)
                local value=original(name,growth,...)
                local char=bridge.player.Character
                if not char or not char.Parent or game.PlaceVersion~=2412
                    or name~=(bridge:attribute(char,"Species") or species.DEFAULT)
                    or not Core.finite(value) or value<=0 or value>30 then return value end
                -- Keep delayed claims ordered; never slow an already faster
                -- native profile. The server may enforce its original cadence.
                local adaptive=bridge.combatGovernor and bridge.combatGovernor:factor() or .62
                -- Never drive contact claims faster than the game's native
                -- contact delay. Raise the interval after repeated clean
                -- no-damage contacts, lower it only on confirmed replies.
                return math.min(value,math.max(value*adaptive,bridge:biteDelay(char)+.055,.08))
            end
            return {entry(species,"biteCooldown",wrapper,"function")}
        elseif id == "recovery" then
            if not numeric(n, { "HEALTH_REGEN", "HEALTH_REST_MULT" }) then return nil, "NeedsConfig recovery schema unavailable" end
            if n.HEALTH_REST_MULT < 1 then return nil,"native HP Rest multiplier unavailable" end
            -- Keep the game's real Rest factor. Flattening it to one removed
            -- the distinction between an actual Rest window and a local edit.
            -- Cap only the local Rest reference at 2x; never edit combat exclusion.
            return { entry(n,"HEALTH_REGEN",n.HEALTH_REGEN*math.min(1,2/n.HEALTH_REST_MULT),"number"),
                entry(n,"HEALTH_REST_MULT",n.HEALTH_REST_MULT,"number") }
        elseif id == "effects" then
            local status = bridge:config("StatusConfig")
            local plan = {}
            for _, pair in ipairs({ {"INJURY","HEAL"}, {"BLEED","CLOT"}, {"VENOM","FADE"} }) do
                local c = status and status[pair[1]]
                if not numeric(c,{pair[2],"REST_MULT"}) or c[pair[2]] <= 0 then
                    return nil, "StatusConfig " .. pair[1] .. " schema unavailable"
                end
                if c.REST_MULT < 1 then return nil,"native condition Rest multiplier unavailable" end
                -- Preserve native Rest=4 and ordinary base decay. Never
                -- advertise a faster HUD calculation as a gameplay cure.
                table.insert(plan,entry(c,pair[2],c[pair[2]]*math.min(1,4/c.REST_MULT),"number"))
                table.insert(plan,entry(c,"REST_MULT",c.REST_MULT,"number"))
            end
            return plan
        elseif id == "mobility" then
            local status = bridge:config("StatusConfig")
            if not numeric(n,{"HURT_SLOW"}) or not numeric(status and status.INJURY,{"SLOW_PER_POINT"}) then
                return nil, "movement slowdown schema unavailable"
            end
            return { entry(n,"HURT_SLOW",0,"number"), entry(status.INJURY,"SLOW_PER_POINT",0,"number") }
        elseif id == "speed" then
            if not numeric(n,{"RUN_SPEED","SWIM_SPEED"}) or n.RUN_SPEED <= 0 or n.RUN_SPEED > 4
                or n.SWIM_SPEED <= 0 or n.SWIM_SPEED > 4 then return nil, "speed schema unavailable" end
            return { entry(n,"RUN_SPEED",n.RUN_SPEED*1.15,"number"), entry(n,"SWIM_SPEED",n.SWIM_SPEED*1.15,"number") }
        elseif id == "leap" then
            local c = bridge:config("JumpLeapConfig")
            if not numeric(c,{"DEFAULT","MAX_RUN_SHARE"}) or c.ON ~= true or type(c.BODY_LENGTHS) ~= "table" then
                return nil, "leap schema unavailable"
            end
            local plan = { entry(c,"DEFAULT",c.DEFAULT*1.15,"number"),
                entry(c,"MAX_RUN_SHARE",c.MAX_RUN_SHARE*1.15,"number") }
            for name, value in pairs(c.BODY_LENGTHS) do
                if Core.finite(value) and value >= 0 and value <= 10 then
                    table.insert(plan,entry(c.BODY_LENGTHS,name,value*1.15,"number"))
                end
            end
            return plan
        elseif id == "climb" then
            local passive = bridge:config("PassiveConfig")
            local c = passive and passive.CLIMBER
            if not numeric(c,{"GRAB_REACH","E_REACH","GRAB_FACING","MOUNT_TIME"}) or type(c.levels) ~= "table" then
                return nil, "climb schema unavailable"
            end
            local plan = {
                entry(c,"GRAB_REACH",math.min(1.25,c.GRAB_REACH*1.3),"number"),
                entry(c,"E_REACH",math.min(2.1,c.E_REACH*1.25),"number"),
                entry(c,"GRAB_FACING",math.max(.25,c.GRAB_FACING*.58),"number"),
                entry(c,"MOUNT_TIME",math.max(.22,c.MOUNT_TIME*.75),"number"),
            }
            for _, level in ipairs({1,2}) do
                if type(c.levels[level]) == "table" then table.insert(plan,entry(c.levels[level],"sprintGrab",true)) end
            end
            return plan
        end
        return nil, "unknown config feature"
    end
    -- Captured v2412 WolfMove forces its run boolean off while CrushAt is
    -- active (186:2394-2402), then uses 16.8 / 42 * scaled(gait) * walkMul.
    -- SPEED_CAP is not consumed by that branch. Adapt its actual scalar input
    -- to the requested native tier, preserving the native ability/guard state.
    function f:hippoInput(s,key)
        if not s.alive or s.species~="Hippo" or s.chat or s.gameMenu or s.captured or s.rest then return end
        if key==Enum.KeyCode.X then
            if self.hippoIntentChar~=s.char then self.hippoBurstIntent=s.burst==true end
            self.hippoIntentChar=s.char;self.hippoBurstIntent=not self.hippoBurstIntent
        elseif key==Enum.KeyCode.Z then
            self.hippoIntentChar=s.char;self.hippoBurstIntent=false
        end
    end
    function f:hippoAttribute(s)
        if s.species~="Hippo" then self.hippoIntentChar,self.hippoBurstIntent=nil,nil;return end
        local at=bridge:attribute(s.char,"FeralCrushAt")
        if at~=nil and at~=false then
            if self.hippoIntentChar~=s.char or self.hippoBurstIntent==nil then
                self.hippoIntentChar=s.char;self.hippoBurstIntent=s.burst==true
            end
            self.hippoCharge=at
        else self.hippoCharge=nil;self.hippoBurstIntent=nil end
    end
    -- One decision drives both the charge-speed calculation and the native
    -- HUD presentation. Never change WolfController's gait or Burst flags.
    function f:hippoTier(char,field,hippo,needs)
        if bridge.player.Character~=char or not char or not char.Parent
            or bridge:attribute(char,"Species")~="Hippo" or game.PlaceVersion~=2412 then return nil end
        local charge=bridge:attribute(char,"FeralCrushAt")
        if charge==nil or charge==false or bridge:attribute(char,"WolfRest")==true
            or bridge:attribute(char,"FeralCrouch")==true
            or bridge:attribute(char,"FeralPinned")==true or bridge:attribute(char,"FeralCarried")==true
            or bridge:attribute(char,"FeralDragged")==true or bridge.UserInputService:GetFocusedTextBox()
            or bridge:attribute(bridge.player,"FeralMenuOpen")==true then return nil end
        local combat=bridge:config("CombatConfig")
        if combat and type(combat.hobbled)=="function" then
            local ok,hobbled=pcall(combat.hobbled,char)
            if not ok or hobbled then return nil end
        end
        local shift=false
        pcall(function()shift=bridge.UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)end)
        local burst=self.hippoIntentChar==char and self.hippoBurstIntent==true
        local denial=bridge:attribute(bridge.player,"HudBurstNo")
        if denial==true or Core.finite(denial) and bridge.clock()>=denial and bridge.clock()-denial<1.7
            or bridge:attribute(char,"StaminaOut")==true then burst=false;self.hippoBurstIntent=false end
        if not shift and not burst then return nil end
        local multiplier=1
        if burst then
            local boost=needs and needs.BURST
            local key=field=="swimSpeed" and "SWIM_SPEED" or "SPEED"
            local n=boost and (boost[key] or boost.SPEED)
            if not boost or boost.ENABLED~=true or not Core.finite(n) or n<1 or n>3 then
                if not shift then return nil end
                burst=false
            else multiplier=n end
        end
        if field=="swimSpeed" then
            if not Core.finite(hippo.swimSprint) or hippo.swimSprint<=0 then return nil end
        elseif not Core.finite(needs and needs.RUN_SPEED) or needs.RUN_SPEED<=0
            or not Core.finite(hippo.speed) then return nil end
        return burst and "burst" or "sprint",multiplier
    end
    function f:paintHippoGait()
        local record=self.hippoScaled
        local char=bridge.player.Character
        local tier
        if registry.byId.hippoMove.requested and record and record.char==char
            and self.leases:valid("hippoGait") and char and char.Parent then
            local field=bridge:attribute(char,"FeralSwimLocal")==true and "swimSpeed" or "gait"
            tier=self:hippoTier(char,field,record.profile,bridge:config("NeedsConfig"))
        end
        bridge:paintHippoGait(tier)
    end
    function f:reconcileHippoGait(s)
        if not registry.byId.hippoMove.requested then self.hippoGaitConflict=nil end
        local cfg=registry.byId.hippoMove.requested and s.alive and s.species=="Hippo" and bridge:config("Species")
        local hippo=cfg and cfg.List and cfg.List.Hippo
        if self.hippoScaled and (not hippo or self.hippoScaled.cfg~=cfg or self.hippoScaled.char~=s.char
            or self.hippoScaled.profile~=hippo) then
            self.leases:release("hippoGait");self.hippoScaled=nil
        end
        if self.hippoGaitConflict and self.hippoGaitConflict.cfg==cfg and self.hippoGaitConflict.char==s.char then return end
        if not hippo or type(cfg.scaled)~="function" or not numeric(hippo,{"speed","gait"})
            or game.PlaceVersion~=2412 then return end
        if self.hippoScaled then
            if not self.leases:valid("hippoGait") then self.leases:release("hippoGait");self.hippoScaled=nil;self.hippoGaitConflict={cfg=cfg,char=s.char} end
            return
        end
        local original=cfg.scaled
        local char=s.char
        local wrapper=function(species,field,growth,...)
            local result=original(species,field,growth,...)
            if species~="Hippo" or (field~="gait" and field~="swimSpeed") or bridge.player.Character~=char
                or not char.Parent or game.PlaceVersion~=2412 or cfg.List.Hippo~=hippo then return result end
            local needs=bridge:config("NeedsConfig")
            local tier,multiplier=self:hippoTier(char,field,hippo,needs)
            if not tier then return result end
            if field=="swimSpeed" then
                local speed=original(species,"swimSprint",growth,...)
                return Core.finite(speed) and speed*multiplier or result
            end
            local walk=hippo.walkMul
            if type(hippo.walkMulStage)=="table" and type(cfg.stage)=="function" then
                local ok,stage=pcall(cfg.stage,growth,species);if ok then walk=hippo.walkMulStage[stage] or walk end
            end
            local scale=bridge:attribute(char,"WalkKMul")
            if scale~=nil and not Core.finite(scale) then return result end
            walk=(Core.finite(walk) and walk or 1)*(scale or 1)
            local run=needs and needs.RUN_SPEED
            local speed=original(species,"speed",growth,...)
            if not Core.finite(walk) or walk<=0 or not Core.finite(run) or run<=0 or not Core.finite(speed) then return result end
            self.hippoStatus=tier=="burst" and "BURST_SPEED_REQUESTED" or "SPRINT_SPEED_REQUESTED"
            return speed*run*multiplier*(42/16.8)/walk
        end
        local ok=self.leases:apply("hippoGait",{entry(cfg,"scaled",wrapper,"function")})
        if ok then self.hippoScaled={cfg=cfg,char=char,profile=hippo,original=original} end
    end
    -- Hippo Crusher Bite has a v2412 native SPEED_CAP="trot" profile.
    -- A separate owner avoids touching other species or requiring a new toggle.
    -- Use the fastest native locomotion tier (burst) as the client-side cap.
    -- This does not activate a burst gait; the server may still impose a slow.
    function f:reconcileHippo(s)
        self:reconcileHippoGait(s)
        local hippo=registry.byId.hippoMove.requested and s.alive and s.species=="Hippo"
        local ability=hippo and bridge:config("AbilityConfig")
        local base=hippo and bridge:config("AbilityConfigBase")
        local profile
        if hippo then
            for _,cfg in ipairs({ability or false,base or false}) do
                if type(cfg)=="table" then
                    local candidate=cfg.CrusherBite
                        or (type(cfg.Hippo)=="table" and cfg.Hippo.CrusherBite)
                        or cfg.CRUSHER
                    if type(candidate)=="table" and (candidate.SPEED_CAP=="trot"
                        or candidate==self.hippoProfile and candidate.SPEED_CAP=="burst") then
                        profile=candidate;break
                    end
                end
            end
        end
        if self.hippoProfile and (not hippo or not profile or self.hippoProfile~=profile
            or self.hippoCharacter~=s.char) then
            self.leases:release("hippoCrush")
            self.hippoProfile,self.hippoCharacter=nil,nil
        end
        if not hippo then
            self.hippoStatus=registry.byId.hippoMove.requested and "WAITING" or "OFF"
            return
        end
        if self.leases.owners.hippoCrush then
            if self.leases:valid("hippoCrush") then
                self.hippoStatus="CLIENT";return
            end
            -- An external edit owns this value now; don't overwrite it.
            self.leases:release("hippoCrush")
            self.hippoProfile,self.hippoCharacter=nil,nil
            self.hippoStatus="CONFLICT";return
        end
        if not profile then self.hippoStatus="WAITING";return end
        -- The native speed tier is read from the same scoped Crusher Bite
        -- profile. Do not force Humanoid.WalkSpeed or manipulate ability remotes.
        local applied=self.leases:apply("hippoCrush",{
            entry(profile,"SPEED_CAP","burst","string")
        })
        self.hippoStatus=applied and "CLIENT" or "WAITING"
        if applied then self.hippoProfile,self.hippoCharacter=profile,s.char end
    end
    function f:reconcile(s, now, force)
        if not force and now < self.nextReconcile then return end
        self.nextReconcile = now+1.25
        for _, id in ipairs({ "reach","stamina","recovery","effects","mobility","speed","leap","climb","attackSpeed" }) do
            local dependencies = {
                reach = {"CombatConfig"},stamina = {"NeedsConfig","FlightConfig","PassiveConfig","VenomConfig","StatusConfig"},
                attackSpeed = {"Species"},
                recovery = {"NeedsConfig"},effects = {"StatusConfig"},
                mobility = {"NeedsConfig","StatusConfig"},speed = {"NeedsConfig"},
                leap = {"JumpLeapConfig"},climb = {"PassiveConfig"},
            }
            local identity,changed = {},false
            for _,name in ipairs(dependencies[id]) do
                identity[name] = bridge:config(name) or false
                if self.configIdentity[id] and self.configIdentity[id][name] ~= identity[name] then changed = true end
            end
            if id=="stamina" then
                local passive=identity.PassiveConfig
                local climb=type(passive)=="table" and type(passive.CLIMBER)=="table" and passive.CLIMBER
                identity.climb=climb or false
                identity.levels=climb and climb.levels or false
                identity.sprint=climb and climb.CLIMB_SPRINT or false
                identity.venom=type(identity.StatusConfig)=="table" and identity.StatusConfig.VENOM or false
                identity.burst=type(identity.NeedsConfig)=="table" and identity.NeedsConfig.BURST or false
                for _,name in ipairs({"climb","levels","sprint","venom","burst"}) do
                    if self.configIdentity[id] and self.configIdentity[id][name]~=identity[name] then changed=true end
                end
                for level=1,3 do
                    local name="climbLevel"..level
                    identity[name]=climb and type(climb.levels)=="table" and climb.levels[level] or false
                    if self.configIdentity[id] and self.configIdentity[id][name]~=identity[name] then changed=true end
                end
            end
            if changed then self.leases:release(id);self.failures[id] = nil end
            self.configIdentity[id] = identity
            local record = registry.byId[id]
            if not record.requested then
                self.leases:release(id)
                registry:ack(id,false,"OFF","original client inputs restored")
                self.failures[id] = nil
            elseif self.failures[id] == "conflict" then
                registry:ack(id,false,"UNAVAILABLE","external config changed; toggle to retry")
            elseif self.leases.owners[id] then
                if self.leases:valid(id) then
                    registry:ack(id,true,"CLIENT","local config acknowledged; gameplay unverified")
                else
                    self.leases:release(id)
                    self.failures[id] = "conflict"
                    registry:ack(id,false,"UNAVAILABLE","external config changed")
                end
            else
                local ok, plan, why = pcall(self.plan,self,id)
                if not ok then why, plan = tostring(plan), nil end
                if plan then
                    local applied, reason = self.leases:apply(id,plan)
                    registry:ack(id,applied,applied and "CLIENT" or "UNAVAILABLE",reason)
                else registry:ack(id,false,"WAITING",why) end
            end
        end
        self:reconcileHippo(s)
        local stamina = registry.byId.stamina
        if not self:flagCharacter(s,stamina.requested and stamina.applied) and stamina.requested then
            registry:ack("stamina",false,"PARTIAL","local config applied; character flag unavailable")
        end
    end
    function f:close()
        bridge:paintHippoGait(nil)
        self:releaseFlag()
        self.leases:close()
    end
    return f
end
return Features
