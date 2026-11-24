-- Same deterministic crowd, services and frames for the preserved release and candidate.
-- Counts API/property operations, not milliseconds or real game FPS.
local Performance={}
function Performance.run(bundle,Mock,pending)
    local w=Mock.new();w:enableNativeActions();w:enableNativeGrab()
    for index=1,24 do w:enemy(2,Mock.V3.new(index*2,3,-60-index)) end
    local h=assert(w.env.loadstring(bundle))({settings={states={esp=true,tags=true,minigame=true}}})
    w:advance(.4);h.ui:toggle()
    if pending then
        local remote=w:remote("FeralGrabV2")
        remote.OnClientEvent:Fire("begin",{f=91,role="prey",n=4})
        remote.OnClientEvent:Fire("strike",{f=91,k=1,t0=w.time+1002.5,spd=1,from=0,zc=.5,zw=.215})
    end
    local scans=0
    local original=h.bridge.candidates
    h.bridge.candidates=function(self,...)scans+=1;return original(self,...)end
    w:resetMetrics()
    for _=1,120 do w:step(1/60)end
    assert(h.active,h.lastError)
    local writes=0
    for key,value in pairs(w.metrics.writes)do if key:sub(1,10)=="Highlight:" then writes+=value end end
    local result={highlightWrites=writes,labelPositions=w.metrics.writes["TextLabel:Position"] or 0,
        projections=w.metrics.projections,upvalues=w.metrics.upvalues,boundInfo=w.metrics.boundInfo,
        connections=w.metrics.connections,heap=w.metrics.heap,candidateScans=scans}
    h:close()
    return result
end
return Performance
