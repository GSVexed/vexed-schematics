-- Native Renaissance page. No companion ScreenGui, scheduler or visibility key.
local UI={}
function UI.new(engine,hub)
    local p={closed=false,engine=engine,hub=hub}
    local function amount(value)
        return type(value)=="number" and string.format("%.0f",value) or "?"
    end
    function p:mount(parent,H)
        local text,button,card=H.text,H.button,H.card
        local v={}
        local controls=card(0,48)
        local start=button(controls,"START FARMING",10,9,150,30)
        local skip=button(controls,"SKIP TARGET",169,9,150,30)
        local copy=button(controls,"COPY STATUS",328,9,150,30)
        start.Name="TerritoryStart";skip.Name="TerritorySkip";copy.Name="TerritoryCopy"
        start.Activated:Connect(function()if not p.closed then engine.setEnabled(not engine.agent.enabled)end end)
        skip.Activated:Connect(function()if not p.closed then engine.skip()end end)
        copy.Activated:Connect(function()if not p.closed then engine.copyStatus()end end)
        local stats=card(56,71)
        local totals=text(stats,"",12,8,465,22,12,H.palette.same)
        local needs=text(stats,"",12,34,465,23,12)
        local goal=card(135,103)
        local phase=text(goal,"",12,7,465,23,13,H.palette.same)
        local reason=text(goal,"",12,33,465,37,11,H.palette.sub);reason.TextWrapped=true
        local progress=text(goal,"",12,73,465,20,11)
        local movement=card(246,53)
        local gait=text(movement,"",12,5,465,22,12)
        local travel=text(movement,"",12,28,465,19,10,H.palette.sub)
        local recent=card(307,54)
        local last=text(recent,"",12,5,465,44,11,H.palette.sub);last.TextWrapped=true
        function v:tick(now)
            if now<(self.nextText or 0) then return end
            self.nextText=now+.25
            local s=engine.status();local n=s.navigation or {};local c=s.hexSummary or {}
            start.Text=s.enabled and "STOP FARMING" or "START FARMING"
            start.BackgroundColor3=s.enabled and H.palette.on or H.palette.off
            local amber=s.metrics and s.metrics.amber
            local balance=amber and string.format("Balance %+.0f · %+.0f/hr",amber.net or 0,amber.netPerWallHour or 0)
                or string.format("Observed Amber +%.0f",s.earned or 0)
            totals.Text=string.format("%d / %d owned · %d need scent · %s",c.owned or 0,c.eligible or 0,c.fading or 0,balance)
            needs.Text="Hunger "..amount(s.hunger).." · Thirst "..amount(s.thirst).." · "..tostring(s.species or "Waiting for animal")
            phase.Text=(s.enabled and "RUNNING · " or "OFF · ")..tostring(s.phase)..(s.key and " · "..s.key or "")
            reason.Text=tostring(s.reason or "Ready")
            local target=s.targetProgress or {}
            local value=target.action=="SCENT" and target.hold or target.progress
            progress.Text=type(value)=="number" and ("Native territory progress "..amount(value*100).."%")
                or s.suspended and ("Will resume "..s.suspended) or "Watching native progress and resource changes"
            if s.capacity and s.capacity.state=="DEADLINE_PRESSURE" then
                progress.Text=progress.Text.." · Maintenance pressure"
            end
            gait.Text=tostring(n.requested or "STOP").." requested · "..tostring(n.observed or "UNKNOWN").." observed"
            travel.Text="Travelled "..amount(n.travelled).." studs · Target "..amount(n.distance).." studs"
                ..(n.failure and (n.stalledFor or 0)>1 and " · "..n.failure or "")
            if s.strategy and s.strategy.area then
                progress.Text=s.strategy.area.." · "..tostring(s.strategy.owned or 0).."/"..tostring(s.strategy.total or 0).." owned"
                    ..(type(value)=="number" and (" · Native progress "..amount(value*100).."%") or "")
            end
            last.Text=s.lastNotice or s.lastSuccess or s.lastSkip or "Select START FARMING. Hiding the hub keeps farming active."
        end
        function v:close()end
        v:tick(os.clock());return v
    end
    p.registration=hub.ui:registerPage("Territory",p)
    function p:close()
        if self.closed then return end
        self.closed=true
        if self.registration then self.registration:close() end
    end
    return p
end
return UI
