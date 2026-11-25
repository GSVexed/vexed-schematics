#!/usr/bin/env python3
"""Deterministically package one standalone eight-module all-animal Amber addon."""
from pathlib import Path
import argparse
import hashlib
ROOT=Path(__file__).resolve().parent
DEST=ROOT.parent/"feral-amber-autopilot-v0.4.lua"
MODULES=("planner","gait","nav","hunt","agent","bridge","driver","ui")
BOOT=r'''-- FERAL AMBER AUTOPILOT v0.4 — all-animal surface-route, territory and care engine.
-- Native client observations only. No teleportation or fake resource changes.
local EXPECTED_PLACE=108901361810209
if game.PlaceId~=EXPECTED_PLACE then
    warn("[FERAL AMBER] This addon is only for FERAL Animal Survival.")
    return nil
end
local environment=(type(getgenv)=="function" and getgenv()) or _G
local prior=environment.FERAL_AMBER_ACTIVE
if type(prior)=="table" and type(prior.close)=="function" then pcall(prior.close) end
-- Do not permit the old snap/hover controller to compete for movement ownership.
local legacy=environment.FERAL_TERRITORY_RUSH_V4
if type(legacy)=="table" and type(legacy.stop)=="function" then pcall(legacy.stop) end
local function module(name)
    local src=assert(sources[name],"Missing owned Amber module: "..tostring(name))
    local fn,why=loadstring(src,"=FERAL_AMBER_"..name)
    if not fn then error("Amber module compile failure: "..tostring(why)) end
    return fn()
end
local Planner=module("planner")
local Gait=module("gait")
local Nav=module("nav")
local Hunt=module("hunt")
local Agent=module("agent")
local Bridge=module("bridge")
local Driver=module("driver")
local UI=module("ui")
local Players=game:GetService("Players")
local player=assert(Players.LocalPlayer,"No player in current client")
local gui=player:WaitForChild("PlayerGui",18)
if not gui then warn("[FERAL AMBER] PlayerGui unavailable. Spawn first.");return nil end
local path=game:GetService("PathfindingService")
local workspace=game:GetService("Workspace")
local nav=Nav.new(path,workspace,Gait)
local bridge=Bridge.new(nav)
local agent=Agent.new(Planner,bridge,Hunt)
local panel,why=UI.new(agent,bridge)
if not panel then warn("[FERAL AMBER] "..tostring(why));return nil end
local driver=Driver.new(player,nav,function()return bridge:manualInput()end)
local active=true
local connection
-- Closing Renaissance also closes all companion territory automation.
-- This watches the specific hub instance so replacing/unloading it never
-- leaves an orphan Amber controller, panel or synthetic held keys.
local ownerHub=environment.FERAL_RENAISSANCE_ACTIVE
local handle={version="0.4.0",agent=agent,bridge=bridge,nav=nav,panel=panel,
    ownerHub=ownerHub,driver=driver}
function handle.close()
    if not active then return end
    active=false
    if connection then connection:Disconnect();connection=nil end
    pcall(agent.setEnabled,agent,false)
    pcall(driver.close,driver)
    pcall(bridge.close,bridge)
    nav.closed=true
    panel:close()
    if environment.FERAL_AMBER_ACTIVE==handle then environment.FERAL_AMBER_ACTIVE=nil end
end
function handle.setEnabled(on) agent:setEnabled(on==true) end
function handle.status() return agent:status() end
function handle.setPanelVisible(on) panel:setVisible(on) end
function handle.togglePanel() panel:toggle() end
local lastError=0
connection=game:GetService("RunService").Heartbeat:Connect(function()
    if not active then return end
    if ownerHub and (ownerHub.closed==true
        or environment.FERAL_RENAISSANCE_ACTIVE~=ownerHub) then
        handle.close()
        return
    end
    -- PlayerModule supplies steering at Input priority, before WolfMove.
    -- Heartbeat only pumps a mutually exclusive native-key fallback.
    if agent.enabled then
        local ok,err=pcall(driver.tick,driver)
        if not ok then
            agent.lastError=tostring(err)
            agent:setEnabled(false)
            agent.phase="ERROR";agent.reason="Movement input failed; stopped"
        end
    end
    if handle.working then return end
    handle.working=true
    local now=os.clock()
    if agent.enabled then
        local hub=environment.FERAL_RENAISSANCE_ACTIVE
        if type(hub)=="table" and hub.walk and type(hub.stopWalk)=="function" then
            pcall(hub.stopWalk,hub,"Amber surface-navigation owner")
        end
    end
    local ok,err=pcall(agent.tick,agent,now)
    if not ok then
        agent:setEnabled(false)
        agent.lastError=tostring(err)
        agent.phase="ERROR"
        agent.reason="Native bridge error; autopilot stopped"
        if now-lastError>4 then
            lastError=now
            warn("[FERAL AMBER] Safe stop: "..tostring(err))
        end
    end
    local good,uierr=pcall(panel.tick,panel,now)
    if not good and now-lastError>4 then lastError=now;warn("[FERAL AMBER] UI: "..tostring(uierr)) end
    handle.working=false
end)
environment.FERAL_AMBER_ACTIVE=handle
print("[FERAL AMBER 0.4] Ready. Select START in the small Amber panel; native walking, claim and care outcomes are observed, not presumed.")
return handle
'''
def create():
    chunks=['-- FERAL Amber Autopilot 0.4.0 | 2026-11-25 | all species | client-only outcomes',
            'local sources = {}']
    for name in MODULES:
        source=(ROOT/"src"/f"{name}.luau").read_text(encoding="utf-8")
        assert "]============]" not in source
        chunks.append(f'sources["{name}"] = [============[\n{source}]============]')
    chunks.append(BOOT.strip())
    return "\n".join(chunks)+"\n"
def main():
    p=argparse.ArgumentParser()
    p.add_argument("--check",action="store_true")
    args=p.parse_args()
    data=create()
    if args.check:
        assert DEST.is_file() and DEST.read_text(encoding="utf-8")==data,"Candidate source differs from compiled modules"
    else:
        DEST.write_text(data,encoding="utf-8")
    print(f"FERAL AMBER 0.4.0 sha256={hashlib.sha256(data.encode()).hexdigest()} bytes={len(data.encode())}")
if __name__=="__main__":main()
