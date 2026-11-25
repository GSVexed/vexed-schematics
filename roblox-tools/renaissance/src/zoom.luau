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
