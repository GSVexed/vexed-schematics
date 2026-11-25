-- Ordinary world-space input before WolfMove reads Humanoid.MoveDirection.
-- v2412 WolfController 187:1546-1666 binds WolfMove at Input.Value+1.
local Driver={}
function Driver.new(player,nav,manual)
    local d={nav=nav,closed=false,method="NATIVE_KEYS",controls=nil,original=nil,nextProbe=0}
    function d:attach()
        if self.closed or self.controls then return end
        local modules={}
        local scripts=player:FindFirstChild("PlayerScripts")
        local legacy=scripts and scripts:FindFirstChild("PlayerModule")
        if legacy then table.insert(modules,{module=legacy,path="PLAYER_SCRIPTS"}) end
        -- The supplied capture indexes StarterPlayer/PlayerModule/ControlModule.
        -- IAS PlayerModule need not expose the legacy GetControls endpoint.
        local ok,starter=pcall(function()return game:GetService("StarterPlayer")end)
        local modern=ok and starter and starter:FindFirstChild("PlayerModule")
        if modern and modern~=legacy then table.insert(modules,{module=modern,path="STARTER_PLAYER"}) end
        local controls,path=nil,nil
        for _,candidate in ipairs(modules) do
            local mod=candidate.module
            local good,value=pcall(require,mod)
            if good and type(value)=="table" then
                if type(value.GetControls)=="function" then
                    local found,result=pcall(value.GetControls,value)
                    if found and type(result)=="table" then controls=result end
                elseif type(value.moveFunction)=="function" then controls=value end
            end
            if not controls and type(mod.FindFirstChild)=="function" then
                local child=mod:FindFirstChild("ControlModule")
                if child then
                    local found,result=pcall(require,child)
                    if found and type(result)=="table" then controls=result end
                end
            end
            if controls and type(controls.moveFunction)=="function" then path=candidate.path;break end
            controls=nil
        end
        if not controls then self.reason="No supported native moveFunction; using keys";return end
        local previous=controls.moveFunction
        local wrapper=function(p,direction,relative)
            if p==player and not self.closed and nav.desiredPoint and nav.steeringStrategy=="WORLD" then
                if manual and manual() then
                    nav:stop(nav.desiredHum,nav.desiredRoot,"MANUAL_INPUT")
                else
                    local wanted=nav:direction()
                    if wanted then
                        nav.driveCalls+=1;nav.lastMode="PLAYER_MODULE"
                        return previous(p,wanted,false)
                    end
                end
            end
            return previous(p,direction,relative)
        end
        local attached,why=pcall(function()controls.moveFunction=wrapper end)
        if not attached then self.reason=tostring(why);return end
        self.controls,self.original,self.wrapper=controls,previous,wrapper
        self.method,self.path,self.reason="PLAYER_MODULE",path,"Native callback attached; motion unverified"
        nav.preferredStrategy="WORLD";nav.steeringStrategy="WORLD"
        nav.driverPath=path
    end
    d:attach()
    if not d.controls then nav.preferredStrategy="KEY";nav.steeringStrategy="KEY" end
    function d:tick()
        if self.closed then return end
        if self.controls and self.controls.moveFunction~=self.wrapper then
            self.method="NATIVE_KEYS";nav.preferredStrategy="KEY";nav.steeringStrategy="KEY"
            self.reason="Native callback ownership changed"
        elseif not self.controls and os.clock()>=self.nextProbe then
            self.nextProbe=os.clock()+5;self:attach()
        end
        nav.driverReason=self.reason
        if nav.steeringStrategy=="KEY" then nav:drive() end
    end
    function d:close()
        if self.closed then return end
        self.closed=true
        nav:stop(nav.desiredHum,nav.desiredRoot,"DRIVER_CLOSED")
        if self.controls and self.controls.moveFunction==self.wrapper then
            self.controls.moveFunction=self.original
        end
    end
    return d
end
return Driver
