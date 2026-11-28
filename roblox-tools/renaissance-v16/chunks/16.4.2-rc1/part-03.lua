false end
        local ok,cd=pcall(species.biteCooldown,self:attribute(s.char,"Species") or species.DEFAULT,
            self:attribute(s.char,"Growth") or 1)
        if not ok or not Core.finite(cd) or cd<.03 or cd>30 then return false end
        local passive=self:config("PassiveConfig")
        if passive and passive.biteCdMult~=nil then
            local valid,m=pcall(passive.biteCdMult,s.char)
            if not valid or not Core.finite(m) or m<=0 or m>20 then return false end
            cd*=m
        end
        local marker=self:attribute(s.char,"WolfBiteAt")
        if marker~=nil and (not Core.finite(marker) or marker>s.serverNow+1) then return false end
        if Core.finite(marker) and s.serverNow-marker<cd-.005 then return false end
        local input=self.combatGovernor
        if input and input.lastDispatch>0 and now-input.lastDispatch<cd-.005
            and not Core.finite(marker) then return false end
        return true
    end
    -- A pcall succeeding on VirtualInputManager does not mean FERAL received
    -- a native bite. After two unmarked pulses try a different available
    -- real-input backend automatically, without user diagnostics.
    -- The first backend that produces a real native WolfBiteAt marker is
    -- preferred over unverified alternatives. Native cooldowns can create
    -- missing markers even though a backend is still functioning.
    function b:noteHeldInputTimeout()
        self.heldInputMisses=(self.heldInputMisses or 0)+1
        if self.holdBinding=="M3" and self.heldInputLockedBackend then return end
        local count=self.heldInputModes or 1
        if count<=1 then return end
        local verified=self.heldInputVerifiedIndex
        local current=self.heldInputIndex or 1
        if verified and verified<=count then
            if current==verified then
                if self.heldInputMisses>=5 then
                    self.heldInputIndex=(verified%count)+1
                    self.heldInputProbeLeft=2
                    self.heldInputMisses=0
                end
            else
                self.heldInputProbeLeft=(self.heldInputProbeLeft or 2)-1
                if self.heldInputProbeLeft<=0 then
                    self.heldInputIndex=verified
                    self.heldInputProbeLeft=nil
                    self.heldInputMisses=0
                end
            end
        elseif self.heldInputMisses>=2 then
            self.heldInputIndex=(current%count)+1
            self.heldInputMisses=0
        end
    end
    function b:noteHeldInputMarker()
        self.heldInputMisses=0
        local index=self.heldInputIndex or 1
        if index>=1 and index<=(self.heldInputModes or 1) then
            self.heldInputVerifiedIndex=index
        end
        self.heldInputProbeLeft=nil
    end
    function b:releaseSyntheticBite()
        local pulse=self.syntheticM1
        if not pulse then return end
        self.syntheticM1=nil
        if pulse.timer and type(task)=="table" and type(task.cancel)=="function" then
            pcall(task.cancel,pulse.timer)
        end
        if not pulse.independent or pulse.didPress then
            self.syntheticReleasing=true
            pcall(pulse.release)
            self.syntheticReleasing=false
        end
        self:restoreFeedClickGuard(pulse.feedGuard)
    end
    -- If an executor fails to run the scheduled synthetic release, do not
    -- permanently block subsequent held-M1 takeover bites.
    function b:clearStaleSyntheticBite(now)
        local pulse=self.syntheticM1
        if not pulse or not Core.finite(pulse.startedAt)
            or now-pulse.startedAt<.5 then return false end
        self:releaseSyntheticBite()
        return true
    end
    -- A physical held M1 is already in the Down state. Simply sending
    -- another Down is ignored by input systems that require a new edge.
    -- Re-arm one short Up -> Down -> Up pulse, with a single owner, unless
    -- an active native grab session has priority. No Bite/BiteHit remotes.
    -- A food/water offer is not feeding. M3 may start on its prompt,
    -- but a generated primary input must never activate that GUI control.
    local feedNames={feralfeedtap=true,feedtap=true,feedbutton=true,eatbutton=true,
        drinkbutton=true,eatdrinkbutton=true,feralfeedbutton=true}
    local function feedLabel(node)
        if feedNames[string.lower(tostring(node.Name or "")):gsub("[^%w]","")] then return true end
        if not (node:IsA("TextButton") or node:IsA("TextLabel")) then return false end
        local label=string.upper(tostring(node.Text or "")):gsub("<[^>]*>",""):match("^%s*(.-)%s*$")
        for _,name in ipairs({"EAT","DRINK","EAT / DRINK"}) do
            if label==name or label==name.." [E]" or label==name.." (E)"
                or label=="[E] "..name or label=="(E) "..name then return true end
        end
        return false
    end
    function b:feedOfferControl(object)
        local node=object
        for _=1,5 do
            if not node then break end
            if feedLabel(node) then return true end
            node=node.Parent
        end
        if object:IsA("GuiButton") then
            local ok,children=pcall(object.GetDescendants,object)
            if ok then
                for _,child in ipairs(children) do if feedLabel(child) then return true end end
            end
        end
        return false
    end
    -- This lease covers one generated primary press and its release.
    -- Only recognised feed buttons are changed; do not hide HUD elements,
    -- write game attributes, consume keyboard input or alter native cooldowns.
    function b:restoreFeedClickGuard(lease)
        if not lease or lease.restored then return end
        lease.restored=true
        for i=#lease.entries,1,-1 do
            local entry=lease.entries[i]
            pcall(function()
                if entry.button.Active==false then entry.button.Active=entry.active end
                if entry.button.Interactable==false then entry.button.Interactable=entry.interactable end
            end)
        end
    end
    function b:beginFeedClickGuard(char)
        local gui=self.player:FindFirstChildOfClass("PlayerGui")
        local offer=self:feedOfferActive(char)
        local lease={entries={}}
        if not gui then
            if offer then return nil,"feeding control unresolved" end
            return lease
        end
        local ok,objects=pcall(gui.GetDescendants,gui)
        if not ok or type(objects)~="table" then return nil,"feeding control query unavailable" end
        local buttons={}
        -- Look at the entire own GUI, not just the reported click coordinates.
        -- Nested Eat/Drink labels can identify an ImageButton.
        for _,object in ipairs(objects) do
            if object:IsA("GuiButton") and self:feedOfferControl(object) then
                buttons[object]=true
            end
        end
        local found=false
        for button in pairs(buttons) do
            found=true
            local readable,active,interactable=pcall(function()return button.Active,button.Interactable end)
            if not readable or type(active)~="boolean" or type(interactable)~="boolean" then
                self:restoreFeedClickGuard(lease)
                return nil,"feeding control guard unavailable"
            end
            table.insert(lease.entries,{button=button,active=active,interactable=interactable})
            local guarded,verified=pcall(function()
                button.Interactable=false
                button.Active=false
                return button.Interactable==false and button.Active==false
            end)
            if not guarded or not verified then
                self:restoreFeedClickGuard(lease)
                return nil,"feeding control guard unavailable"
            end
        end
        -- An unrecognised active feeding control is not safe to click through.
        if offer and not found then
            self:restoreFeedClickGuard(lease)
            return nil,"feeding control unresolved"
        end
        if found then self.feedGuardPulses=(self.feedGuardPulses or 0)+1 end
        return lease
    end
    -- This check is for actual generated clicks only, never M3 acquisition.
    -- Unknown GUI state remains blocked rather than clicking blindly.
    function b:mouseGameplayPoint(point,allowOffer)
        point=point or self.UserInputService:GetMouseLocation()
        local gui=self.player:FindFirstChildOfClass("PlayerGui")
        if not point then return false,false,"mouse position unavailable" end
        if self.combatPointBlocked and self.combatPointBlocked(point) then return false,false,"hub UI" end
        if not gui then return true,false,"clear" end
        local ok,under=pcall(gui.GetGuiObjectsAtPosition,gui,point.X,point.Y)
        if not ok or type(under)~="table" then return false,false,"GUI query unavailable" end
        local offer,button=false,false
        for _,object in ipairs(under) do
            local node=object
            for _=1,4 do
                if not node then break end
                if node:IsA("TextBox") then return false,false,"text field" end
                if node:IsA("GuiButton") then
                    local readable,interactable=pcall(function()return node.Interactable end)
                    if not readable or interactable~=false then
                        if self:feedOfferControl(node) or self:feedOfferControl(object) then offer=true
                        else button=true end
                    end
                end
                node=node.Parent
            end
        end
        if button then return false,offer,"HUD button" end
        if offer then return allowOffer==true,true,"Eat/Drink offer" end
        return true,false,"clear"
    end
    function b:feedOfferActive(char)
        local offer=self:attribute(char,"FeedCan")
        return offer=="eat" or offer=="drink"
    end
    function b:clearOfferClickPoint(point)
        local clear,offer,reason=self:mouseGameplayPoint(point,false)
        if clear then return point end
        -- A feed button must be isolated by the pulse guard, not avoided by
        -- assuming the executor actually honours relocated coordinates.
        if self.holdBinding=="M3" and offer then return nil,"Eat/Drink offer" end
        -- Only relocate a coordinate-addressable click around a confirmed HUD
        -- obstruction. Do not relocate across real hub/text/menu boundaries
        -- or when the hit-test API cannot establish a clear position.
        if reason~="HUD button" and reason~="Eat/Drink offer" then return nil,reason end
        local camera=self.Workspace.CurrentCamera
        local size=camera and camera.ViewportSize
        if not size then return nil,"viewport unavailable" end
        for _,distance in ipairs({12,24,48,72,96,128}) do
            for _,offset in ipairs({{0,-distance},{0,distance},{-distance,0},{distance,0}}) do
                local x,y=point.X+offset[1],point.Y+offset[2]
                if x>=8 and y>=8 and x<size.X-8 and y<size.Y-8 then
                    local candidate=Vector2.new(x,y)
                    if self:mouseGameplayPoint(candidate,false) then return candidate end
                end
            end
        end
        return nil,"no verified clear click position"
    end
    function b:blockedHeldInput(reason)
        self.heldInputBlockReason=reason
        return false
    end
    function b:tryHeldInputBite(s,now)
        self.heldInputBlockReason=nil
        if self.syntheticM1 then return self:blockedHeldInput("previous click releasing") end
        local independent=self.holdBinding=="M3"
        local desktop=independent and s and type(self.desktopOwnsPrimary)=="function" and self.desktopOwnsPrimary(s,now)
        if independent and (not s or s.r2Held or not desktop and (s.mouseHeld or s.physicalM1Held)) then
            return self:blockedHeldInput("manual primary input")
        end
        if independent and self.combatPulseBlocked and self.combatPulseBlocked() then
            return self:blockedHeldInput("pulse ownership unavailable")
        end
        if not s or not s.alive or s.char~=self.player.Character or not self:combatInputCompatible()
            or s.chat or s.gameMenu or s.grab or s.rest or s.feeding or s.ability
            or s.captured or s.holding then return false end
        local position=self.UserInputService:GetMouseLocation()
        if not position then return self:blockedHeldInput("mouse position unavailable") end
        local clear,offer,pointReason=self:mouseGameplayPoint(position,independent)
        if not clear and (not independent or pointReason~="HUD button" and pointReason~="Eat/Drink offer") then
            return self:blockedHeldInput(pointReason)
        end
        local virtualPoint,virtualReason=position,nil
        if not clear and not offer then virtualPoint,virtualReason=self:clearOfferClickPoint(position) end
        local modes={}
        local ok,virtual=pcall(function()return game:GetService("VirtualInputManager")end)
        if ok and virtual then table.insert(modes,{
            name="VIRTUAL_MOUSE",
            down=function()virtual:SendMouseButtonEvent(virtualPoint.X,virtualPoint.Y,0,true,game,0)end,
            up=function()virtual:SendMouseButtonEvent(virtualPoint.X,virtualPoint.Y,0,false,game,0)end,
        }) end
        if type(mouse1press)=="function" and type(mouse1release)=="function" then
            table.insert(modes,{name="EXECUTOR_PAIRED",down=mouse1press,up=mouse1release})
        end
        if type(mouse1click)=="function" then
            table.insert(modes,{name="EXECUTOR_CLICK",click=mouse1click})
        end
        if #modes==0 then return false end
        self.heldInputModes=#modes
        if self.heldInputVerifiedIndex and self.heldInputVerifiedIndex>#modes then
            self.heldInputVerifiedIndex,self.heldInputProbeLeft=nil,nil
        end
        local index=self.heldInputIndex or 1
        if independent and self.heldInputLockedBackend then
            index=nil
            for i,mode in ipairs(modes) do
                if mode.name==self.heldInputLockedBackend then index=i;break end
            end
            if not index then return false end
        elseif index>#modes then index=1 end
        self.heldInputIndex=index
        local mode=modes[index]
        local down,up,backend=mode.down,mode.up,mode.name
        if backend=="VIRTUAL_MOUSE" then
            if not virtualPoint then return self:blockedHeldInput(virtualReason or "no verified clear click position") end
        elseif not clear then
            -- A physical-coordinate adapter cannot relocate an ordinary
            -- click safely. Retain the chosen route instead of clicking UI.
            return self:blockedHeldInput(pointReason)
        end
        self.heldInputBackend=backend
        if mode.click then
            -- Atomic adapters cannot establish the release boundary. The
            -- verified virtual paired route is preferred for guarded input.
            if independent and (offer or self:feedOfferActive(self.player.Character)) then
                return self:blockedHeldInput("paired click required for feeding guard")
            end
            if not self:mouseGameplayPoint(nil,false) then return false end
            self.syntheticM1Until=now+.18
            self.syntheticPressing=true
            local clicked=pcall(mode.click)
            self.syntheticPressing=false
            if not clicked then self:noteHeldInputTimeout() end
            return clicked
        end
        self.syntheticM1Until=now+.3
        local pulse={release=up,method=backend,didPress=false,startedAt=now,independent=independent}
        self.syntheticM1=pulse
        local function safeUp()
            self.syntheticReleasing=true
            local success=pcall(up)
            self.syntheticReleasing=false
            return success
        end
        local function stop()
            if self.syntheticM1==pulse then self:releaseSyntheticBite() end
        end
        -- Reset the logical button state while preserving the real human-held
        -- intent in CombatInput (synthetic InputEnded events are ignored).
        if not independent and not safeUp() then
            self.syntheticM1=nil
            self.heldInputIndex=(index%#modes)+1
            self.heldInputMisses=0
            return false
        end
        local function beginPress()
            if self.syntheticM1~=pulse then return end -- a grab began meanwhile
            if self.combatPulseBlocked then
                local known,blocked=pcall(self.combatPulseBlocked)
                if not known or blocked then self.heldInputBlockReason="pulse ownership unavailable";stop();return end
            end
            local readable,current=pcall(self.snapshot,self,self.clock(),false)
            local desktopOwned=readable and desktop and type(self.desktopOwnsPrimary)=="function"
                and self.desktopOwnsPrimary(current,self.clock())
            if desktop and not desktopOwned then
                self.heldInputBlockReason="desktop hold expired";stop();return
            end
            if not readable or not current.alive or current.char~=s.char or current.generation~=s.generation
                or current.chat or current.gameMenu or current.rest or current.feeding
                or current.ability or current.captured or current.holding
                or independent and (current.r2Held or current.grab or current.mouseHeld and not desktopOwned) then
                self.heldInputBlockReason="native action or manual input lock";stop();return
            end
            if independent then
                -- Lease the actual feeding controls just before Down, and
                -- restore immediately after Up (including errors/unload).
                local lease,why=self:beginFeedClickGuard(current.char)
                if not lease then self.heldInputBlockReason=why;stop();return end
                pulse.feedGuard=lease
                -- UI may appear between scheduling and the actual press.
                -- Revalidate the point without moving the physical mouse.
                if backend=="VIRTUAL_MOUSE" then
                    local origin=self.UserInputService:GetMouseLocation()
                    if not origin then stop();return end
                    local candidate,reason=self:clearOfferClickPoint(origin)
                    if not candidate or not self:mouseGameplayPoint(candidate,false) then
                        self.heldInputBlockReason=reason or "click point changed"
                        stop();return
                    end
                    virtualPoint=candidate
                elseif not self:mouseGameplayPoint(nil,false) then
                    self.heldInputBlockReason="cursor over an interactive control"
                    stop();return
                end
                -- If the engine still reports the primary as down, re-arm
                -- its ordinary logical input edge once, under the same
                -- feeding guard. Do not change physical device state.
                if desktopOwned and current.mouseHeld and not pulse.desktopReset then
                    pulse.desktopReset=true
                    if not safeUp() then self.heldInputBlockReason="logical release unavailable";stop();return end
                    self.desktopLogicalResets=(self.desktopLogicalResets or 0)+1
                    self:restoreFeedClickGuard(pulse.feedGuard);pulse.feedGuard=nil
                    if type(task)=="table" and type(task.delay)=="function" then
                        local scheduled,timer=pcall(task.delay,.025,beginPress)
                        if scheduled then pulse.timer=timer;return end
                    end
                    self.heldInputBlockReason="logical release scheduling unavailable";stop();return
                end
                pulse.didPress=true
            end
            self.syntheticPressing=true
            local pressed=pcall(down)
            self.syntheticPressing=false
            if not pressed then self.heldInputBlockReason="input adapter rejected press";stop();return end
            if desktop then self.desktopDispatches=(self.desktopDispatches or 0)+1 end
            pulse.didPress=true
            if self.syntheticM1~=pulse then return end -- reentrant grab begin
            if type(task)=="table" and type(task.delay)=="function" then
                local scheduled,timer=pcall(task.delay,.055,stop)
                if scheduled then pulse.timer=timer else stop() end
            else stop() end
        end
        if type(task)=="table" and type(task.delay)=="function" then
            local scheduled,timer=pcall(task.delay,.025,beginPress)
            if scheduled then pulse.timer=timer;return true end
        end
        -- Never leave a held synthetic button if delayed input isn't supported.
        beginPress()
        return pulse.didPress
    end
    -- FeralHippoClient.finish uses the native clock and release path. Validate
    -- its captured own-player/remote layout before retaining or calling it.
    function b:hippoHandleValid(native)
        if not self:capability("hippoFinish") or not native or type(native.finish)~="function" then return false end
        local scripts=self.player:FindFirstChild("PlayerScripts")
        local own=scripts and scripts:FindFirstChild("FeralHippoClient")
        local remote=self.ReplicatedStorage:FindFirstChild("FeralHippo")
        if not own or own~=native.script or not remote or remote~=native.remote then return false end
        local ok,source,name=pcall(debug.info,native.finish,"sn")
        if not ok or name~="finish" or type(source)~="string" or not source:find("FeralHippoClient",1,true) then return false end
        if type(getfenv)=="function" then
            local valid,env=pcall(getfenv,native.finish)
            if valid and type(env)=="table" and env.script~=nil and env.script~=own then return false end
        end
        local v=self:upvalues(native.finish)
        return v[2]==self.player and type(v[3])=="function" and type(v[4])=="table" and v[5]==remote
    end
    function b:nativeHippoActions(now)
        if self.hippoActions and self:hippoHandleValid(self.hippoActions) then return self.hippoActions end
        self.hippoActions=nil
        if self.deferNativeDiscovery or not self:capability("hippoFinish") or type(getconnections)~="function"
            or type(debug)~="table" or type(debug.info)~="function" then return nil end
        local scripts=self.player:FindFirstChild("PlayerScripts")
        local own=scripts and scripts:FindFirstChild("FeralHippoClient")
        local remote=self.ReplicatedStorage:FindFirstChild("FeralHippo")
        if not own or not remote or not remote:IsA("RemoteEvent") then return nil end
        local scan=self.hippoDiscovery
        if scan and (scan.script~=own or scan.remote~=remote) then scan=nil;self.hippoDiscovery=nil end
        if not scan then
            if now<(self.nextHippoDiscovery or 0) then return nil end
            local signals={}
            if self.UserInputService.InputEnded then table.insert(signals,self.UserInputService.InputEnded) end
            if self.RunService.RenderStepped then table.insert(signals,self.RunService.RenderStepped) end
            table.insert(signals,self.player:GetAttributeChangedSignal("FeralCrushTouchUp"))
            scan={script=own,remote=remote,signals=signals,signalIndex=1,queue={},cursor=1,seen={}}
            self.hippoDiscovery=scan
        end
        local started,checked=self.clock(),0
        while checked<24 and self.clock()-started<.001 do
            local item=scan.queue[scan.cursor]
            if item then
                scan.cursor+=1;checked+=1
                local fn=item.fn
                if type(fn)~="function" or scan.seen[fn] or item.depth>3 then continue end
                scan.seen[fn]=true
                local ok,source,name=pcall(debug.info,fn,"sn")
                local owned=ok and type(source)=="string" and source:find("FeralHippoClient",1,true)
                if type(getfenv)=="function" then
                    local valid,env=pcall(getfenv,fn)
                    if valid and type(env)=="table" and env.script~=nil then owned=env.script==own end
                end
                if not owned and item.depth~=0 then continue end
                if owned and name=="finish" then
                    local native={finish=fn,script=own,remote=remote}
                    if self:hippoHandleValid(native) then
                        self.hippoActions=native;self.hippoDiscovery=nil;return native
                    end
                end
                local count=0
                for _,value in pairs(self:upvalues(fn)) do
                    count+=1;if count>32 then break end
                    if type(value)=="function" and #scan.queue<192 then table.insert(scan.queue,{fn=value,depth=item.depth+1}) end
                end
            elseif scan.connections then
                local record=scan.connections[scan.connectionIndex]
                if not record or scan.connectionIndex>96 then scan.connections=nil;continue end
                scan.connectionIndex+=1;checked+=1
                local ok,fn=pcall(function()return record.Function end)
                if ok and type(fn)=="function" and #scan.queue<192 then table.insert(scan.queue,{fn=fn,depth=0}) end
            else
                local signal=scan.signals[scan.signalIndex]
                if not signal then self.hippoDiscovery=nil;self.nextHippoDiscovery=now+10;return nil end
                scan.signalIndex+=1;checked+=1
                local ok,connections=pcall(getconnections,signal)
                if ok and type(connections)=="table" then scan.connections,scan.connectionIndex=connections,1 end
            end
        end
        return nil
    end
    function b:finishNativeHippo(s,startedAt,now)
        if not s.alive or s.species~="Hippo" or s.char~=self.player.Character then return false end
        local native=self:nativeHippoActions(now)
        if not native or not self:hippoHandleValid(native) then return false end
        local state=self:upvalues(native.finish)[1]
        if type(state)~="table" or state.at~=startedAt or self:attribute(s.char,"FeralCrushAt")~=startedAt then return false end
        return pcall(native.finish) -- no supplied timestamp, multiplier or damage
    end
    -- The client's unmodified native attack cooldown provides the baseline
    -- for request pacing. Reading it does not change native damage or cooldown.
    function b:nativeBiteCooldown(s)
        if not s or not s.char or s.char~=self.player.Character then return nil end
        local native=self.wolfActions
        if native and type(native.biteCooldown)=="function"
            and self:capability("wolfTiming") then
            local ok,cd=pcall(native.biteCooldown)
            if ok and Core.finite(cd) and cd>=.03 and cd<=30 then return cd end
        end
        local species=self:config("Species")
        if not species or type(species.biteCooldown)~="function" then return nil end
        local ok,cd=pcall(species.biteCooldown,
            self:attribute(s.char,"Species") or species.DEFAULT,
            self:attribute(s.char,"Growth") or 1)
        if not ok or not Core.finite(cd) or cd<.03 or cd>30 then return nil end
        local passive=self:config("PassiveConfig")
        if passive and passive.biteCdMult~=nil then
            local valid,mult=pcall(passive.biteCdMult,s.char)
            if not valid or not Core.finite(mult) or mult<=0 or mult>20 then return nil end
            cd*=mult
        end
        return Core.finite(cd) and cd>=.03 and cd<=30 and cd or nil
    end
    function b:biteDelay(char)
        local c = self:config("CombatConfig")
        if c and type(c.hitDelay) == "function" then
            local ok,delay = pcall(c.hitDelay,char)
            if ok and Core.finite(delay) and delay >= .03 and delay <= 1 then return delay end
        end
        return c and Core.finite(c.HIT_DELAY) and math.clamp(c.HIT_DELAY,.03,1) or .27
    end
    function b:restLock(char)
        local profiles=self:config("AnimProfiles")
        local profile=profiles and profiles[self:attribute(char,"AnimProfile") or ""]
        local value=profile and profile.REST_UP_LOCK
        return Core.finite(value) and math.clamp(value,.05,1.5) or .7
    end
    function b:biteReadiness(s,now,policy)
        local function result(ready,reason,known)return {ready=ready,reason=reason,known=known~=false}end
        if not s.alive then return result(false,"waiting for animal") end
        if s.chat or s.gameMenu then return result(false,"menu or text input") end
        if s.captured or s.char:FindFirstChild("FeralClamp") then return result(false,"capture or carry lock") end
        if s.feeding then return result(false,"feeding") end
        if s.rest or policy.manualRest or policy:restLocked(now,self:restLock(s.char)) then return result(false,"Rest or stand-up lock") end
        if s.ability or self:attribute(s.char,"FeralKingsAt") or self:attribute(s.char,"FeralCrushAt") then
            return result(false,"native ability lock")
        end
        for _,key in ipairs({"FeralNoBiteUntil","FeralVenomRecoilUntil"}) do
            local at=self:attribute(s.char,key)
            if at~=nil and (not Core.finite(at) or not s.serverNow) then return result(false,"native timing unknown",false) end
            if at and at>s.serverNow then return result(false,"native bite lock") end
        end
        local native=self.wolfActions
        local scripts=self.player:FindFirstChild("PlayerScripts")
        local own=scripts and scripts:FindFirstChild("WolfController")
        if native and (native.remote~=self.ReplicatedStorage:FindFirstChild("WolfActions")
            or native.script~=own or not own or own.Parent==nil or native.placeVersion~=game.PlaceVersion) then
            self:resetWolfDiscovery();native=nil
        end
        if not self:capability("wolfTiming") or not native or not native.tryBite
            or not native.doBite or not native.biteCooldown then
            -- Primary-input connections may be VM-isolated. The captured
            -- cooldown calculation and own SafeTime bite marker remain useful,
            -- but do not establish the inaccessible private Rest/input state.
            local species=self:config("Species")
            local passive=self:config("PassiveConfig")
            local at=self:attribute(s.char,"WolfBiteAt")
            if not species or type(species.biteCooldown)~="function" or not s.serverNow or not Core.finite(at)
                or at>s.serverNow+1 then return result(false,"native timing unavailable",false) end
            local ok,cd=pcall(species.biteCooldown,self:attribute(s.char,"Species") or species.DEFAULT,self:attribute(s.char,"Growth") or 1)
            local mult=1
            if passive and passive.biteCdMult~=nil then
                local valid,value=pcall(passive.biteCdMult,s.char)
                if not valid or not Core.finite(value) or value<=0 then return result(false,"native cooldown unknown",false) end
                mult=value
            end
            if not ok or not Core.finite(cd) or cd*mult<.03 or cd*mult>30 then return result(false,"native cooldown unknown",false) end
            local r=result(s.serverNow-at>=cd*mult,s.serverNow-at>=cd*mult
                and "visible client checks clear; private state unverified" or "native cooldown")
            r.timingSource="native config and own bite marker";r.privateStateKnown=false
            if not r.ready then r.nextAt=now+math.max(.015,cd*mult-(s.serverNow-at)) end
            return r
        end
        local timing=self.biteTiming
        if not timing or timing.native~=native or now>=timing.nextAt then
            if self.deferNativeDiscovery then return result(false,"native timing deferred",false) end
            local try,doBite=self:upvalues(native.tryBite),self:upvalues(native.doBite)
            local remote=self.ReplicatedStorage:FindFirstChild("WolfActions")
            if try[1]~=self.player or try[4]~=native.biteCooldown or try[5]~=native.doBite
                or doBite[1]~=self.player or doBite[8]~=remote or not remote
                or not Core.finite(try[3]) or not Core.finite(doBite[4])
                or type(doBite[2])~="boolean" or type(doBite[3])~="boolean" then
                return result(false,"native timing layout unknown",false)
            end
            -- The captured biteCooldown prototype is a pure native calculation.
            -- No attack/cooldown state is changed or bypassed.
            local ok,cd=pcall(native.biteCooldown)
            if not ok or not Core.finite(cd) or cd<.03 or cd>30 then return result(false,"native cooldown unknown",false) end
            timing={native=native,lastBite=try[3],lastRest=doBite[4],resting=doBite[2] or doBite[3],cd=cd,nextAt=now+.05}
            self.biteTiming=timing
        end
        if timing.resting or now-timing.lastRest<self:restLock(s.char) then return result(false,"native Rest lock") end
        if now-timing.lastBite<timing.cd then
            local r=result(false,"native cooldown");r.nextAt=timing.lastBite+timing.cd;return r
        end
        local r=result(true,"client checks clear; gameplay unverified")
        r.privateStateKnown=true;r.timingSource="validated own native closures"
        return r
    end
    function b:io()
        return {
            available = type(readfile) == "function" and type(writefile) == "function",
            read = function(path)
                assert(type(readfile) == "function","readfile unavailable")
                return self.HttpService:JSONDecode(readfile(path))
            end,
            write = function(path,value)
                assert(type(writefile) == "function","writefile unavailable")
                writefile(path,self.HttpService:JSONEncode(value))
                return true
            end,
        }
    end
    function b:water(char,hum,root)
        if not hum or not root then return false,false end
        local swim = self:attribute(char,"FeralSwimLocal") == true
            or hum:GetState() == Enum.HumanoidStateType.Swimming or hum.FloorMaterial == Enum.Material.Water
        local under = self:attribute(char,"FeralUnderwater") == true
            or self:attribute(char,"FeralDiving") == true
        local params = RaycastParams.new()
        params.FilterType, params.FilterDescendantsInstances = Enum.RaycastFilterType.Include,{self.Workspace.Terrain}
        params.IgnoreWater = false
        local body = math.max(hum.HipHeight+root.Size.Y/2,.2)
        local y,top = root.Position.Y+40,nil
        for _ = 1,2 do
            local hit = self.Workspace:Raycast(Vector3.new(root.Position.X,y,root.Position.Z),
                Vector3.new(0,-(y-root.Position.Y+body*2),0),params)
            if not hit then break end
            if hit.Material == Enum.Material.Water then top = hit.Position.Y; break end
            if hit.Position.Y <= root.Position.Y then break end
            y = hit.Position.Y-.3
        end
        local depth = top and top-root.Position.Y
        if depth and depth > math.max(1.6,body*1.2) then under = true end
        local surface = swim and depth ~= nil and not under
            and depth >= -math.max(1.6,body*1.25) and depth <= math.max(1.6,body*1.2)
        return swim,under,surface == true,depth
    end
    function b:snapshot(now, waterNeeded)
        local char = self.player.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local at = self:serverNow()
        local deadline = self:attribute(self.player,"FeralCombatUntil")
        local combat = nil
        if at and (deadline == nil or Core.finite(deadline)) then combat = (deadline or 0) > at end
        local s = { now = now, serverNow = at, char = char, hum = hum, root = root,
            generation = self.generation, species=self:attribute(char,"Species"),
            alive = char ~= nil and char.Parent ~= nil and hum ~= nil and root ~= nil and hum.Health > 0,
            hp = hum and hum.Health or 0, maxHP = hum and hum.MaxHealth or 0,
            chat = self.UserInputService:GetFocusedTextBox() ~= nil,
            gameMenu = self:attribute(self.player,"FeralMenuOpen") == true
                or self:attribute(self.player,"FeralTitleOpen") == true
                or self:attribute(self.player,"FeralMapOpen") == true,
            combat = combat, rest = self:attribute(char,"WolfRest") == true,
            feeding = false, captured = false, moving = false, locomotion = "NONE",
            injury = self:attribute(char,"FeralInjury"), bleed = self:attribute(char,"FeralBleed"),
            venom = self:attribute(char,"FeralVenomAmt"), stamina = self:attribute(char,"Stamina"),
            maxStamina=self:attribute(char,"StaminaMax"),
            hunger = self:attribute(char,"Hunger"), thirst = self:attribute(char,"Thirst"),
            survival = self:attribute(self.player,"FeralSurvival") }
        if not s.alive then return s end
        s.serverTired=self:attribute(char,"FeralSrvTired")==true
        s.noSprint=self:attribute(char,"FeralNoSprint")==true
        s.protectedInteraction=self:protectedInteraction(char)
        local feed = self:attribute(char,"WolfFeed")
        s.feedMode = (feed == "eat" or feed == "drink") and feed or nil
        s.feeding = feed == true or s.feedMode ~= nil
        s.captured = self:attribute(char,"FeralPinned") == true
            or self:attribute(char,"FeralCarried") == true or self:attribute(char,"FeralDragged") == true
        s.pinned = self:attribute(char,"FeralPinned") == true or self:attribute(char,"FeralDragged") == true
        s.carried = self:attribute(char,"FeralCarried") == true
        s.climbing = self:isClimbing(char)
        s.climbCan = self:attribute(char,"ClimbCan") == true
        s.climber = self:attribute(char,"PassiveClimber")
        s.flying = self:attribute(char,"FeralFlyLocal") == true
        s.diveCan = self:attribute(self.player,"FeralDiveCan") == true
            or self:attribute(char,"DiveCan") == true
        s.diving = self:attribute(char,"FeralDiving") == true
        s.burst = self:attribute(self.player,"HudBurst") == true or self:attribute(char,"FeralFlyBurst") == true
        -- v2412 WolfController input callback accepts MouseButton1/R2.
        -- MouseButton2 is a camera control, not a continuously held bite.
        local mouseOK,mouseDown=pcall(self.UserInputService.IsMouseButtonPressed,
            self.UserInputService,Enum.UserInputType.MouseButton1)
        s.mouseHeld=mouseOK and mouseDown==true
        s.mouseHeldKnown=mouseOK and type(mouseDown)=="boolean"
        if self.holdBinding=="M3" then
            local middleOK,middleDown=pcall(self.UserInputService.IsMouseButtonPressed,
                self.UserInputService,Enum.UserInputType.MouseButton3)
            s.middleHeldKnown=middleOK and type(middleDown)=="boolean"
            s.middleHeld=middleOK and middleDown==true
        end
        s.r2Held=false
        local padsOK,pads=pcall(self.UserInputService.GetConnectedGamepads,self.UserInputService)
        if not padsOK or type(pads)~="table" then pads={Enum.UserInputType.Gamepad1} end
        for index,pad in ipairs(pads) do
            if index>8 then break end
            local padOK,padHeld=pcall(self.UserInputService.IsGamepadButtonDown,self.UserInputService,
                pad,Enum.KeyCode.ButtonR2)
            if padOK and padHeld==true then s.r2Held=true;break end
        end
        s.attackHeld=s.mouseHeld or s.r2Held
        local velocity = root.AssemblyLinearVelocity
        s.moving = hum.MoveDirection.Magnitude > .13 or Vector3.new(velocity.X,0,velocity.Z).Magnitude >= 2
        local clamp = char:FindFirstChild("FeralClamp")
        s.holding = clamp ~= nil and clamp:IsA("ObjectValue") and clamp.Value ~= nil
            or self:attribute(char,"FeralCarcassCarry") == true
        s.talonLock=self:attribute(char,"FeralTalonLock")
        s.diveLock=self:attribute(char,"FeralDiveLocal")
        s.ability = self:attribute(char,"FeralCrushAt")~=nil and self:attribute(char,"FeralCrushAt")~=false
            or self:attribute(char,"FeralDeathRollLocal") == true
            or self:attribute(char,"FeralDowned") == true
            or self:attribute(char,"FeralRolling") == true
            or s.talonLock~=nil or s.diveLock~=nil
            or self:attribute(char,"FeralDiveBomb") == true
            or self:attribute(char,"FeralVenomDown") == true
            or self:attribute(char,"FeralTumbleAt") ~= nil
            or s.protectedInteraction~=nil
            or self:attribute(char,"FeralPrideTaken")~=nil and self:attribute(char,"FeralPrideTaken")~=false
        if waterNeeded then
            s.swimming,s.underwater,s.surface,s.depth = self:water(char,hum,root)
        else
            s.swimming = self:attribute(char,"FeralSwimLocal") == true
                or hum:GetState() == Enum.HumanoidStateType.Swimming or hum.FloorMaterial == Enum.Material.Water
            s.underwater = self:attribute(char,"FeralUnderwater") == true or s.diving
        end
        s.locomotion = s.underwater and "UNDERWATER" or s.flying and "FLIGHT"
            or s.climbing and "CLIMB" or s.swimming and "SWIM" or s.burst and "BURST" or "LAND"
        return s
    end
    local function knownPack(v)
        if type(v) == "number" then return v > 0 and tostring(v) or nil end
        if type(v) == "string" and v ~= "" and v ~= "0" and v ~= "None" and v ~= "nil" then return v end
        return nil
    end
    function b:litterRecord(char)
        local record = self.litterByBody and self.litterByBody[char]
        local body = record and record.Parent and record:FindFirstChild("Body")
        if body and body:IsA("ObjectValue") and body.Value == char and self:attribute(record,"Alive") == true then return record end
        return nil
    end
    function b:refreshLitter()
        local map = {}
        local folder = self.ReplicatedStorage:FindFirstChild("FeralLitter")
        if folder then
            for index,record in ipairs(folder:GetChildren()) do
                if index > 256 then break end
                local body = record:FindFirstChild("Body")
                local char = body and body:IsA("ObjectValue") and body.Value
                if char and char:IsA("Model") and char.Parent and self:attribute(record,"Alive") == true then map[char] = record end
            end
        end
        self.litterByBody = map
        return map
    end
    function b:packFor(char,owner)
        local record = self:litterRecord(char)
        return knownPack(self:attribute(owner,"FeralPack")) or knownPack(self:attribute(char,"FeralPack"))
            or knownPack(self:attribute(record,"Pack"))
    end
    function b:affiliation(other, char)
        local own = self:packFor(self.player.Character,self.player)
        local theirs = self:packFor(char,other or (char and self.Players:GetPlayerFromCharacter(char)))
        return own and theirs and (own == theirs and "same" or "other") or "unknown"
    end
    function b:targetBlocker(char,owner)
        if not char or not char.Parent or self:attribute(char,"FeralDead") == true then return "target unavailable" end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then return "target unavailable" end
        if char:FindFirstChildOfClass("ForceField") then return "protected target" end
        local safe,now = self:attribute(char,"FeralSafeUntil"),self:serverNow()
        if safe~=nil and not Core.finite(safe) then return "protection timing unknown" end
        if Core.finite(safe) and (not now or safe > now) then return "spawn protection" end
        owner = owner or self.Players:GetPlayerFromCharacter(char)
        if self:attribute(owner,"FeralTut") == true or self:attribute(owner,"FeralTutorial") == true then return "tutorial protection" end
        local tutorial = self:attribute(char,"TutorialOwner")
        if tutorial ~= nil and tutorial ~= self.player.UserId then return "another tutorial target" end
        if self:attribute(char,"FeralBurrowed") == true then return "burrowed target" end
        return nil
    end
    function b:combatEligible(char)
        return char ~= self.player.Character and not self:targetBlocker(char)
            and self:affiliation(nil,char) ~= "same"
    end
    function b:sameTree(a,c)
        if not self:isClimbing(a) or not self:isClimbing(c) then return false end
        local axisA,axisB = self:attribute(a,"FeralClimbAxis"),self:attribute(c,"FeralClimbAxis")
        return typeof(axisA) == "Vector3" and typeof(axisB) == "Vector3" and (axisA-axisB).Magnitude < 5
    end
    function b:currentTargetBody(target)
        if not target or not target.char or target.char==self.player.Character or not target.char.Parent
            or not target.root or not target.hum
            or target.root.Parent~=target.char or target.hum.Parent~=target.char
            or target.hum.Health<=0 then return false end
        if target.player and target.player.Character~=target.char then return false end
        return target.char:FindFirstChild("HumanoidRootPart")==target.root
            and target.char:FindFirstChildOfClass("Humanoid")==target.hum
    end
    function b:clearCombatTargets()
        self.reachTarget,self.treeTarget=nil,nil
        self.allCandidates,self.tracked={},{}
        self.replicatedCount,self.packNPCCount=0,0
    end
    function b:retireCombatTarget(target)
        if self.reachTarget==target then self.reachTarget=nil end
        if self.treeTarget==target then self.treeTarget=nil end
    end
    function b:candidates(s, range,visual)
        local all,seen = {},{}
        if not s.alive then
            if visual~=false then self:clearCombatTargets() end
            return all
        end
        local litter = self:refreshLitter()
        local function add(char,other,npc)
            if not char or char == s.char or not char.Parent or seen[char] then return end
            local owner = self.Players:GetPlayerFromCharacter(char)
            if owner == self.player then return end
            local root,hum = char:FindFirstChild("HumanoidRootPart"),char:FindFirstChildOfClass("Humanoid")
            if not root or not hum or hum.Health <= 0 then return end
            local delta = root.Position-s.root.Position
            local distance = delta.Magnitude
            if distance > range then return end
            local record = litter[char]
            seen[char] = true
            table.insert(all,{ char = char, root = root, hum = hum, player = owner, npc = owner == nil,
                litter = owner == nil and record or nil,
                name = owner and owner.DisplayName or self:attribute(record,"Name") or self:attribute(char,"FeralName") or char.Name,
                distance = distance,affiliation = self:affiliation(owner,char), flat = Vector3.new(delta.X,0,delta.Z),
                sameTree = self:sameTree(s.char,char),
                protected = self:targetBlocker(char,owner) ~= nil })
        end
        for _, other in ipairs(self.Players:GetPlayers()) do
            if other ~= self.player then add(other.Character,other,false) end
        end
        local folder = self.Workspace:FindFirstChild("FeralNPCs")
        if folder then
            for i, char in ipairs(folder:GetChildren()) do
                if i > 256 then break end
                if char:IsA("Model") then add(char,nil,true) end
            end
        end
        for char in pairs(litter) do add(char,nil,true) end
        table.sort(all,function(a,c) return a.distance < c.distance end)
        local tracked,players,playerCount,npcCount = {},0,0,0
        for _,target in ipairs(all) do
            if target.player then
                playerCount += 1
                if players < 24 then table.insert(tracked,target);players += 1 end
            elseif target.litter or self:packFor(target.char) then
                npcCount += 1
            end
        end
        if visual ~= false then
            self.tracked,self.replicatedCount,self.packNPCCount = tracked,playerCount,npcCount
            self.allCandidates=all
        end
        return all
    end
    function b:carrying(s,target)
        local clamp=s.char and s.char:FindFirstChild("FeralClamp")
        local value=clamp and clamp:IsA("ObjectValue") and clamp.Value
        return value ~= nil and (value==target or value:IsDescendantOf(target)) and self:attribute(clamp,"Carry")==true
    end
    function b:carryEligible(s,target)
        if not s.alive or not target or not target.char.Parent or not target.root.Parent or target.hum.Health<=0
            or self:attribute(target.char,"FeralCarried")==true or self:attribute(target.char,"FeralDragged")==true
            or self:affiliation(target.player,target.char)=="other" then return false end
        local cfg,species,abilities=self:config("CarryConfig"),self:config("Species"),self:config("AbilityConfig")
        if not cfg or cfg.ENABLED~=true or not Core.finite(cfg.REACH) or type(cfg.canCarry)~="function" or not species or not abilities then return false end
        local diff=target.root.Position-s.root.Position
        local reach=1.5+cfg.REACH*(s.root.Size.Z+target.root.Size.Z)
        local flat=Vector3.new(diff.X,0,diff.Z)
        local look=s.root.CFrame.LookVector;look=Vector3.new(look.X,0,look.Z)
        if diff.Magnitude>reach or flat.Magnitude>.1 and look.Magnitude>.1 and look.Unit:Dot(flat.Unit)<.2 then return false end
        local ok,can=pcall(cfg.canCarry,species,abilities,s.char,target.char)
        return ok and can==true
    end
    function b:waterCub(s)
        local best
        for _,target in ipairs(self:candidates(s,35,false)) do
            if self:carryEligible(s,target) then
                local swim,_,_,depth=self:water(target.char,target.hum,target.root)
                if (swim or depth and depth>=-.25) and (not best or target.distance<best.distance) then best=target end
            end
        end
        return best
    end
    function b:carryWaterAllowed(s)
        local swim,under,_,depth=self:water(s.char,s.hum,s.root)
        if not swim and not under and (not depth or depth<-.25) then return true end
        local cfg=self:config("CarryConfig")
        return cfg and type(cfg.WATER_OK)=="table" and cfg.WATER_OK[self:attribute(s.char,"Species")]==true or false
    end
    function b:geometry(values,s,target)
        if type(values)~="table" or not s or not s.alive or not s.root or not s.hum
            or not s.root.Parent or not s.hum.Parent or not target or not target.root or not target.hum then return nil end
        if s.char and (s.root.Parent~=s.char or s.hum.Parent~=s.char) then return nil end
        if not target.root.Parent or not target.hum.Parent or target.hum.Health <= 0
            or target.char and (target.root.Parent~=target.char or target.hum.Parent~=target.char) then return nil end
        for _,key in ipairs({"REACH","HIT_SCALE","CONE","SLACK","MAX_DY"}) do
            if not Core.finite(values[key]) then return nil end
        end
        if values.REACH<=0 or values.HIT_SCALE<=0 or values.MAX_DY<=0
            or not Core.finite(s.hum.HipHeight) or not Core.finite(target.hum.HipHeight) then return nil end
        local diff = target.root.Position-s.root.Position
        if not Core.finite(diff.X) or not Core.finite(diff.Y) or not Core.finite(diff.Z) then return nil end
        local flat = Vector3.new(diff.X,0,diff.Z)
        local fwd = s.root.CFrame.LookVector
        fwd = Vector3.new(fwd.X,0,fwd.Z)
        if fwd.Magnitude < .01 then return nil end
        if type(values.biteLook) == "function" then
            local ok,v = pcall(values.biteLook,s.char,fwd.Unit)
            if ok and typeof(v) == "Vector3" then fwd = Vector3.new(v.X,0,v.Z) end
        end
        if fwd.Magnitude < .01 then return nil end
        local ok,gap = pcall(values.bodyGap,target.root,flat)
        if not ok or not Core.finite(gap) then return nil end
        local function modifier(key, default)
            if type(values[key]) ~= "function" then return default end
            local good,v = pcall(values[key],s.char)
            return good and Core.finite(v) and v or default
        end
        local box = self:attribute(s.root,"FeralBoxFull")
        if not Core.finite(box) or box <= 0 then box = s.root.Size.Z end
        local reach = (box*.5+s.hum.HipHeight*values.REACH+values.SLACK)*values.HIT_SCALE*modifier("reachMult",1)
        local angle = flat.Magnitude > .01 and fwd.Unit:Dot(flat.Unit) or 1
        local cone = modifier("coneFor",values.CONE)
        local height = math.abs(target.root.Position.Y-s.root.Position.Y)
        local vertical = (s.hum.HipHeight+target.hum.HipHeight)*values.MAX_DY*modifier("dyMult",1)
        return { valid = gap < reach and angle > math.cos(math.rad(cone)) and height < vertical,
            withinBodyRange = gap < reach and height < vertical,
            gap = gap, reach = reach, angle = angle, cone = cone, height = height, vertical = vertical,
            distance = diff.Magnitude,score = gap-angle*2 }
    end
    function b:occluded(s,target)
        if not s or not s.root or not target or not target.root or not target.char then return true,false end
        local params = RaycastParams.new()
        params.FilterType,params.FilterDescendantsInstances = Enum.RaycastFilterType.Exclude,{s.char}
        params.IgnoreWater = true
        local ok,hit=pcall(self.Workspace.Raycast,self.Workspace,s.root.Position,target.root.Position-s.root.Position,params)
        -- Missing scene evidence must not turn into a false clear-hit cue or
        -- shut down all other features because one streamed query failed.
        if not ok then return true,false end
        return hit ~= nil and (not hit.Instance or not hit.Instance:IsDescendantOf(target.char)),true
    end
    function b:imminentBiteTarget(s,stock,all)
        -- Release automatic Rest *before* contact, when a real eligible target
        -- is either within normal bite reach or the animal is closing on it.
        -- This does not claim extra hit range or force an attack.
        if not s or not s.alive or not stock or not s.root or not s.hum then return nil end
        local movement=s.hum.MoveDirection
        local velocity=s.root.AssemblyLinearVelocity
        local horizontal=Vector3.new(velocity.X,0,velocity.Z)
        local speed=math.max(18,horizontal.Magnitude)
        local anticipate=math.clamp(self:restLock(s.char)*speed+3,6,22)
        local checked=0
        for _,target in ipairs(all or {}) do
            if target.distance>32 then break end
            if target.affiliation~="same" and not target.protected
                and self:combatEligible(target.char) and target.root and target.root.Parent then
                checked+=1
                if checked>10 then break end
                local geometric=self:geometry(stock,s,target)
                if geometric then
                    local diff=target.root.Position-s.root.Position
                    local horizontalDiff=Vector3.new(diff.X,0,diff.Z)
                    local closing=movement.Magnitude>.13 and horizontalDiff.Magnitude>.1
                        and movement.Unit:Dot(horizontalDiff.Unit)>.25
                    local allowance=closing and anticipate or 3
                    local vertical=math.abs(diff.Y)
                    local verticalLimit=geometric.vertical+2
                    if geometric.gap <= geometric.reach+allowance
                        and vertical<=verticalLimit and (target.sameTree or not self:occluded(s,target)) then
                        return target
                    end
                end
            end
        end
        return nil
    end
    function b:leadPoint(s,target)
        local point=target.root.Position
        local a,bv=target.root.AssemblyLinearVelocity,s.root.AssemblyLinearVelocity
        if typeof(a)~="Vector3" or typeof(bv)~="Vector3" then return point end
        -- A one-frame velocity replication spike can steer the bite beyond
        -- the current hitbox. Reduce the speculative lead on fast movement.
        local lead=(a-bv)*math.min(.20,self:biteDelay(s.char))
        lead=Vector3.new(lead.X,0,lead.Z)
        if not Core.finite(lead.Magnitude) then return point end
        if lead.Magnitude>2.25 then lead=lead.Unit*2.25 end
        return point+lead
    end
    function b:autoAttackTarget(s,guide,values)
        if not guide or guide.invalid or not guide.target or not s.alive then return false end
        local target=guide.target
        if not self:currentTargetBody(target) or (target.root.Position-s.root.Position).Magnitude>45
            or not self:combatEligible(target.char) then return false end
        local geometry=self:geometry(values,s,target)
        if not geometry or not geometry.valid or self:occluded(s,target) then return false end
        -- Stock-valid auto hits take priority. Extended-only contacts can
        -- still be probed, but not spammed during repeated no-reply windows.
        local base
        if self.originalAutoCombat then
            -- An out-of-range animal must not inherit a stale green guide
            -- from the preceding scan when deciding whether to auto-bite.
            base=self:geometry(self.originalAutoCombat,s,target)
        else
            base=guide.baseline
        end
        if base and base.valid then return true end
        local entry=self.extendedConfidence and self.extendedConfidence[target.char]
        return not entry or (s.now or 0)>=(entry.waitUntil or 0)
    end
    function b:select(s, baseline, changed, all)
        local previousAssist=self.reachTarget
        self.treeTarget = nil
        self.reachTarget = nil
        local best,score = nil,math.huge
        local eligible={}
        for _, target in ipairs(all) do
            if target.distance <= 45 and self:currentTargetBody(target) and self:combatEligible(target.char) then
                table.insert(eligible,target)
                if target.sameTree and (not self.treeTarget or target.distance < self.treeTarget.distance) then self.treeTarget = target end
            end
        end
        local assisted,assistScore = nil,math.huge
        local visibility,visibilityKnown={},{}
        local rays=0
        local function obstruction(target)
            if visibility[target]==nil then
                if rays>=12 then
                    visibility[target],visibilityKnown[target]=true,false
                else
                    rays+=1
                    local blocked,known=self:occluded(s,target)
                    visibility[target],visibilityKnown[target]=blocked,known~=false
                end
            end
            return visibility[target]
        end
        local selectionModel = table.clone(changed)
        selectionModel.biteLook = baseline.biteLook
        self.originalAutoCombat=baseline
        for _,target in ipairs(eligible) do
                local geometry = self:geometry(selectionModel,s,target)
                if geometry and geometry.withinBodyRange then
                    local stock = self:geometry(baseline,s,target)
                    local rank = target.distance+(target.affiliation == "unknown" and .5 or 0)
                        -(stock and stock.valid and .75 or 0)
                    if previousAssist and previousAssist.char==target.char then rank-=.65 end
                    if rank < assistScore and not obstruction(target) then
                        assisted,assistScore = target,rank
                    end
                end
        end
        self.reachTarget = assisted
        for _, target in ipairs(eligible) do
                local base = self:geometry(baseline,s,target)
                local extended = self:geometry(changed,s,target)
                if base or extended then
                    local blocked=target.protected or obstruction(target)
                    -- A clear stock-valid candidate outranks a speculative
                    -- extended-only target. Never prefer a wall over a
                    -- nearby unobstructed animal.
                    -- Stock validity comes from the unmodified biteLook.
                    -- Calculate its tier BEFORE the extended geometry score:
                    -- the latter depends on the currently assisted aim target
                    -- and otherwise creates a feedback loop favouring ghosts.
                    local stockValid=base and base.valid
                    local extendedValid=extended and extended.valid
                    local tier=stockValid and 0 or extendedValid and 100 or 2000
                    local scoreValue=stockValid and base.score
                        or extended and extended.score or 1000
                    local rank=tier+scoreValue+(blocked and 4000 or 0)
                    if rank<score then
                        best,score={
                            target=target,baseline=base,extended=extended,obstruction=blocked,
                        },rank
                    end
                end
        end
        if best then
            best.blocked=best.obstruction
            best.obstructionKnown=visibilityKnown[best.target]~=false
            -- Native biteLook must prefer the same stock-clear target the
            -- guide displays. Extended-only rear/tree aim retains the
            -- existing sticky assist until a stock-valid option appears.
            if best.baseline and best.baseline.valid and not best.blocked then
                self.reachTarget=best.target
            end
        end
        return best
    end
    function b:refreshGuide(s,baseline,changed,guide)
        local target=guide.target
        if not s.alive or s.char~=self.player.Character or not self:currentTargetBody(target)
            or not self:combatEligible(target.char) then
            self:retireCombatTarget(target)
            guide.blocked,guide.invalid=true,true;return
        end
        guide.invalid=false
        guide.baseline=self:geometry(baseline,s,target)
        guide.extended=self:geometry(changed,s,target)
        -- A guide tracks the current selected body every frame. Target search
        -- and obstacle queries remain bounded background work.
        guide.blocked=guide.obstruction or not guide.extended or not guide.extended.valid
    end
    function b:friendlyCarry(s)
        if not s.carried or s.pinned then return false end
        local growth = self:attribute(s.char,"Growth")
        local species = self:attribute(s.char,"Species")
        if not Core.finite(growth) or growth > .34 or type(species) ~= "string" then return false end
        for _, other in ipairs(self.Players:GetPlayers()) do
            local adult = other.Character
            local ag = self:attribute(adult,"Growth")
            if adult ~= s.char and Core.finite(ag) and ag >= .67 and self:attribute(adult,"Species") == species then
                for _, name in ipairs({"FeralClamp","FeralClampLocal"}) do
                    local clamp = adult and adult:FindFirstChild(name)
                    if clamp and clamp:IsA("ObjectValue") then
                        local target = clamp.Value
                        if target and (target == s.char or target:IsDescendantOf(s.char)) then return true end
                    end
                end
            end
        end
        return false
    end
    function b:escapeAction(s)
        if not s.alive or self:friendlyCarry(s) then return nil,"friendly carry or no animal" end
        if s.holding and not s.captured then return nil,"carrying prey" end
        local clamp = self:attribute(s.char,"FeralClampN") or self:attribute(s.char,"FeralClampGame")
        local need = self:attribute(s.char,"FeralShakeNeed")
        local cue = s.captured or (Core.finite(clamp) and clamp > 0) or (Core.finite(need) and need > 0)
        if not cue then return nil,"watching native capture cues" end
        if s.carried then return "getoff","carried",.435 end
        local bindings = self.ContextActionService:GetAllBoundActionInfo()
        if bindings.FeralTugTap then return "shake","native tug",.12 end
        if bindings.FeralShakeTaps or bindings.FeralShakeMash then return "shake","native shake",.17 end
        return nil,"captured; no native escape binding"
    end
    function b:nearbyDanger(s)
        if not s.root then return true end
        local params = OverlapParams.new()
        params.FilterType,params.FilterDescendantsInstances = Enum.RaycastFilterType.Exclude,{s.char}
        params.MaxParts = 200
        local parts = self.Workspace:GetPartBoundsInRadius(s.root.Position,28,params)
        if #parts >= 200 then return true end
        for _, part in ipairs(parts) do
            local model = part:FindFirstAncestorOfClass("Model")
            local hum = model and model:FindFirstChildOfClass("Humanoid")
            if model ~= s.char and hum and hum.Health > 0 then return true end
        end
        return false
    end
    function b:safeStep(s, anchor)
        local config = self:config("SurvivalConfig")
        local threshold = config and config.AFK_MOVE
        if not Core.finite(threshold) or threshold < 0 or threshold+2 > 8 then return nil end
        local step = threshold+2
        local root = s.root
        local params = RaycastParams.new()
        params.FilterType,params.FilterDescendantsInstances = Enum.RaycastFilterType.Exclude,{s.char}
        params.IgnoreWater = false
        local function ground(at)
            local hit = self.Workspace:Raycast(at+Vector3.new(0,8,0),Vector3.new(0,-35,0),params)
            return hit and hit.Material ~= Enum.Material.Water and hit.Normal.Y > .86 and hit.Position or nil
        end
        local start = ground(root.Position)
        if not start then return nil end
        local forward = root.CFrame.LookVector
        forward = Vector3.new(forward.X,0,forward.Z)
        if forward.Magnitude < .01 then return nil end
        forward = forward.Unit
        local side = Vector3.new(-forward.Z,0,forward.X)
        local goals = { root.Position+side*step,root.Position-side*step,root.Position+forward*step,root.Position-forward*step }
        if anchor and (root.Position-anchor).Magnitude > threshold+.2 then goals = {anchor} end
        for _, goal in ipairs(goals) do
            local vector = goal-root.Position
            vector = Vector3.new(vector.X,0,vector.Z)
            if vector.Magnitude > threshold+.5 and vector.Magnitude <= 8 then
                local safe = true
                for distance = 0,vector.Magnitude+1.25,1 do
                    local point = ground(root.Position+vector.Unit*distance)
                    if not point or math.abs(point.Y-start.Y) > 1.1 then safe = false; break end
                end
                if safe and not self.Workspace:Raycast(root.Position+Vector3.new(0,1,0),vector,params) then
                    local ending = ground(goal)
                    if ending then return Vector3.new(goal.X,root.Position.Y+ending.Y-start.Y,goal.Z) end
                end
            end
        end
        return nil
    end
    function b:routeSafe(s,goal)
        if not s.alive or not goal or s.hum.FloorMaterial==Enum.Material.Air
            or s.hum.FloorMaterial==Enum.Material.Water then return false end
        local vector=goal-s.root.Position
        vector=Vector3.new(vector.X,0,vector.Z)
        if vector.Magnitude>8.1 then return false end
        if vector.Magnitude<.05 then return true end
        local params=RaycastParams.new()
        params.FilterType,params.FilterDescendantsInstances=Enum.RaycastFilterType.Exclude,{s.char}
        params.IgnoreWater=false
        local groundY
        for distance=0,vector.Magnitude+1.25,1 do
            local point=s.root.Position+vector.Unit*distance
            local hit=self.Workspace:Raycast(point+Vector3.new(0,8,0),Vector3.new(0,-35,0),params)
            if not hit or hit.Material==Enum.Material.Water or hit.Normal.Y<=.86 then return false end
            groundY=groundY or hit.Position.Y
            if math.abs(hit.Position.Y-groundY)>1.1 then return false end
        end
        return self.Workspace:Raycast(s.root.Position+Vector3.new(0,1,0),vector,params)==nil
    end
    function b:walk(s,goal)
        if s.char ~= self.player.Character or not s.hum or not s.root then return false end
        s.hum:MoveTo(goal or s.root.Position)
        return true
    end
    function b:pulseIdle()
        local ok = pcall(function()
            local v = game:GetService("VirtualUser")
            v:CaptureController()
            v:ClickButton2(Vector2.new(0,0))
        end)
        return ok
    end
    function b:attach(hub,scope)
        scope:add(function() self:releaseSyntheticBite() end)
        local function connect(signal,fn)
            local c = signal:Connect(function(...)
                if hub.active and not hub.closed then fn(...) end
            end)
            scope:add(function() c:Disconnect() end)
            return c
        end
        local function character(char)
            if self.characterScope then self.characterScope:close() end
            self.characterScope = Core.scope()
            self.generation += 1
            self.character = char
            hub:characterChanged(self.generation)
            if not char then return end
            for _, key in ipairs({"WolfRest","WolfBiteAt","WolfFeed","FeralPinned","FeralCarried",
                "FeralDragged","FeralTalonLock","FeralDiveLocal","FeralDeathRollLocal","FeralRolling",
                "FeralDowned","FeralVenomDown","FeralTumbleAt","FeralCrushAt","FeralCrushBiteAt","FeralClimbLocal","FeralFlyLocal",
                "FeralUnderwater","FeralDiving","FeralSwimLocal","FeralWrestle",
                "FeralPrideTaken","FeralSrvTired","FeralNoSprint"}) do
                local c = char:GetAttributeChangedSignal(key):Connect(function()
                    if hub.active and not hub.closed and char == self.player.Character then hub:nativeAttribute(key) end
                end)
                self.characterScope:add(function() c:Disconnect() end)
            end
        end
        self.bindCharacter = character
        scope:add(function() if self.characterScope then self.characterScope:close() end end)
        connect(self.player.CharacterAdded,character)
        connect(self.player.CharacterRemoving,function() character(nil) end)
        connect(self.player.Idled,function() hub:idle() end)
        connect(self.player:GetAttributeChangedSignal("FeralPanelHold"),function() hub:nativeAttribute("FeralPanelHold") end)
        connect(self.player:GetAttributeChangedSignal("FeralRestTap"),function()
            if self.UserInputService:GetFocusedTextBox() then return end
            local now=self.clock()
            hub.policy:input("rest",now)
            hub.recovery:manual(now)
            hub.combatInput:cancel();hub.feeding:cancel("manual rest control",now);hub.rescue:cancel()
        end)
        connect(self.UserInputService.InputBegan,function(input,processed) hub:input(input,processed) end)
        connect(self.UserInputService.InputEnded,function(input) hub:inputEnded(input) end)
        if self.UserInputService.WindowFocusReleased then
            connect(self.UserInputService.WindowFocusReleased,function() hub:focusChanged(false) end)
        end
        if self.UserInputService.WindowFocused then
            connect(self.UserInputService.WindowFocused,function() hub:focusChanged(true) end)
        end
        connect(self.UserInputService.InputChanged,function(input)
            local kind = input.UserInputType
            if kind == Enum.UserInputType.MouseMovement or kind == Enum.UserInputType.MouseWheel
                or kind == Enum.UserInputType.Touch then hub:physicalInput(kind == Enum.UserInputType.MouseMovement and "mouse" or "other") end
        end)
        local actionName = "FERAL_RENAISSANCE_" .. tostring(hub.token)
        -- CAS can consume event-driven sprint bindings. Native IsKeyDown
        -- polling can still see Right Shift; this limitation is recorded.
        self.ContextActionService:BindActionAtPriority(actionName,function(_,state,input)
            if not hub.active or hub.closed or self.UserInputService:GetFocusedTextBox() then return Enum.ContextActionResult.Pass end
            if input.KeyCode == Enum.KeyCode.RightShift then
                if state == Enum.UserInputState.Begin then hub.ui:toggle() end
                return Enum.ContextActionResult.Sink
            end
            if state == Enum.UserInputState.Begin and input.KeyCode == Enum.KeyCode.G and hub:carryInput(input) then
                return Enum.ContextActionResult.Sink
            end
            if state == Enum.UserInputState.Begin then hub:preInput(input) end
            return Enum.ContextActionResult.Pass
        end,false,4000,Enum.KeyCode.RightShift,Enum.KeyCode.R,Enum.KeyCode.ButtonY,Enum.KeyCode.Z,Enum.KeyCode.X,
            Enum.KeyCode.E,Enum.KeyCode.F,Enum.KeyCode.G,
            Enum.KeyCode.Q,Enum.KeyCode.Space,Enum.KeyCode.ButtonR2,Enum.KeyCode.ButtonB,
            Enum.UserInputType.MouseButton1,Enum.UserInputType.MouseButton2)
        scope:add(function() self.ContextActionService:UnbindAction(actionName) end)
        connect(self.UserInputService.JumpRequest,function() hub:requestFlight() end)
        connect(self.RunService.Heartbeat,function(dt)
            local ok,err = pcall(hub.tick,hub,dt)
            if not ok then hub:fault(err) end
        end)
        local renderName = actionName .. "_RENDER"
        self.RunService:BindToRenderStep(renderName,Enum.RenderPriority.Camera.Value+3,function(dt)
            if hub.active and not hub.closed then
                local ok,err = pcall(hub.render,hub,dt)
                if not ok then hub:fault(err) end
            end
        end)
        scope:add(function() self.RunService:UnbindFromRenderStep(renderName) end)
        if self.RunService.PreAnimation then
            connect(self.RunService.PreAnimation,function() hub:maskPose() end)
        end
        scope:add(function()
            for _, item in pairs(self.remoteConnections) do item.connection:Disconnect() end
            table.clear(self.remoteConnections)
        end)
    end
    function b:bindNative(hub)
        for _, item in ipairs({{"FeralGrabV2","grab"},{"FeralHit","feedback"},{"FeralHippo","hippo"},{"WolfActions","actions"},
            {"FeralBiteLocal","biteLocal","BindableEvent"}}) do
            local remote = self.ReplicatedStorage:FindFirstChild(item[1])
            local old = self.remoteConnections[item[1]]
            if old and (old.remote ~= remote or old.connection.Connected==false) then
                old.connection:Disconnect(); self.remoteConnections[item[1]] = nil; old = nil
            end
            if remote and remote:IsA(item[3] or "RemoteEvent") and not old then
                local kind,name = item[2],item[1]
                local signal = item[3] == "BindableEvent" and remote.Event or remote.OnClientEvent
                local c = signal:Connect(function(...)
                    if hub.active and not hub.closed and self.ReplicatedStorage:FindFirstChild(name)==remote then
                        hub:nativeEvent(kind,...)
                    end
                end)
                self.remoteConnections[item[1]] = { remote = remote,connection = c }
            end
        end
    end
    return b
end
return Roblox
]============]
sources["zoom"] = [============[
-- Expand the normal camera's zoom range without replacing its controller.
local Zoom = {}
local fields = {"CameraMaxZoomDistance", "CameraMinZoomDistance", "CameraMode"}
function Zoom.new(player)
    local z = {player=player,active=false,applied=false,connections={},reason="OFF"}
    local desired = {CameraMaxZoomDistance=100000,CameraMinZoomDistance=.5,CameraMode=Enum.CameraMode.Classic}
    function z:apply()
        if not self.active or self.writing then return self.applied end
        self.writing=true
        local ok=pcall(function()
            for _,key in ipairs(fields) do
                if player[key]~=desired[key] then player[key]=desired[key] end
            end
            for _,key in ipairs(fields) do assert(player[key]==desired[key],"Camera limit rejected") end
        end)
        self.writing=false;self.applied=ok
        if not ok then
            -- A rejected second property must not leave the first expanded or
            -- retain observers on a half-applied camera lease.
            self:close()
        end
        self.reason=ok and "Mouse-wheel zoom · 0.5–100,000 studs" or "Camera limits unavailable or rejected"
        return ok
    end
    function z:close()
        self.active=false;self.applied=false
        for _,c in ipairs(self.connections) do pcall(c.Disconnect,c) end
        self.connections={}
        local before=self.before;self.before=nil
        if before then
            -- Restore only values still owned by us. Min first keeps the
            -- original min/max pair valid when returning from the wider range.
            for _,key in ipairs({"CameraMinZoomDistance","CameraMaxZoomDistance","CameraMode"}) do
                pcall(function()if player[key]==desired[key] then player[key]=before[key] end end)
            end
        end
        self.reason="OFF"
    end
    function z:set(on)
        if not on then
            if self.active then self:close() end
            return false
        end
        if not self.active then
            local before={}
            local ok=pcall(function()
                before.CameraMaxZoomDistance=player.CameraMaxZoomDistance
                before.CameraMinZoomDistance=player.CameraMinZoomDistance
                before.CameraMode=player.CameraMode
                assert(type(before.CameraMaxZoomDistance)=="number" and type(before.CameraMinZoomDistance)=="number"
                    and before.CameraMode~=nil,"Camera properties unavailable")
            end)
            if not ok then self.reason="Camera properties unavailable";return false end
            self.before=before;self.active=true
            local attached=pcall(function()
                for _,key in ipairs(fields) do
                    local c=player:GetPropertyChangedSignal(key):Connect(function()
                        if not self.active or self.writing then return end
                        local current=player[key]
                        if current~=desired[key] then
                            -- A respawn/species script can publish new defaults.
                            -- Remember those for OFF/unload instead of stale ones.
                            self.before[key]=current
                            self:apply()
                        end
                    end)
                    table.insert(self.connections,c)
                end
            end)
            if not attached then self:close();self.reason="Camera observation unavailable";return false end
        end
        return self:apply()
    end
    return z
end
return Zoom
]============]
sources["voice"] = [============[
-- Optional hearing assistance for the default Roblox Audio API voice graph.
-- This module never touches the microphone, chat controls, voice permissions,
-- voice wires, remotes, player positions or any combat/minigame subsystem.
local Voice = {}

local function finite(x)
    return type(x)=="number" and x==x and x>=0 and x<1e8
end
function Voice.cloneCurve(curve)
    if type(curve)~="table" then return nil end
    local out,n={},0
    for distance,volume in pairs(curve) do
        if not finite(distance) or not finite(volume) or volume>1 then return nil end
        out[distance]=volume
        n+=1
        if n>400 then return nil end
    end
    return n>0 and out or nil
end
function Voice.scaleCurve(curve,scale)
    if not finite(scale) or scale<1 or scale>1.5 then return nil end
    local source=Voice.cloneCurve(curve)
    if not source then return nil end
    local out={}
    for distance,volume in pairs(source) do
        local farther=distance==0 and 0 or math.floor(distance*scale*10000+.5)/10000
        if out[farther]~=nil then return nil end
        out[farther]=volume
    end
    return out
end
function Voice.sameCurve(a,b)
    if type(a)~="table" or type(b)~="table" then return false end
    local left,right=0,0
    for distance,volume in pairs(a) do
        left+=1
        if not finite(distance) or not finite(volume)
            or not finite(b[distance]) or math.abs(volume-b[distance])>.0001 then return false end
    end
    for _ in pairs(b) do right+=1 end
    return left==right
end

function Voice.new(players,localPlayer)
    local v={players=players,localPlayer=localPlayer,closed=false,started=false,
        enabled=false,factor=1.25,records={},playerConns={},charConns={},
        characters={},connections={},skipped=0,conflicts=0}
    local function connect(bucket,signal,handler)
        if not signal then return end
        local ok,connection=pcall(function() return signal:Connect(handler) end)
        if ok and connection then table.insert(bucket,connection) end
    end
    local function disconnect(bucket)
        for i=#bucket,1,-1 do
            pcall(function() bucket[i]:Disconnect() end)
            bucket[i]=nil
        end
    end
    local function sameBounds(a,b)
        return a and b and finite(a.Min) and finite(a.Max)
            and finite(b.Min) and finite(b.Max)
            and math.abs(a.Min-b.Min)<.001 and math.abs(a.Max-b.Max)<.001
    end
    local function restore(emitter)
        local record=v.records[emitter]
        if not record then return end
        v.records[emitter]=nil
        local ok=pcall(function()
            -- Detachment is not destruction. Restore an owned curve even
            -- between parents so a later reattach cannot scale it twice.
            if emitter.DistanceAttenuationMode~=record.mode then
                v.conflicts+=1;return
            end
            if record.custom then
                if not Voice.sameCurve(emitter:GetDistanceAttenuation(),record.modified) then
                    v.conflicts+=1;return
                end
                emitter:SetDistanceAttenuation(record.original)
            else
                if not sameBounds(emitter.DistanceAttenuationBounds,record.modified) then
                    v.conflicts+=1;return
                end
                emitter.DistanceAttenuationBounds=record.original
            end
        end)
        if not ok then v.conflicts+=1 end
    end
    local function restorePlayer(remote)
        local found={}
        for emitter,record in pairs(v.records) do
            if record.player==remote then table.insert(found,emitter) end
        end
        for _,emitter in ipairs(found) do restore(emitter) end
    end
    local function apply(remote,emitter)
        if v.closed or not v.enabled or v.records[emitter] then return end
        -- Never alter an unrelated ambient sound or a user's own microphone.
        if remote==localPlayer or remote.Character~=emitter.Parent
            or not emitter:IsA("AudioEmitter") or emitter.Name~="AudioEmitter"
            or not remote:FindFirstChildOfClass("AudioDeviceInput") then return end
        local modeOK,mode=pcall(function() return emitter.DistanceAttenuationMode end)
        if not modeOK or mode==nil then v.skipped+=1;return end
        local custom=mode==Enum.DistanceAttenuationMode.Custom
        if custom then
            local ok,before=pcall(function() return emitter:GetDistanceAttenuation() end)
            local old=ok and Voice.cloneCurve(before) or nil
            -- Empty curves use Roblox's default inverse rolloff, which cannot
            -- be losslessly stretched. Do not replace it with a fabricated curve.
            local desired=old and Voice.scaleCurve(old,v.factor)
            if not desired then v.skipped+=1;return end
            local wrote=pcall(function() emitter:SetDistanceAttenuation(desired) end)
            local read,after=pcall(function() return emitter:GetDistanceAttenuation() end)
            if not wrote or not read or not Voice.sameCurve(after,desired) then
                v.skipped+=1
                if read and Voice.sameCurve(after,desired) then
                    pcall(function() emitter:SetDistanceAttenuation(old) end)
                end
                return
            end
            v.records[emitter]={player=remote,mode=mode,custom=true,original=old,modified=desired}
        else
            local ok,before=pcall(function() return emitter.DistanceAttenuationBounds end)
            if not ok or not before or not finite(before.Min) or not finite(before.Max)
                or before.Max<=before.Min then v.skipped+=1;return end
            local desired=NumberRange.new(before.Min*v.factor,before.Max*v.factor)
            local wrote=pcall(function() emitter.DistanceAttenuationBounds=desired end)
            local read,after=pcall(function() return emitter.DistanceAttenuationBounds end)
            if not wrote or not read or not sameBounds(after,desired) then
                v.skipped+=1
                -- A property setter can change the value before reporting a
                -- failure. Undo only the exact attempted value, just as the
                -- custom-curve path does, so OFF/unload cannot miss this write.
                if read and sameBounds(after,desired) then
                    pcall(function() emitter.DistanceAttenuationBounds=before end)
                end
                return
            end
            v.records[emitter]={player=remote,mode=mode,custom=false,original=before,modified=desired}
        end
    end
    local function scan(remote)
        if v.closed or not v.enabled or remote==localPlayer then return end
        local char=remote.Character
        if not char or not remote:FindFirstChildOfClass("AudioDeviceInput") then return end
        for _,child in ipairs(char:GetChildren()) do
            if child:IsA("AudioEmitter") then apply(remote,child) end
        end
    end
    local function detachCharacter(remote)
        local bucket=v.charConns[remote]
        if bucket then disconnect(bucket) end
        v.charConns[remote]=nil;v.characters[remote]=nil
        restorePlayer(remote)
    end
    local watchCharacter
    watchCharacter=function(remote,char)
        if v.characters[remote]==char then scan(remote);return end
        detachCharacter(remote)
        v.characters[remote]=char
        local bucket={}
        v.charConns[remote]=bucket
        connect(bucket,char.ChildAdded,function(child)
            if child:IsA("AudioEmitter") then apply(remote,child) end
        end)
        connect(bucket,char.ChildRemoved,function(child)
            if v.records[child] then restore(child) end
        end)
        scan(remote)
    end
    local function detachPlayer(remote)
        detachCharacter(remote)
        local bucket=v.playerConns[remote]
        if bucket then disconnect(bucket) end
        v.playerConns[remote]=nil
    end
    local function watchPlayer(remote)
        if remote==localPlayer or v.playerConns[remote] then return end
        local bucket={}
        v.playerConns[remote]=bucket
        connect(bucket,remote.CharacterAdded,function(char)
            if not v.closed then watchCharacter(remote,char) end
        end)
        connect(bucket,remote.CharacterRemoving,function()
            detachCharacter(remote)
        end)
        connect(bucket,remote.ChildAdded,function(child)
            if child:IsA("AudioDeviceInput") then scan(remote) end
        end)
        if remote.Character then watchCharacter(remote,remote.Character) end
    end

    function v:start()
        if self.started or self.closed then return end
        self.started=true
        connect(self.connections,players.PlayerAdded,function(remote)
            if not self.closed then watchPlayer(remote) end
        end)
        connect(self.connections,players.PlayerRemoving,function(remote)
            detachPlayer(remote)
        end)
        for _,remote in ipairs(players:GetPlayers()) do watchPlayer(remote) end
    end
    function v:setEnabled(on)
        if self.closed then return false end
        if not self.started then self:start() end
        self.enabled=on==true
        if self.enabled then
            for _,remote in ipairs(players:GetPlayers()) do
                watchPlayer(remote)
                if remote.Character then watchCharacter(remote,remote.Character) end
                scan(remote)
            end
        else
            local affected={}
            for emitter in pairs(self.records) do table.insert(affected,emitter) end
            for _,emitter in ipairs(affected) do restore(emitter) end
        end
        return true
    end
    function v:status()
        local adjusted=0
        for emitter in pairs(self.records) do
            if emitter.Parent then adjusted+=1 end
        end
        return {enabled=self.enabled,adjusted=adjusted,
            skipped=self.skipped,conflicts=self.conflicts}
    end
    function v:summary()
        if not self.enabled then return "Default hearing restored" end
        local status=self:status()
        if status.adjusted>0 then
            return "Local voice rolloff +25%; server hearing limit unchanged"
        end
        return "Waiting for compatible proximity voice audio; server limit unchanged"
    end
    function v:close()
        if self.closed then return end
        self:setEnabled(false)
        self.closed=true
        disconnect(self.connections)
        local peers={}
        for remote in pairs(self.playerConns) do table.insert(peers,remote) end
        for _,remote in ipairs(peers) do detachPlayer(remote) end
    end
    return v
end

return Voice
]============]
sources["test_features"] = [============[
-- Own-character diagnostics for every animal. Potassium's local file is
-- picked up by the separate private PC runner; this module has no network API.
local Tests = {}
local PATH = "FERAL_RENAISSANCE_TESTS_LATEST.json"
local LIMIT = 240
local SCHEMA = "FERAL_RENAISSANCE_TESTS_V1"

function Tests.new(Core,bridge,hub)
    local t = { active = false, closed = false, enabled = true, path = PATH,
        events = {}, samples = {}, species = {}, biteTimes = {}, biteCount = 0,
        dirty = true, saved = false, attempts = 0,
        nextSave = 0, nextSample = 0, notice = "Recording starts with the hub",
        characterScope = Core.scope() }
    local io = bridge:io()
    local function attr(char,key)
        if not char then return nil end
        local read,value=pcall(char.GetAttribute,char,key)
        return read and value or nil
    end
    local function finite(value)
        return Core.finite(value)
    end
    function t:snapshot()
        local char=bridge.player.Character
        local hum=char and char:FindFirstChildOfClass("Humanoid")
        local species=attr(char,"Species")
        local shell
        local config=bridge:config("CombatConfig")
        if char and config and type(config.shellMult)=="function" then
            local computed,value=pcall(config.shellMult,char)
            if computed and finite(value) then shell=value end
        end
        local current=hub.snapshot
        local combat
        if current and current.char==char and type(current.combat)=="boolean" then combat=current.combat end
        return {species=type(species)=="string" and #species<=31 and species:match("^[A-Za-z][A-Za-z0-9]*$") and species or "unknown",
            rest=attr(char,"WolfRest")==true,
            restAt=finite(attr(char,"WolfRestAt")) and attr(char,"WolfRestAt") or nil,
            hp=hum and finite(hum.Health) and hum.Health or nil,
            maxHP=hum and finite(hum.MaxHealth) and hum.MaxHealth or nil,
            safeUntil=finite(attr(char,"FeralSafeUntil")) and attr(char,"FeralSafeUntil") or nil,
            crushAt=finite(attr(char,"FeralCrushAt")) and attr(char,"FeralCrushAt") or nil,
            injury=current and current.char==char and finite(current.injury) and current.injury or nil,
            bleed=current and current.char==char and finite(current.bleed) and current.bleed or nil,
            venom=current and current.char==char and finite(current.venom) and current.venom or nil,
            stamina=current and current.char==char and finite(current.stamina) and current.stamina or nil,
            maxStamina=current and current.char==char and finite(current.maxStamina) and current.maxStamina or nil,
            hunger=current and current.char==char and fini