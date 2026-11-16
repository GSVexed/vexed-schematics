-- Appended to the existing offline mock's fixture prefix by the Python runner.
-- These are synthetic test scripts, not game sources.
function methods:GetAttribute(key) return self._attrs[key] end
local function ensure(parent,name)
    return parent:FindFirstChild(name) or newNode("Folder",name,parent)
end
local fixtureTargets = assert(load(TEST_TARGETS,"=test_target_metadata"))()
local targetNodes = {}
for index,target in ipairs(fixtureTargets) do
    local cursor = game
    local segments = {}
    for part in target.path:gmatch("[^/]+") do segments[#segments + 1] = part end
    for i = 2,#segments - 1 do
        if cursor == services.Players and segments[i] == "LocalPlayer" then cursor = localPlayer
        else cursor = ensure(cursor,segments[i]) end
    end
    local source = 'local AccessToken = "PRIVATE_SOURCE_TOKEN"; return {growth=' .. index .. '}'
    if index == 1 or case == "all_invalid" then source = "local x = {one=1 two=2}; return x" end
    if index == 3 then source = "_G.RECONSTRUCTED_CODE_EXECUTED = true; return {}" end
    if case == "chunked_recovery" and index == 2 then source = 'return [=[' .. string.rep('αβ text\n',3000) .. ']=]' end
    if case == "oversize_recovery" and index == 2 then source = string.rep('local a=1\n',200) end
    if case == "interpolated_recovery" and index == 2 then source = 'return `secret: PRIVATE_BACKTICK_SECRET`' end
    if case == "filter_regression" then source = "return {value=1}" end
    if not (case == "missing_target" and index == 2) then
        local obj = addScript(target.path:find("PlayerScripts",1,true) and "LocalScript" or "ModuleScript",segments[#segments],cursor,source)
        targetNodes[index] = obj
        if case == "readable_source" then obj._props.Source = source end
    end
end
localPlayer._attrs.FeralMenuOpen,localPlayer._attrs.FeralDespawned = true,true
localPlayer._attrs.FeralAnimal = "Tiger"
localPlayer._props.Character = nil
localCharacter._attrs.Species,localCharacter._attrs.Stamina,localCharacter._attrs.StaminaMax = "Tiger",80,100
local function spawnTiger()
    localPlayer._props.Character = localCharacter
    localPlayer._attrs.FeralMenuOpen,localPlayer._attrs.FeralDespawned = false,false
end
local compiling = 0
function loadstring(body,name)
    compiling = compiling + 1
    if case == "compiler_throws" then error("PRIVATE_COMPILER_EXCEPTION " .. body) end
    return load(body,name)
end
if case == "compiler_missing" then loadstring = nil end
if case == "environment_apis" then
    local env = getgenv()
    env.loadstring = loadstring
    loadstring = nil
end
local liveWorkers = {}
local cancelBase = task.cancel
task.cancel = function(thread)
    if case == "recovery_uncancellable" then error("cannot cancel worker") end
    cancelBase(thread)
    if liveWorkers[thread] then liveWorkers[thread] = nil; activeDecompilers = activeDecompilers - 1 end
end
function decompile(obj)
    decompileCalls = decompileCalls + 1
    activeDecompilers = activeDecompilers + 1
    maxActiveDecompilers = math.max(maxActiveDecompilers,activeDecompilers)
    local thread = coroutine.running()
    liveWorkers[thread] = true
    obj._props.attempts = (obj._props.attempts or 0) + 1
    if case == "cancel" and decompileCalls == 3 then click("Stop"); stopTriggered = true end
    if case == "pause" and decompileCalls == 2 then
        click("Pause"); pauseTriggered = true
        task.delay(0.5,function() click("Pause") end)
    end
    if case == "recovery_timeout" or case == "recovery_uncancellable" then task.wait(1000) end
    if case == "yielding" then task.wait(0.03) end
    liveWorkers[thread] = nil
    activeDecompilers = activeDecompilers - 1
    if case == "recovery_api_error" then error("PRIVATE_EXCEPTION_TEXT") end
    if case == "retry_improves" and obj._props.attempts > 1 then return "return {improved=true}" end
    return obj._props.mockSource
end
if case == "no_decompiler" then decompile = nil end
if case == "environment_apis" then
    getgenv().decompile = decompile
    decompile = nil
end
local text = assert(io.open(SOURCE_PATH,"rb")):read("*a")
local marker = "local uiOk,uiError = pcall(D.createUI)"
local pos = assert(text:find(marker,1,true))
local hook = "FERAL_TEST = D\nlocal kindBase = D.errorKind; D.errorKind = function(err) TEST_LAST_ERROR = tostring(err); return kindBase(err) end\n"
if case == "filter_regression" then
    hook = hook .. 'D.filterSource = function() return "local = ",0,true end\n'
end
text = text:sub(1,pos - 1) .. hook .. text:sub(pos)
if case == "object_limit" then text = text:gsub("maxObjects = 300000","maxObjects = 20",1) end
if case == "oversize_recovery" then text = text:gsub("maxSingleSourceBytes = 8388608","maxSingleSourceBytes = 1024",1) end
if case == "chunked_recovery" then
    text = text:gsub("uploadPartBytes = 25165824","uploadPartBytes = 131072",1)
    text = text:gsub("sourceChunkBytes = 524288","sourceChunkBytes = 4096",1)
end
assert(load(text,"@feral-recovery-supplement-v3.1.lua"))()
assert(writes == 0 and decompileCalls == 0,"capture started without a click")
if case ~= "manual_ready" then
    task.defer(function()
        if case == "wrong_mode" then spawnTiger();click("MenuCapture");return end
        if case == "ingame_only" then spawnTiger();click("InGameCapture");return end
        if case == "hide_show" then click("Hide");click("Show") end
        if case == "ingame_before_spawn" then click("InGameCapture");return end
        if case == "pause_observation" then task.delay(0.4,function()
            click("Pause");task.delay(3,function() click("Pause") end)
        end) end
        click("MenuCapture")
        if case == "dual_capture" or case == "hide_show" then
            assert(not FERAL_TEST.running,"menu click returned before capture ended")
            spawnTiger()
            click("InGameCapture")
        end
        click("CopyFolder")
    end)
    if case == "double_click" then task.defer(function() click("MenuCapture") end) end
end
local steps = 0
while #queue > 0 do
    table.sort(queue,function(a,b) return a.at < b.at end)
    local item = table.remove(queue,1)
    if not dead[item.thread] and coroutine.status(item.thread) ~= "dead" then
        clock = math.max(clock,item.at)
        local ok,delay = coroutine.resume(item.thread,table.unpack(item.args or {}))
        assert(ok,tostring(delay))
        if coroutine.status(item.thread) ~= "dead" then schedule(item.thread,delay or 0.016) end
    end
    steps = steps + 1
    assert(steps < 1500000,"scheduler did not finish")
    if case == "recovery_uncancellable" and clock > 100 then break end
end
click("CopyStartup")
assert(not RECONSTRUCTED_CODE_EXECUTED,"compiled game code was executed")
assert(forbiddenWrites == 0,"gameplay mutations occurred")
assert(eventCalls == 0,"remote invoked")
os.clock = nativeClock
local captures = {}
for _,capture in ipairs(FERAL_TEST.captures) do
    captures[#captures + 1] = {mode = capture.mode,status = capture.status}
end
local result = {case = case,disk = disk,decompile_calls = decompileCalls,writes = writes,cancelled = cancelled,
    status = FERAL_TEST.phase,notice = FERAL_TEST.notice,steps = steps,clock = clock,warnings = warnings,clipboard = clipboard,
    blocked_attempts = blockedAttempts,max_active_decompilers = maxActiveDecompilers,compiler_calls = compiling,
    captures = captures,filter_regressions = FERAL_TEST.recoveryCounts.filter_regressions,blocked = FERAL_TEST.blocked,
    compiler_ready = FERAL_TEST.compilerReady,stop_triggered = stopTriggered,pause_triggered = pauseTriggered,test_error = TEST_LAST_ERROR}
dumping = true
local output = assert(io.open(OUTPUT_PATH,"wb"));output:write(json(result));output:close()
