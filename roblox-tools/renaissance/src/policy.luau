-- Local scheduling policy. This never changes native eligibility or cooldowns.
local Policy = {}
local function finite(n) return type(n)=="number" and n==n and math.abs(n)<1e12 end
function Policy.new()
    local p = { attackUntil = 0, actionUntil = 0, lastRestRelease = -math.huge,
        manualIntentUntil = 0, manualRest = false, lastPhysical = 0, menuOpen = false,
        combatApproachUntil = 0 }
    function p:input(kind, now)
        self.lastPhysical = now
        if kind == "attack" then self.attackUntil = math.max(self.attackUntil, now+1.1) end
        if kind == "action" then self.actionUntil = math.max(self.actionUntil, now+1.3) end
        if kind == "rest" then self.manualIntentUntil = now+.9 end
    end
    function p:activity(s,now)
        if not s or not s.alive then return "unavailable" end
        if s.chat or s.gameMenu then return "menu" end
        if s.grab then return "minigame" end
        if s.captured then return "capture" end
        if s.attackHeld or now<self.attackUntil then return "attack" end
        if s.ability or s.holding then return "ability" end
        if s.feeding then return "feeding" end
        if s.rescuing then return "rescue" end
        if s.climbing or s.flying or s.underwater or s.swimming then return "movement" end
        if self.manualRest then return "manual Rest" end
        if now<self.actionUntil then return "action" end
        return "recovery window"
    end
    function p:allowed(mode, s, now, purpose)
        if not s or not s.alive then return false, "waiting for animal" end
        if s.chat or s.gameMenu then return false, "native menu or text input" end
        if mode == "grab" then return true, "native session" end
        if s.grab then return false, "minigame has priority" end
        if mode == "escape" then return true, "native capture" end
        if s.captured then return false, "captured" end
        if mode == "recovery" then
            if self.manualRest then return false, "manual Rest" end
            if s.feeding then return false, "feeding or approaching food/water" end
            if s.rescuing then return false,"cub rescue input" end
            if s.ability or s.holding then return false, "native action" end
            if s.attackHeld or now < self.attackUntil then return false, "attack has priority" end
            -- Avoid re-arming native Rest just as an eligible enemy enters
            -- contact: its native stand-up lock can swallow the first bite.
            if now < self.combatApproachUntil then return false, "imminent bite; preserving combat readiness" end
            if now < self.actionUntil or s.afkWalking then return false, "action has priority" end
            -- The original live-tested Rest signal worked while the own
            -- animal was moving; surface swimming is ordinary locomotion, not
            -- an attack. Protect aerial, climb and submerged transitions.
            if s.climbing or s.flying or s.underwater then return false, "movement transition" end
            -- Combat time can be unknown when the server clock is unavailable.
            -- That must not silently disable the separate condition request.
            -- HP is still excluded while combat is true or unknown.
            if purpose == "effects" then
                return true,s.combat == true and "condition Rest while in combat; no combat HP claim"
                    or s.combat == nil and "condition Rest; combat state unknown, HP excluded"
                    or "condition Rest, no combat"
            end
            if s.combat ~= false then return false, s.combat and "combat" or "combat state unknown" end
            return true, "recovery window"
        end
        if self.manualRest or s.rest then return false, "manual Rest" end
        if s.feeding or s.ability then return false, "native action" end
        if s.rescuing then return false,"cub rescue input" end
        if s.attackHeld or now < self.attackUntil then return false, "attack has priority" end
        if mode == "climb" or mode == "flight" then
            if s.diveCan and mode == "climb" then return false, "dive has priority" end
            return true, "manual movement request"
        end
        if mode == "afk" then
            if self.menuOpen then return false, "hub menu open" end
            if s.combat ~= false then return false, "combat or unknown combat state" end
            if now-self.lastPhysical < 65 then return false, "manual input" end
            if s.climbing or s.flying or s.swimming or s.holding then return false, "busy" end
            if s.moving and not s.afkWalking then return false, "already moving" end
            if not finite(s.hp) or not finite(s.maxHP) or s.maxHP<=0 or s.hp<0 then return false,"health unavailable" end
            if s.hp < s.maxHP*.8 then return false, "health deficit" end
            for _, key in ipairs({ "injury", "bleed", "venom" }) do
                if not finite(s[key]) or s[key]<0 or s[key] > .1 then return false, "status or unknown status" end
            end
            if not finite(s.hunger) or not finite(s.thirst)
                or s.hunger < 25 or s.thirst < 25 then return false, "needs or unknown needs" end
            if s.nearbyDanger then return false, "animal nearby" end
            return true, "safe activity window"
        end
        return false, "unknown action"
    end
    function p:restLocked(now, duration)
        return now-self.lastRestRelease < (duration or .7)
    end
    return p
end
return Policy
