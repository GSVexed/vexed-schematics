-- FERAL NOVA PRIME v33.0 / GUARDED STARTUP AND RECOVERY
-- Compact entrypoint: verify source, trap errors, show an in-game status and
-- try the v32 bundle, then individually fetched modules, then v26 fallback.
-- Every outcome is visibly identified; an older fallback is never called v32.
local REPO="https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/"
local PLACE=108901361810209
local VERSION="v33"
local trace={}
local stage="starting"
local outcome="NOT_STARTED"
local label
local screen
local player
local pg
local function clean(value)
    local str=tostring(value or "unknown")
    str=str:gsub("https?://%S+","[URL]")
    str=str:gsub("[A-Za-z]:\\[^%s]+","[LOCAL_PATH]")
    if #str>360 then str=str:sub(1,360)end
    return str
end
local function tell(message)
    local text=clean(message)
    trace[#trace+1]={step=stage,message=text}
    pcall(function()warn("[NOVA BOOT "..VERSION.."] "..text)end)
    if label and label.Parent then
        pcall(function()label.Text="FERAL NOVA PRIME  ·  STARTUP\n"..text..
            "\nThe hub will open automatically if a launch succeeds."
        end)
    end
end
local function store()
    if type(writefile)~="function" then return end
    pcall(function()
        local http=game:GetService("HttpService")
        local data=http:JSONEncode({
            schema="FERAL_NOVA_STARTUP_V33",
            release="v33",phase=stage,outcome=outcome,
            events=trace
        })
        writefile("FERAL_NOVA_STARTUP_v33.json",data)
    end)
end
local function overlay()
    local ok=pcall(function()
        local Players=game:GetService("Players")
        player=Players.LocalPlayer
        if not player then error("No LocalPlayer") end
        pg=player:FindFirstChildOfClass("PlayerGui")
            or player:WaitForChild("PlayerGui",12)
        if not pg then error("No PlayerGui") end
        local previous=pg:FindFirstChild("FERAL_NOVA_V33_LOADER")
        if previous then previous:Destroy()end
        screen=Instance.new("ScreenGui")
        screen.Name="FERAL_NOVA_V33_LOADER"
        screen.ResetOnSpawn=false
        screen.DisplayOrder=100000
        screen.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
        label=Instance.new("TextLabel")
        label.Name="StartupStatus"
        label.Size=UDim2.fromOffset(520,100)
        label.Position=UDim2.new(0,12,1,-114)
        label.BackgroundColor3=Color3.fromRGB(12,22,34)
        label.BackgroundTransparency=.08
        label.TextColor3=Color3.fromRGB(115,240,210)
        label.Font=Enum.Font.GothamBold
        label.TextSize=13
        label.TextXAlignment=Enum.TextXAlignment.Left
        label.TextYAlignment=Enum.TextYAlignment.Center
        label.TextWrapped=true
        label.Text="FERAL NOVA PRIME · Checking startup..."
        label.Parent=screen
        screen.Parent=pg
    end)
    return ok
end
local function getSource(filename)
    stage="download/"..filename
    tell("Downloading "..filename.."...")
    local ok,result=pcall(function()
        return game:HttpGet(REPO..filename)
    end)
    if not ok then return nil,"HTTP failed: "..clean(result)end
    if type(result)~="string" or #result<1500
        or #result>600000 or not result:find("FERAL NOVA PRIME",1,true) then
        return nil,"Unexpected source response ("..
            tostring(type(result)=="string" and #result or type(result)).." bytes)"
    end
    return result
end
local function getGui(version)
    if not pg then return nil end
    return pg:FindFirstChild(version)
end
local function live(expected)
    if not pg then return false end
    local gui=getGui(expected)
    if not gui or not gui.Parent then return false end
    local menu=gui:FindFirstChildWhichIsA("Frame",true)
    if not menu then return false end
    return true
end
local function execute(filename,expected)
    local source,why=getSource(filename)
    if not source then return false,why end
    stage="compile/"..filename
    tell("Compiling "..filename.." ("..#source.." bytes)")
    local ok,fn,detail=pcall(loadstring,source)
    if not ok then return false,"loadstring threw: "..clean(fn)end
    if type(fn)~="function" then
        return false,"Compiler rejected source: "..clean(detail)
    end
    stage="run/"..filename
    tell("Starting "..filename.."...")
    local worked,errorText=xpcall(fn,function(err)
        local traceback=debug and debug.traceback
        if type(traceback)=="function" then
            return traceback(tostring(err),2)
        end
        return tostring(err)
    end)
    if not worked then return false,"Runtime: "..clean(errorText)end
    if type(task)=="table" and type(task.wait)=="function" then
        pcall(function()task.wait(.15)end)
    end
    if not live(expected) then
        return false,"Startup returned without creating "..expected..
            " (check the NOVA warning in executor output)"
    end
    return true,"Loaded "..expected
end

if game.PlaceId~=PLACE then
    stage="wrong_place"
    outcome="WRONG_GAME"
    overlay()
    tell("Open FERAL Animal Survival (place "..PLACE.."). In this place: "..tostring(game.PlaceId))
    store()
    return
end

if not overlay() then
    pcall(function()warn("[NOVA BOOT] PlayerGui unavailable; attempting launch without overlay")end)
end

local tries={
    {
        file="feral-nova-prime-standalone-v32.0.lua",
        gui="FeralNovaPrimeV320",
        label="Complete v32 standalone"
    },
    {
        file="feral-nova-prime-modular-v33.0.lua",
        gui="FeralNovaPrimeV320",
        label="v32 features, individually loaded modules"
    },
    {
        file="feral-nova-prime-standalone-v26.0.lua",
        gui="FeralNovaPrimeV260",
        label="v26 recovery fallback (older features)"
    }
}
for index,attempt in ipairs(tries) do
    stage="attempt_"..index
    tell("Trying "..attempt.label)
    local ok,result=execute(attempt.file,attempt.gui)
    if ok then
        stage="complete"
        outcome=index==3 and "FALLBACK_V26" or index==2 and "MODULAR_V32" or "V32_LOADED"
        tell("Loaded "..attempt.label..
            (index==3 and ". New Eagle improvements unavailable in fallback." or "."))
        store()
        if screen then
            if type(task)=="table" and type(task.delay)=="function" then
                task.delay(index==3 and 16 or 3,function()
                    if screen then pcall(function()screen:Destroy()end)end
                end)
            end
        end
        return
    end
    stage="attempt_"..index.."_failed"
    tell(attempt.label.." failed: "..clean(result))
    store()
end
stage="failed"
outcome="ALL_FAILED"
tell("All launch routes failed. Open Velocity's output for NOVA BOOT messages.")
store()
