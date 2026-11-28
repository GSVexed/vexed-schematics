-- Experimental, own-character movement assistance. Native WolfMove can set
-- both speed and intent to zero while tired. Neither local request proves
-- server acceptance or other-client visibility.
local Endurance={}
local function horizontal(v)
    if not v then return nil end
    local x,z=v.X,v.Z
    if type(x)~="number" or type(z)~="number" or x~=x or z~=z
        or math.abs(x)>1e6 or math.abs(z)>1e6 then return nil end
    return math.sqrt(x*x+z*z)
end
function Endurance.new(Core,bridge)
    local e={enabled=false,status="OFF",baseline=nil,character=nil,humanoid=nil,owned=nil,
        suspendedUntil=0,externalVerified=false,observedSpeed=nil,corrections=0,nativeOverwrites=0,
        directionRequested=false}
    local function keyboardDirection(uis)
        local function down(key)
            local ok,held=pcall(uis.IsKeyDown,uis,key)
            return ok and held==true
        end
        local x=(down(Enum.KeyCode.D) and 1 or 0)-(down(Enum.KeyCode.A) and 1 or 0)
        local z=(down(Enum.KeyCode.S) and 1 or 0)-(down(Enum.KeyCode.W) and 1 or 0)
        if x==0 and z==0 then return nil end
        local direction=Vector3.new(x,0,z)
        return direction.Magnitude>1 and direction.Unit or direction
    end
    function e:release()
        local o=self.owned;self.owned=nil
        self.appliedSince=nil;self.lowMotionSince=nil;self.directionRequested=false
        if o and o.hum and o.hum.Parent and o.hum.WalkSpeed==o.target then
            pcall(function()o.hum.WalkSpeed=o.before end)
        end
    end
    function e:reset()
        self:release();self.character=nil;self.humanoid=nil;self.baseline=nil;self.lastPosition=nil
        self.lastPositionAt=nil;self.suspendedUntil=0;self.suspendReason=nil;self.observedSpeed=nil
        self.recalibrateAfter=0
    end
    function e:setEnabled(on)
        self.enabled=on==true
        if not self.enabled then self:reset();self.status="OFF" end
    end
    function e:close() self:setEnabled(false) end
    function e:render(s,now,focused)
        if not self.enabled then return end
        if game.PlaceVersion~=2415 then
            self:reset();self.status="Endurance experiment needs audited build 2415";return
        end
        if not s or not s.alive or not s.char or not s.hum or not s.root then
            self:reset();self.status="Waiting for animal";return
        end
        if s.char~=self.character or s.hum~=self.humanoid then
            self:reset();self.character=s.char;self.humanoid=s.hum
        end
        local hum=s.hum
        local native=hum.WalkSpeed
        if not Core.finite(native) or native<0 or native>250 then
            self:release();self.status="Native movement speed unavailable";return
        end
        if self.owned and native~=self.owned.target then
            -- The native controller (or another owner) replaced our value.
            -- WolfMove writes its speed every frame; keep a count, but only
            -- back off when actual local movement remains below the sample.
            self.owned=nil
            self.nativeOverwrites+=1
        end
        local currentOwned=self.owned~=nil
        local ground=not s.swimming and not s.underwater and not s.flying and not s.climbing
            and s.hum.FloorMaterial~=Enum.Material.Air and s.hum.FloorMaterial~=Enum.Material.Water
        local tired=s.serverTired==true or bridge:attribute(s.char,"StaminaOut")==true
        local clear=ground and not s.rest and not s.feeding and not s.captured and not s.ability
            and (not s.noSprint or s.serverTired==true) and not s.holding
            and not s.grab and not s.chat and not s.gameMenu and not s.protectedInteraction
            and focused~=false
        local inputOK,sprint=pcall(bridge.UserInputService.IsKeyDown,
            bridge.UserInputService,Enum.KeyCode.LeftShift)
        local direction=inputOK and sprint==true and keyboardDirection(bridge.UserInputService) or nil
        clear=clear and inputOK and sprint==true
            and (s.hum.MoveDirection.Magnitude>.55 or direction~=nil)
        if clear and not tired and not currentOwned
            and s.stamina and s.maxStamina
            and Core.finite(s.stamina) and Core.finite(s.maxStamina) and s.maxStamina>0
            and s.stamina/s.maxStamina>=.35 and native>0
            and bridge:attribute(bridge.player,"HudSprint")==true then
            if self.baseline and native<self.baseline*.95 then
                -- A speed buff or gait may have ended. Do not reuse its old
                -- higher pace while the current healthy sprint settles.
                self.baseline=nil;self.recalibrateAfter=now+.6
            elseif now>=self.recalibrateAfter then
                -- Never invent a speed from a remote argument or old species.
                self.baseline=native
                self.status="Healthy native sprint sampled"
            end
        end
        if not clear or not tired then
            self:release()
            native=hum.WalkSpeed
            self.lastPosition,self.lastPositionAt=nil,nil
            if not clear then self.status="Paused for native movement or input"
            elseif now<self.recalibrateAfter then self.status="Waiting for native sprint to stabilize"
            elseif not self.baseline then self.status="Waiting for healthy sprint sample"
            elseif native<self.baseline*.95 then self.status="Waiting for native sprint to recover"
            else self.status="Native sprint available" end
            return
        end
        if now<self.suspendedUntil then
            self:release();self.status=self.suspendReason or "Movement assistance paused";return
        end
        if not self.baseline or not Core.finite(self.baseline) or self.baseline<=0 then
            self:release();self.status="Waiting for healthy sprint sample";return
        end
        local position=s.root.Position
        if self.lastPosition and self.lastPositionAt and Core.finite(now-self.lastPositionAt)
            and now>self.lastPositionAt and now-self.lastPositionAt<.25 then
            local dx,dz=position.X-self.lastPosition.X,position.Z-self.lastPosition.Z
            local distance=math.sqrt(dx*dx+dz*dz)
            if distance>math.max(14,self.baseline*(now-self.lastPositionAt)*4) then
                -- An abrupt own-character correction/teleport is enough to
                -- suspend the experiment; it is not proof of server rejection.
                self:release();self.suspendedUntil=now+8;self.corrections+=1
                self.suspendReason="Abrupt movement; assistance paused"
                self.status=self.suspendReason
                self.lastPosition,self.lastPositionAt=nil,nil
                return
            end
        end
        self.lastPosition,self.lastPositionAt=position,now
        self.observedSpeed=horizontal(s.root.AssemblyLinearVelocity)
        if self.appliedSince and self.observedSpeed
            and self.observedSpeed<self.baseline*.68 then
            self.lowMotionSince=self.lowMotionSince or now
            if now-self.lowMotionSince>=1.5 then
                self:release();self.suspendedUntil=now+8
                self.suspendReason="Local movement below sampled pace; assistance paused"
                self.status=self.suspendReason
                return
            end
        else self.lowMotionSince=nil end
        self.directionRequested=false
        local function followPhysicalInput()
            if hum.MoveDirection.Magnitude>.13 then return true end
            if not direction or type(hum.Move)~="function" then
                self:release();self.status="Physical movement input unavailable";return false
            end
            -- Native WolfMove runs at Input+1; the hub runs at Camera+3.
            -- Roblox's Humanoid:Move accepts a camera-relative keyboard vector
            -- and must be called each frame when another controller overwrites it.
            local ok=pcall(hum.Move,hum,direction,true)
            if not ok then
                self:release();self.suspendedUntil=now+8
                self.suspendReason="Native direction request unavailable; assistance paused"
                self.status=self.suspendReason
                return false
            end
            self.directionRequested=true
            self.appliedSince=self.appliedSince or now
            return true
        end
        if currentOwned then
            if not followPhysicalInput() then return end
            self.status=self.directionRequested and "Local pace and direction requested; peer unverified"
                or "Local pace held; peer unverified"
            return
        end
        if native>=self.baseline*.95 then
            if not followPhysicalInput() then return end
            self.status=self.directionRequested and "Local direction requested; peer unverified"
                or "Native pace already sustained"
            return
        end
        -- No position, velocity, CFrame, animation, stamina or server writes.
        -- A native overwrite is observed afresh on the next frame.
        local target=self.baseline
        local ok=pcall(function()hum.WalkSpeed=target end)
        if not ok or hum.WalkSpeed~=target then
            self.status="Movement property unavailable";return
        end
        self.owned={hum=hum,before=native,target=target}
        self.appliedSince=self.appliedSince or now
        if not followPhysicalInput() then return end
        self.status=self.directionRequested and "Local pace and direction requested; peer unverified"
            or "Local pace requested; peer unverified"
    end
    return e
end
return Endurance
