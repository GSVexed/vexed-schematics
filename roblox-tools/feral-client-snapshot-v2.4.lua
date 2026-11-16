-- FERAL Complete Client Snapshot v2.4
-- Passive, one-shot snapshot: NO gameplay steps, no rest/sprint testing.
-- Enumerates client-visible instances, attributes, Value objects, remotes,
-- script metadata and (when supported) client-side decompiled scripts.
-- Does not retrieve server-only code, contact remote services, call remote
-- events/functions, require arbitrary modules, or change gameplay properties.
-- Exports to local executor workspace via writefile if supported; otherwise
-- offers ordered clipboard parts. Treat exports as potentially sensitive.

local Players=game:GetService("Players")
local CollectionService=game:GetService("CollectionService")
local player=Players.LocalPlayer
if not player then warn("[FERAL snapshot] No local player"); return end
local expectedPlaceId=108901361810209
if game.PlaceId~=expectedPlaceId then
    warn("[FERAL snapshot] This snapshot is configured for FERAL PlaceId "..expectedPlaceId)
    return
end

local MAX_INSTANCES=130000
local MAX_INVENTORY_BYTES=32000000
local MAX_SCRIPT_SOURCES=5000
local MAX_SINGLE_SOURCE_BYTES=800000
local MAX_TOTAL_SOURCE_BYTES=48000000
local PART_SIZE=160000
local MAX_STRING_LENGTH=160
local WRITE_FILE=type(writefile)=="function" and writefile or nil
local MAKE_FOLDER=type(makefolder)=="function" and makefolder or nil
local DECOMPILE=type(decompile)=="function" and decompile or nil
local CLIPBOARD=(type(setclipboard)=="function" and setclipboard)
    or (type(toclipboard)=="function" and toclipboard or nil)

local playerGui=player:WaitForChild("PlayerGui")
local guiName="FeralClientSnapshotV24"
local old=playerGui:FindFirstChild(guiName)
if old then old:Destroy() end
local colors={
    bg=Color3.fromRGB(21,27,40),
    surface=Color3.fromRGB(31,42,59),
    edge=Color3.fromRGB(65,83,109),
    ink=Color3.fromRGB(242,247,255),
    muted=Color3.fromRGB(176,195,213),
    blue=Color3.fromRGB(61,126,216),
    green=Color3.fromRGB(40,170,121),
    red=Color3.fromRGB(187,78,91)
}
local function make(kind,properties,parent)
    local obj=Instance.new(kind)
    for name,value in pairs(properties) do obj[name]=value end
    obj.Parent=parent
    return obj
end
local function round(obj,n)
    make("UICorner",{CornerRadius=UDim.new(0,n)},obj)
end
local gui=make("ScreenGui",{
    Name=guiName,ResetOnSpawn=false,DisplayOrder=410,IgnoreGuiInset=true
},playerGui)
local panel=make("Frame",{
    Name="Panel",Size=UDim2.fromOffset(565,379),
    Position=UDim2.fromScale(0.5,0.12),
    AnchorPoint=Vector2.new(0.5,0),
    BackgroundColor3=colors.bg,BorderSizePixel=0,Active=true
},gui)
round(panel,12)
make("UIStroke",{Color=colors.edge,Thickness=1},panel)
local camera=workspace.CurrentCamera
if camera then
    local vp=camera.ViewportSize
    make("UIScale",{
        Scale=math.clamp(math.min(vp.X/620,vp.Y/435),0.55,1)
    },panel)
end
local function label(name,msg,x,y,w,h,size,color,bold)
    return make("TextLabel",{
        Name=name,Text=msg,
        Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),
        BackgroundTransparency=1,TextColor3=color or colors.ink,
        Font=bold and Enum.Font.GothamBold or Enum.Font.Gotham,
        TextSize=size,TextWrapped=true,
        TextXAlignment=Enum.TextXAlignment.Left,
        TextYAlignment=Enum.TextYAlignment.Center
    },panel)
end
local function button(name,msg,x,y,w,h,col)
    local b=make("TextButton",{
        Name=name,Text=msg,
        Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),
        BackgroundColor3=col,BorderSizePixel=0,
        TextSize=12,Font=Enum.Font.GothamBold,TextColor3=colors.ink
    },panel)
    round(b,7)
    return b
end
label("Heading","FERAL  /  COMPLETE CLIENT SNAPSHOT",14,8,480,25,15,colors.ink,true)
label("Subheading","v2.4 • inventory + client code (if decompiler available) • no gameplay tests",
    14,35,520,23,11,colors.muted,false)
local close=button("Close","X",528,12,26,25,colors.red)
local status=label("Status","Starting snapshot automatically...",14,71,536,33,13,colors.green,true)
local statistics=label("Statistics","Collecting accessible objects.",14,108,536,42,12,colors.ink,false)
local capability=label("Capabilities",
    "Checking local file export and optional client-script decompiler...",
    14,151,535,35,11,colors.muted,false)
local note=label("Notes",
    "No Rest, sprint or damage required. No remote calls or server-side code extraction.",
    14,192,535,38,11,colors.muted,false)
local copySummary=button("CopySummary","COPY SUMMARY",14,244,160,42,colors.blue)
local copyNext=button("CopyNext","COPY NEXT PART",184,244,185,42,colors.blue)
local rescan=button("Rescan","RESCAN",379,244,173,42,colors.green)
local output=make("TextBox",{
    Name="Preview",Text="Snapshot report will appear here.",
    Position=UDim2.fromOffset(14,298),Size=UDim2.fromOffset(538,65),
    BackgroundColor3=colors.surface,BorderSizePixel=0,
    ClearTextOnFocus=false,TextEditable=true,MultiLine=true,
    TextColor3=colors.ink,TextSize=10,Font=Enum.Font.Code,
    TextWrapped=false,TextXAlignment=Enum.TextXAlignment.Left,
    TextYAlignment=Enum.TextYAlignment.Top
},panel)
round(output,8)
make("UIPadding",{
    PaddingLeft=UDim.new(0,8),PaddingRight=UDim.new(0,8),
    PaddingTop=UDim.new(0,6),PaddingBottom=UDim.new(0,6)
},output)

local running=false
local active=true
local generation=0
local summaryText=""
local parts={}
local nextPart=1
local scripts={}
local inventoryParts={}
local inventorySize=0
local currentInventory={}
local currentInventoryBytes=0
local sourceBytes=0
local savedFiles=0
local exportErrors=0
local visited=0
local nodeErrors=0
local scriptCount=0
local remoteCount=0
local valueCount=0
local decompiledCount=0
local decompileFailed=0
local decompileSkipped=0
local statsByClass={}
local sampleScriptFailures={}
local cappedInventory=false
local cappedNodes=false
local cappedSources=false
local exportRoot=""
local decompilerStatus="Not checked"
local writeStatus="Not checked"

local function cleanName(s)
    s=tostring(s or "Object")
    s=s:gsub("[^%w_%-%.]","_")
    return s:sub(1,55)
end
local function safeValue(v,fullStrings)
    local k=typeof(v)
    if k=="nil" then return "nil" end
    if k=="string" then
        if not fullStrings then return "[string "..#v.." chars]" end
        return string.format("%q",v:sub(1,MAX_STRING_LENGTH)):gsub("\n","\\n")
    end
    if k=="number" or k=="boolean" then return tostring(v) end
    if k=="Instance" then return "[Instance:"..v.ClassName.."]" end
    if k=="table" then return "[table]" end
    local text=tostring(v)
    return #text>MAX_STRING_LENGTH and text:sub(1,MAX_STRING_LENGTH).."…" or text
end
local function safeGet(obj,property)
    local ok,result=pcall(function() return obj[property] end)
    if ok then return result end
    return nil
end
local function getClass(inst)
    return safeGet(inst,"ClassName") or "?"
end
local function appendInventory(line)
    if cappedInventory then return end
    local n=#line+1
    if inventorySize+n>MAX_INVENTORY_BYTES then
        cappedInventory=true
        return
    end
    inventorySize=inventorySize+n
    table.insert(currentInventory,line)
    currentInventoryBytes=currentInventoryBytes+n
    if currentInventoryBytes>=PART_SIZE then
        table.insert(inventoryParts,table.concat(currentInventory,"\n"))
        currentInventory={}
        currentInventoryBytes=0
    end
end
local function flushInventory()
    if #currentInventory>0 then
        table.insert(inventoryParts,table.concat(currentInventory,"\n"))
        currentInventory={}
        currentInventoryBytes=0
    end
end
local function getScriptType(inst)
    local class=getClass(inst)
    if class=="LocalScript" or class=="ModuleScript" then return class end
    if class=="Script" then
        local run=safeGet(inst,"RunContext")
        if run==Enum.RunContext.Client then return "ClientScript" end
        return "ServerOrUnknownScript"
    end
    return nil
end

local privateChars={}
local function omitInstance(inst)
    if inst==gui or inst:IsDescendantOf(gui) then return true end
    if inst:IsA("Player") and inst~=player then return true end
    for _,char in ipairs(privateChars) do
        if inst==char or inst:IsDescendantOf(char) then return true end
    end
    return false
end
local function collectPrivateChars()
    privateChars={}
    for _,other in ipairs(Players:GetPlayers()) do
        if other~=player and other.Character then
            table.insert(privateChars,other.Character)
        end
    end
end
local function pathName(parentPath,inst)
    if inst==player then return "Players/LocalPlayer" end
    return parentPath.."/"..inst.Name:gsub("\n","_"):sub(1,88)
end
local function getAttributes(inst)
    local ok,attrs=pcall(function() return inst:GetAttributes() end)
    if not ok or type(attrs)~="table" then return "" end
    local names={}
    for k in pairs(attrs) do table.insert(names,k) end
    table.sort(names)
    local a={}
    for _,key in ipairs(names) do
        local low=key:lower()
        local full=(low:find("stamina",1,true) or low:find("health",1,true)
            or low:find("rest",1,true) or low:find("regen",1,true)
            or low:find("burst",1,true) or low:find("sprint",1,true))
        table.insert(a,tostring(key).."="..safeValue(attrs[key],full))
    end
    return #a>0 and " | Attributes{"..table.concat(a,", ").."}" or ""
end
local function getExtras(inst)
    local class=getClass(inst)
    local extras={}
    if inst:IsA("ValueBase") then
        valueCount=valueCount+1
        local v=safeGet(inst,"Value")
        -- StringValue might contain personal data; do not export raw string values.
        table.insert(extras,"Value="..safeValue(v,false))
    end
    if inst:IsA("BasePart") then
        for _,key in ipairs({"Position","Size","Anchored","CanCollide","Transparency"}) do
            local v=safeGet(inst,key)
            if v~=nil then table.insert(extras,key.."="..safeValue(v,true)) end
        end
    end
    if inst:IsA("Humanoid") then
        for _,key in ipairs({"Health","MaxHealth","WalkSpeed","JumpPower"}) do
            local v=safeGet(inst,key)
            if v~=nil then table.insert(extras,key.."="..safeValue(v,true)) end
        end
    end
    if inst:IsA("GuiObject") then
        local visible=safeGet(inst,"Visible")
        if visible~=nil then table.insert(extras,"Visible="..tostring(visible)) end
    end
    if inst:IsA("RemoteEvent") or inst:IsA("RemoteFunction") or
       inst:IsA("UnreliableRemoteEvent") or inst:IsA("BindableEvent") or
       inst:IsA("BindableFunction") then
        remoteCount=remoteCount+1
    end
    local ok,tags=pcall(function() return CollectionService:GetTags(inst) end)
    if ok and type(tags)=="table" and #tags>0 then
        table.insert(extras,"Tags="..table.concat(tags,","))
    end
    return #extras>0 and " | "..table.concat(extras,", ") or ""
end
local function isRelevantName(name)
    name=string.lower(tostring(name))
    for _,word in ipairs({"stamina","health","heal","regen","recover","rest",
        "exhaust","burst","sprint","energy","damage","bleed","feed"}) do
        if name:find(word,1,true) then return true end
    end
    return false
end

local function newExportRoot()
    exportRoot=""
    if not WRITE_FILE then writeStatus="Unavailable (use clipboard parts)"; return end
    if MAKE_FOLDER then
        local folder="FERAL_Client_Snapshot_v2_4"
        local ok=pcall(MAKE_FOLDER,folder)
        if ok or (type(isfolder)=="function" and pcall(function()
             return isfolder(folder) end)) then
            exportRoot=folder
            local child=folder.."/client_scripts"
            local okChild=pcall(MAKE_FOLDER,child)
            if not okChild and type(isfolder)=="function" then
                local possible,exists=pcall(isfolder,child)
                okChild=possible and exists
            end
            if okChild then
                writeStatus="Workspace files: "..folder
            else
                writeStatus="Workspace files (flat): "..folder
            end
        end
    end
    if exportRoot=="" then
        writeStatus="Workspace files with prefix FERAL_v24_"
    end
end
local function filePath(filename,nested)
    if exportRoot~="" then
        if nested then
            local inner=exportRoot.."/client_scripts"
            local exists=false
            if type(isfolder)=="function" then
                local ok,r=pcall(isfolder,inner)
                exists=ok and r
            end
            if exists then return inner.."/"..filename end
        end
        return exportRoot.."/"..filename
    end
    return "FERAL_v24_"..filename
end
local function save(filename,content,nested)
    if not WRITE_FILE then return false end
    local ok=pcall(WRITE_FILE,filePath(filename,nested),content)
    if ok then savedFiles=savedFiles+1; return true end
    exportErrors=exportErrors+1
    return false
end
local function appendCopyPart(name,content)
    local start=1
    if #content==0 then return end
    while start<=#content do
        local ending=math.min(#content,start+PART_SIZE-1)
        table.insert(parts,{
            name=name,
            content=content:sub(start,ending)
        })
        start=ending+1
    end
end
local function exportScripts()
    decompilerStatus=DECOMPILE and "Supported function present" or "Unavailable"
    if not DECOMPILE then return end
    for i,entry in ipairs(scripts) do
        if not active then break end
        local codeType=entry.scriptType
        local allowed=(codeType~="ServerOrUnknownScript")
        if allowed and decompiledCount+decompileFailed<MAX_SCRIPT_SOURCES
            and sourceBytes<MAX_TOTAL_SOURCE_BYTES then
            status.Text="Reading client scripts: "..i.." / "..#scripts
            local ok,result=pcall(DECOMPILE,entry.instance)
            if ok and type(result)=="string" and #result>0 then
                local bytes=math.min(#result,MAX_SINGLE_SOURCE_BYTES,
                    MAX_TOTAL_SOURCE_BYTES-sourceBytes)
                local body=result:sub(1,bytes)
                if bytes<#result then
                    body=body.."\n-- [Snapshot truncated script: source export limit reached]"
                    cappedSources=true
                end
                sourceBytes=sourceBytes+bytes
                decompiledCount=decompiledCount+1
                local filename=string.format("%05d_%s.lua",i,cleanName(entry.name))
                if not save(filename,body,true) then
                    appendCopyPart(filename,body)
                end
                entry.sourceStatus="exported "..bytes.." bytes"
            else
                decompileFailed=decompileFailed+1
                local err=tostring(result)
                entry.sourceStatus="failed: "..err:sub(1,130)
                if #sampleScriptFailures<14 then
                    table.insert(sampleScriptFailures,entry.path.." = "..entry.sourceStatus)
                end
            end
        else
            decompileSkipped=decompileSkipped+1
            entry.sourceStatus=allowed and "export limit" or "not a client script"
        end
        if i%2==0 then task.wait() end
    end
end
local function makeReport()
    local classes={}
    for name,count in pairs(statsByClass) do
        table.insert(classes,{name=name,count=count})
    end
    table.sort(classes,function(a,b)
        if a.count==b.count then return a.name<b.name end
        return a.count>b.count
    end)
    local out={
        "=== FERAL COMPLETE CLIENT SNAPSHOT v2.4 ===",
        "PlaceId: "..tostring(game.PlaceId),
        "Snapshot: single one-shot client-visible inventory (no gameplay test)",
        "Objects: "..visited..(cappedNodes and " (CAP HIT)" or ""),
        "Script instances: "..scriptCount,
        "Remotes + bindables: "..remoteCount,
        "Value objects: "..valueCount,
        "Inventory bytes: "..inventorySize..(cappedInventory and " (CAP HIT)" or ""),
        "Decompilation API: "..decompilerStatus,
        "Client scripts successfully decompiled: "..decompiledCount,
        "Decompiler failures: "..decompileFailed,
        "Scripts not attempted: "..decompileSkipped,
        "Exported code bytes: "..sourceBytes..(cappedSources and " (LIMIT)" or ""),
        "Local files written: "..savedFiles,
        "Local file export: "..writeStatus,
        "Write errors: "..exportErrors,
        "Read/scan warnings: "..nodeErrors,
        "Clipboard parts held: "..#parts,
        "",
        "=== INSTANCE CLASS COUNTS ==="
    }
    for _,x in ipairs(classes) do
        table.insert(out,x.name.." = "..x.count)
    end
    table.insert(out,"")
    table.insert(out,"=== ALL CLIENT-VISIBLE SCRIPT INSTANCES ===")
    for i,e in ipairs(scripts) do
        table.insert(out,string.format(
            "%d | %s | %s | source %s",
            i,e.scriptType,e.path,e.sourceStatus or "not available"))
    end
    table.insert(out,"")
    table.insert(out,"=== DECOMPILER ERRORS (SAMPLES) ===")
    for _,x in ipairs(sampleScriptFailures) do table.insert(out,x) end
    table.insert(out,"")
    table.insert(out,"=== LIMITATIONS ===")
    table.insert(out,"Server-only scripts and private server checks are not replicated to clients.")
    table.insert(out,"A decompiler yields approximate reconstructed source, not the original project.")
    table.insert(out,"StreamingEnabled may keep some world objects unloaded or absent.")
    table.insert(out,"This snapshot omits OTHER players' characters/Player objects and raw chat/text inputs.")
    table.insert(out,"Byte/instance limits are reported above; export may not include literally every object.")
    table.insert(out,"No remotes called, no arbitrary modules executed, no state changed.")
    table.insert(out,"Exports remain local and are never automatically sent anywhere.")
    table.insert(out,"Do not share raw source exports publicly; they may contain private implementation details.")
    table.insert(out,"=== END ===")
    return table.concat(out,"\n")
end
local function resetData()
    summaryText=""
    parts={}
    nextPart=1
    scripts={}
    inventoryParts={}
    inventorySize=0
    currentInventory={}
    currentInventoryBytes=0
    sourceBytes=0
    savedFiles=0
    exportErrors=0
    visited=0
    nodeErrors=0
    scriptCount=0
    remoteCount=0
    valueCount=0
    decompiledCount=0
    decompileFailed=0
    decompileSkipped=0
    statsByClass={}
    sampleScriptFailures={}
    cappedInventory=false
    cappedNodes=false
    cappedSources=false
end

local function scanOnce()
    if running then return end
    running=true
    generation=generation+1
    local myGeneration=generation
    resetData()
    status.Text="Scanning client-visible objects..."
    status.TextColor3=colors.green
    copyNext.Text="COPY NEXT PART"
    newExportRoot()
    collectPrivateChars()
    local queue={{object=game,path="game"}}
    local head=1
    while head<=#queue and active and myGeneration==generation do
        if visited>=MAX_INSTANCES then cappedNodes=true; break end
        local current=queue[head]
        queue[head]=false
        head=head+1
        local inst=current.object
        if not omitInstance(inst) then
            visited=visited+1
            local class=getClass(inst)
            statsByClass[class]=(statsByClass[class] or 0)+1
            local p=current.path
            if inst~=game then
                appendInventory(p.." | "..class..
                    getAttributes(inst)..getExtras(inst))
            end
            local scriptType=getScriptType(inst)
            if scriptType then
                scriptCount=scriptCount+1
                table.insert(scripts,{
                    instance=inst,path=p,name=inst.Name,scriptType=scriptType
                })
            end
            local ok,children=pcall(function() return inst:GetChildren() end)
            if ok then
                for _,child in ipairs(children) do
                    if not omitInstance(child) then
                        table.insert(queue,{object=child,path=pathName(p,child)})
                    end
                end
            else
                nodeErrors=nodeErrors+1
            end
        end
        if visited%130==0 then
            status.Text="Scanning: "..visited.." objects | "..scriptCount.." scripts"
            task.wait()
        end
    end
    flushInventory()
    if not active or myGeneration~=generation then running=false;return end
    status.Text="Found "..visited.." objects. Exporting inventory..."
    for i,part in ipairs(inventoryParts) do
        local filename=string.format("inventory_%03d.txt",i)
        if not save(filename,part,false) then appendCopyPart(filename,part) end
    end
    inventoryParts={}
    task.wait()
    if not active or myGeneration~=generation then running=false;return end
    exportScripts()
    summaryText=makeReport()
    if not save("summary.txt",summaryText,false) then
        appendCopyPart("summary.txt",summaryText)
    end
    output.Text=summaryText:sub(1,3000)
    status.Text="SNAPSHOT COMPLETE  •  "..visited.." objects  •  "..
        decompiledCount.." client code files"
    status.TextColor3=colors.green
    statistics.Text="Scripts: "..scriptCount.." | Remotes: "..remoteCount..
        " | Values: "..valueCount.." | Local files: "..savedFiles
    capability.Text="Decompiler: "..decompilerStatus.." | Export: "..writeStatus
    note.Text=#parts>0 and
        ("Clipboard backup: "..#parts.." parts. Use COPY NEXT PART sequentially.") or
        "Saved to executor workspace. Use COPY SUMMARY for a short index."
    copyNext.Text=#parts>0 and ("COPY PART 1 / "..#parts) or "NO CLIP PARTS"
    running=false
end

local function copy(value)
    if CLIPBOARD then
        local ok=pcall(CLIPBOARD,value)
        if ok then return true end
    end
    return false
end
copySummary.Activated:Connect(function()
    if summaryText=="" then
        status.Text="Snapshot not finished; no summary yet."
    elseif copy(summaryText) then
        status.Text="Summary copied to clipboard."
    else
        output.Text=summaryText
        output:CaptureFocus()
        status.Text="No clipboard API; select report text and copy manually."
    end
end)
copyNext.Activated:Connect(function()
    if running then status.Text="Scan still running."; return end
    if #parts==0 then status.Text="All exports saved locally; no clipboard parts.";return end
    if nextPart>#parts then nextPart=1 end
    local p=parts[nextPart]
    local packet="=== FERAL CLIENT SNAPSHOT PART "..nextPart.."/"..#parts..
        " | "..p.name.." ===\n"..p.content
    if copy(packet) then
        status.Text="Copied part "..nextPart.."/"..#parts.." ("..p.name..")"
    else
        output.Text=packet
        output:CaptureFocus()
        status.Text="Select and copy part "..nextPart.." manually."
    end
    nextPart=nextPart+1
    copyNext.Text="COPY PART "..math.min(nextPart,#parts).." / "..#parts
end)
rescan.Activated:Connect(function()
    if running then status.Text="Snapshot already in progress.";return end
    task.spawn(scanOnce)
end)
close.Activated:Connect(function()
    active=false
    generation=generation+1
    gui:Destroy()
end)
gui.Destroying:Connect(function()
    active=false
    generation=generation+1
end)

task.spawn(scanOnce)
