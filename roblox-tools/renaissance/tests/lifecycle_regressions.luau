-- Cross-branch lifecycle regressions beyond the retained 16.0.2 scenarios.
return function(test,eq,load,Mock,modules,boot,close,E)
    test("small residual conditions retain only bounded missing-data grace",function()
        local w=Mock.new();local char=w.player.Character
        char:SetAttribute("FeralVenomAmt",.025)
        local h=load(w,{settings={states={recovery=true}}});w:advance(.1)
        eq(h.recovery.owned,char)
        char:SetAttribute("FeralVenomAmt",nil);w:advance(.4)
        eq(h.recovery.owned,char)
        char:SetAttribute("FeralVenomAmt",0);w:advance(.04)
        eq(h.recovery.owned,nil)
        eq(h.recovery.observations.venom,nil)
        h:close()
    end)

    test("voice bound setter mutation followed by rejection restores the original curve bounds",function()
        local M,w=modules();local remote,char=w:enemy(2)
        local input=w.new("AudioDeviceInput");input.Parent=remote
        local emitter=w.new("AudioEmitter");emitter.Name="AudioEmitter"
        emitter.DistanceAttenuationMode=E.DistanceAttenuationMode.Inverse
        w.env.NumberRange={new=function(minimum,maximum)return {Min=minimum,Max=maximum}end}
        emitter.DistanceAttenuationBounds=w.env.NumberRange.new(5,40)
        emitter.Parent=char
        local meta=getmetatable(emitter);local write=meta.__newindex
        local rejected=0
        meta.__newindex=function(self,key,value)
            write(self,key,value)
            if key=="DistanceAttenuationBounds" and value.Max>40 then
                rejected+=1;error("setter mutated before rejecting")
            end
        end
        local v=M.voice.new(w.env.game:GetService("Players"),w.player)
        v:setEnabled(true)
        assert(rejected>0)
        close(emitter.DistanceAttenuationBounds.Min,5)
        close(emitter.DistanceAttenuationBounds.Max,40)
        eq(v:status().adjusted,0)
        v:close();eq(w:connections(),0)
        close(emitter.DistanceAttenuationBounds.Max,40)
    end)
end
