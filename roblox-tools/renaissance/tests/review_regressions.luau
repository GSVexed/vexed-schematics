-- Behavior regressions discovered during independent final integration review.
return function(test,eq,load,Mock,modules,boot,close,E)
    test("a held click on hub UI cannot become a gameplay attack by dragging outside",function()
        local w=Mock.new();w:enableNativeActions()
        local h=load(w,{settings={states={holdBite=true,recovery=false,attackSpeed=false}}});w:advance(.2)
        w.uis.GetMouseLocation=function()return Mock.V2.new(100,100)end
        w.held=E.UserInputType.MouseButton1
        w:input(nil,E.UserInputType.MouseButton1,true)
        w:advance(.2);eq(w.nativeBites,nil)
        w.uis.GetMouseLocation=function()return Mock.V2.new(1200,850)end
        w:advance(1.5);eq(w.nativeBites,nil);eq(h.combatInput.held,nil)
        w:input(nil,E.UserInputType.MouseButton1);w:advance(.8)
        assert((w.nativeBites or 0)>=2,"a fresh gameplay press should restore repeated input")
        h:close()
    end)

    test("overlapping native ability damage never trains ordinary bite cadence",function()
        for _,key in ipairs({"FeralCrushBiteAt","FeralDeathRollLocal"}) do
            local w=Mock.new();w:spawn("Hippo");w:enableNativeActions()
            local _,victim=w:enemy(2,Mock.V3.new(0,3,-4))
            local h=load(w,{settings={states={holdBite=true,recovery=false,attackSpeed=true}}});w:advance(.3)
            w.held=E.UserInputType.MouseButton1;local input=w:input(nil,E.UserInputType.MouseButton1)
            local tx=h.transactions[#h.transactions];assert(tx.rateEligible)
            w.held=nil;w.uis.InputEnded:Fire(input);w:advance(.3)
            w.player.Character:SetAttribute(key,key=="FeralCrushBiteAt" and w.time+1000 or true)
            w:remote("FeralHit").OnClientEvent:Fire("hit",{a=w.player.Character,v=victim,dmg=30})
            eq(tx.feedback,nil);eq(tx.fastConfirmed,nil);eq(h.combatInput.goodStreak,0)
            eq(h.ledger.counts.native_outgoing_hit_reply,1)
            eq(h.ledger.counts.native_outgoing_hit_reply_unmatched,1)
            assert(h.combatStatus:find("Game reports a hit",1,true))
            w:advance(3);eq(h.combatInput.suspectStreak,0)
            eq(h.ledger.counts.cadence_backoff,nil);h:close()
        end
    end)

    test("ability overlap cannot become an extended-contact miss after its evidence window",function()
        local w=Mock.new();w:spawn("Hippo");w:enableNativeActions()
        local _,victim=w:enemy(2,Mock.V3.new(0,3,-8))
        local h=load(w,{settings={states={holdBite=true,recovery=false,attackSpeed=false}}});w:advance(.3)
        assert(h.guide.extended.valid and not h.guide.baseline.valid)
        w.held=E.UserInputType.MouseButton1;local input=w:input(nil,E.UserInputType.MouseButton1)
        w.held=nil;w.uis.InputEnded:Fire(input);w:advance(.3)
        local tx=h.transactions[#h.transactions];assert(tx.extendedOnly and tx.extendedClaimValid)
        w.player.Character:SetAttribute("FeralCrushBiteAt",w.time+1000)
        w:advance(3)
        eq(h.extendedConfidence[victim],nil);eq(h.ledger.counts.extended_contact_unconfirmed,nil)
        eq(h.combatInput.suspectStreak,0);h:close()
    end)

    test("temporarily detached voice emitters restore before reattachment without repeated scaling",function()
        local M,w=modules();local remote,char=w:enemy(2)
        local input=w.new("AudioDeviceInput");input.Parent=remote
        local emitter=w.new("AudioEmitter");emitter.Name="AudioEmitter"
        emitter.DistanceAttenuationMode=E.DistanceAttenuationMode.Custom
        emitter._attenuation={[0]=1,[10]=.6,[40]=0};emitter.Parent=char
        local v=M.voice.new(w.env.game:GetService("Players"),w.player);v:setEnabled(true)
        eq(emitter:GetDistanceAttenuation()[12.5],.6)
        emitter.Parent=nil;v:setEnabled(false)
        eq(emitter:GetDistanceAttenuation()[10],.6)
        emitter.Parent=char;v:setEnabled(true)
        eq(emitter:GetDistanceAttenuation()[12.5],.6)
        eq(emitter:GetDistanceAttenuation()[15.625],nil)
        emitter.Parent=nil;emitter:SetDistanceAttenuation({[0]=1,[7]=.4,[29]=0})
        v:close();eq(emitter:GetDistanceAttenuation()[7],.4)
        eq(w:connections(),0)
    end)
end
