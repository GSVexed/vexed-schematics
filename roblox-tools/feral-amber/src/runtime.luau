-- Built-in Territory engine. Renaissance owns scheduling, UI and shutdown.
local Runtime={version="0.6.0"}
function Runtime.start(M,hub)
    assert(hub and hub.ui and type(hub.ui.registerPage)=="function","Update Renaissance for its built-in Territory page")
    local env=(type(getgenv)=="function" and getgenv()) or _G
    local prior=env.FERAL_AMBER_ACTIVE
    if prior and prior.version==Runtime.version and prior.ownerHub==hub and not prior.closed then return prior end
    if prior and type(prior.close)=="function" then pcall(prior.close) end
    local function module(name)return assert(M["amber_"..name] or M[name],"Missing territory module "..name)end
    local Nav,Bridge,Agent=module("nav"),module("bridge"),module("agent")
    local nav=Nav.new(game:GetService("PathfindingService"),game:GetService("Workspace"),module("gait"))
    local bridge=Bridge.new(nav);bridge.ownerHub=hub
    local agent=Agent.new(module("planner"),bridge,module("hunt"),module("care"))
    local driver=module("driver").new(bridge.player,nav,function()return bridge:manualInput()end)
    local h={version=Runtime.version,ownerHub=hub,agent=agent,bridge=bridge,nav=nav,driver=driver,closed=false,nextCounts=0}
    function h.setEnabled(on) if not h.closed then agent:setEnabled(on==true) end end
    function h.status()
        local now=os.clock();local st=agent:status()
        if now>=h.nextCounts then
            h.counts=bridge:counts(agent.lastState or {now=now});h.nextCounts=now+.8
        end
        st.hexSummary=h.counts;st.navigation=nav:status();st.gameVersion=game.PlaceVersion
        st.events={}
        for i=math.max(1,#agent.events-11),#agent.events do table.insert(st.events,agent.events[i]) end
        return st
    end
    function h.copyStatus()
        local ok,payload=pcall(function()return game:GetService("HttpService"):JSONEncode(h.status())end)
        if not ok then return false end
        if type(setclipboard)=="function" then pcall(setclipboard,payload) end
        print("[FERAL TERRITORY STATUS] "..payload);return true
    end
    function h.skip()
        if not agent.enabled then return end
        local s=agent.lastState
        if not s or not agent.goal or agent.goal.kind~="TERRITORY" then return end
        agent:fail(s,"Target skipped from Territory controls");agent.nextTick=0
    end
    h.panel=module("ui").new(h,hub)
    function h:tick(now)
        if self.closed then return end
        if hub.closed then self.close();return end
        local ok,why=pcall(function()
            if agent.enabled then driver:tick() end
            for _=1,3 do
                agent:tick(now)
                if not agent.enabled or agent.goal or agent.phase~="CONFIRMED" and agent.phase~="REPLAN" then break end
                agent.nextTick=now
            end
        end)
        if not ok then
            -- A failure in the normal stop path must not escape this boundary
            -- and interrupt the shared hub's remaining work for the frame.
            pcall(agent.setEnabled,agent,false)
            pcall(nav.stop,nav,nav.desiredHum,nav.desiredRoot,"TERRITORY_ERROR")
            pcall(nav.releaseKeys,nav);pcall(bridge.releaseInputs,bridge)
            agent.enabled=false;agent.goal=nil;agent.suspended=nil;agent.returns={};agent.phase="ERROR"
            agent.lastError=tostring(why):sub(1,180);agent.reason="Territory stopped after an input or data error"
        end
    end
    function h.close()
        if h.closed then return end
        h.closed=true
        pcall(agent.setEnabled,agent,false);pcall(driver.close,driver);pcall(bridge.close,bridge)
        nav.closed=true
        if h.panel then pcall(h.panel.close,h.panel) end
        if env.FERAL_AMBER_ACTIVE==h then env.FERAL_AMBER_ACTIVE=nil end
        if hub.territory==h then hub.territory=nil end
    end
    env.FERAL_AMBER_ACTIVE=h;hub.territory=h
    return h
end
return Runtime
