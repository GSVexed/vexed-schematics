-- Experimental, own-character movement assistance. This can alter local
-- Humanoid speed; it does not change server stamina or prove peer replication.
local Endurance={}
local function horizontal(v)
    if not v then return nil end
    local x,z=v.X,v.Z
    if type(x)~="number" or type(z)~="number" then return nil end
    return math.sqrt(x*x+z*z)
end
function Endurance.new(Core,bridge)
    local e={enabled=false,status="OFF",baseline=nil,character=nil,owned=nil,
        suspendedUntil=0,externalVerified=false,observedSpeed=nil,corrections=0}
    function e:release()
        local o=self.owned;self.owned=nil
        self.appliedSince=nil;self.lowMotionSince=nil
        if o and o.hum and o.hum.Parent and o.hum.WalkSpeed==o.target then
            pcall(function()o.hum.WalkSpeed=o.before end)
        end
    end
    function e:reset()
        self:release();self.character=nil;self.baseline=nil;self.lastPosition=nil
        self.lastPositionAt=nil;self.suspendedUntil=0;self.suspendReason=nil;self.observedSpeed=nil
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
        if s.char~=self.character then
            self:reset();self.character=s.char
        end
        local hum=s.hum
        local native=hum.WalkSpeed
        if not Core.finite(native) or native<=0 or native>250 then
            self:release();self.status="Native movement speed unavailable";return
        end
        if self.owned and (self.owned.hum~=hum or native~=self.owned.target) then
            -- The native controller (or another owner) replaced our value.
            -- Never restore an older speed on top of its new value.
            self.owned=nil
        end
        local currentOwned=self.owned~=nil
        local ground=not s.swimming and not s.underwater and not s.flying and not s.climbing
            and s.hum.FloorMaterial~=Enum.Material.Air and s.hum.FloorMaterial~=Enum.Material.Water
        local tired=s.serverTired==true or bridge:attribute(s.char,"StaminaOut")==true
        local clear=ground and not s.rest and not s.feeding and not s.captured and not s.ability
            and (not s.noSprint or s.serverTired==true) and not s.holding
            and not s.grab and not s.chat and not s.gameMenu and not s.protectedInteraction
            and focused~=false and s.hum.MoveDirection.Magnitude>.55
        local inputOK,sprint=pcall(bridge.UserInputService.IsKeyDown,
            bridge.UserInputService,Enum.KeyCode.LeftShift)
        clear=clear and inputOK and sprint==true
        if clear and not tired and not currentOwned
            and (not self.baseline or native>=self.baseline*.95)
            and s.stamina and s.maxStamina
            and Core.finite(s.stamina) and Core.finite(s.maxStamina) and s.maxStamina>0
            and s.stamina/s.maxStamina>=.35
            and bridge:attribute(bridge.player,"HudSprint")==true then
            -- Calibrate against the game's own healthy sprint on this animal.
            -- Never invent a speed from a remote argument or an old species.
            self.baseline=native
            self.status="Healthy native sprint sampled"
        end
        if not clear or not tired then
            self:release()
            native=hum.WalkSpeed
            self.lastPosition,self.lastPositionAt=nil,nil
            if not clear then self.status="Paused for native movement or input"
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
            and self.observedSpeed<self.baseline*.4 then
            self.lowMotionSince=self.lowMotionSince or now
            if now-self.lowMotionSince>=1.5 then
                self:release();self.suspendedUntil=now+8
                self.suspendReason="No sustained local movement; assistance paused"
                self.status=self.suspendReason
                return
            end
        else self.lowMotionSince=nil end
        if currentOwned then
            self.status="Local pace held; other-client view unverified"
            return
        end
        if native>=self.baseline*.95 then
            self.status="Native pace already sustained";return
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
        self.status="Local pace requested; other-client view unverified"
    end
    return e
end
return Endurance
