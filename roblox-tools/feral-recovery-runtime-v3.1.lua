-- Runtime appended by build-feral-recovery-v3.1.py. This file is not a loader.
D.captures,D.lastSources,D.recoveryCounts = {},{}, {attempts = 0,exported = 0,unexported = 0,syntax_pass = 0,syntax_reject = 0,unchecked = 0,missing = 0,filter_regressions = 0}
D.expectedSpecies,D.traceSeconds,D.traceInterval = "Tiger",30,0.1
D.phase,D.current,D.notice = "ready","Choose MENU CAPTURE first, then spawn as a Tiger and choose IN-GAME CAPTURE.","Nothing starts until you click a capture button."
D.emitBase = D.emit
function D.emit(name,record)
    if D.capture then
        record.capture_id = D.capture.key
        name = "captures/" .. D.capture.key .. "/" .. name
    end
    return D.emitBase(name,record)
end
function D.context()
    local characterOk,character = D.read(player,"Character")
    if not characterOk or typeof(character) ~= "Instance" then character = nil end
    local function attr(obj,key)
        if not obj then return nil end
        local ok,value = pcall(function() return obj:GetAttribute(key) end)
        if ok then return value end
        return nil
    end
    local humanoid = nil
    if character then
        local ok,found = pcall(function() return character:FindFirstChildOfClass("Humanoid") end)
        if ok then humanoid = found end
    end
    local health = nil
    if humanoid then local ok,value = D.read(humanoid,"Health"); if ok then health = value end end
    local species = attr(character,"Species") or attr(player,"FeralAnimal")
    local menu,despawned = attr(player,"FeralMenuOpen"),attr(player,"FeralDespawned")
    local active = character ~= nil and humanoid ~= nil and type(health) == "number" and health > 0 and menu ~= true and despawned ~= true
    return {character_present = character ~= nil,humanoid_present = humanoid ~= nil,health = D.value(health),
        menu_open = D.value(menu),despawned = D.value(despawned),species = D.value(species,"Species",false),
        expected_species = D.expectedSpecies,species_matches = species == D.expectedSpecies,active = active},character,humanoid
end
function D.syntax(source)
    if not D.compilerReady then return {status = "unavailable",reason = D.compilerReason or "not_tested"} end
    -- loadstring returns a compiled closure. It is NEVER invoked, required,
    -- spawned or passed to an execution API. Error text can echo source: omit it.
    local ok,compiled,err = pcall(API.compile,source,"=FERAL_compile_only")
    local kind = type(compiled)
    compiled = nil
    if not ok then return {status = "api_error",reason = "compiler_error_details_withheld"} end
    if kind == "function" then return {status = "pass",execution_attempted = false} end
    local text = type(err) == "string" and err or ""
    local line = tonumber(text:match(":(%d+):"))
    local row,column = text:match("%((%d+),(%d+)%)")
    return {status = "reject",line = line or tonumber(row),column = tonumber(column),
        reason = "compiler_rejected_text_details_withheld",execution_attempted = false}
end
function D.checkCompiler()
    if not API.compile then D.compilerReady,D.compilerReason = false,"loadstring_missing"; return end
    local good,fn = pcall(API.compile,"return 1","=FERAL_compiler_selfcheck")
    local bad,badFn = pcall(API.compile,"local = ","=FERAL_compiler_selfcheck")
    D.compilerReady = good and type(fn) == "function" and bad and type(badFn) ~= "function"
    fn,badFn = nil,nil
    D.compilerReason = D.compilerReady and "selfcheck_passed_without_execution" or "compiler_selfcheck_failed"
end
function D.sourceComparison(rawCheck,filteredCheck)
    if rawCheck.status == "pass" and filteredCheck.status == "reject" then return "filter_regression" end
    if rawCheck.status == "reject" and filteredCheck.status == "reject" then return "invalid_before_and_after_filter" end
    if rawCheck.status == "reject" and filteredCheck.status == "pass" then return "filter_changed_rejected_text_to_parsable" end
    if rawCheck.status == "pass" and filteredCheck.status == "pass" then return "syntax_pass_semantics_unverified" end
    return "syntax_comparison_unavailable"
end
function D.readCanonical(info)
    if not API.read or not info then return nil end
    local chunks = {}
    for _,meta in ipairs(info.files or {}) do
        local ok,body = pcall(API.read,D.root .. "/" .. meta.path)
        if not ok or type(body) ~= "string" or #body ~= meta.bytes or D.adler(body) ~= meta.adler32 then return nil end
        chunks[#chunks + 1] = body
    end
    return table.concat(chunks)
end
function D.exportAttempt(target,body,method,attempt,previousRaw,previousAttempt)
    local record = {target = target.key,path = target.path,previous_id = target.previous_id,attempt = attempt,
        method = method,original_bytes = #body,reconstructed = method == "decompile",original_source_guaranteed = false,
        execution_attempted = false}
    if #body > CFG.maxSingleSourceBytes then
        record.status,record.reason = "not_exported","source_size_limit"
        D.limits.single_source_bytes = true
        D.emit("recovery-attempts/game",record)
        return record
    end
    record.raw_syntax = D.syntax(body)
    -- Conservative gap for a new output format the privacy lexer cannot safely
    -- tokenize. Current baseline targets have no backticks. Never persist raw text.
    if body:find("`",1,true) then
        record.status,record.reason = "not_exported","interpolated_string_format_not_supported_by_privacy_filter"
        D.emit("recovery-attempts/game",record)
        return record
    end
    if previousRaw and body == previousRaw and previousAttempt then
        record.status,record.same_raw_as_previous_attempt = previousAttempt.status,true
        record.filtered_syntax,record.filter_comparison = previousAttempt.filtered_syntax,previousAttempt.filter_comparison
        record.files,record.exported_bytes,record.exported_adler32 = previousAttempt.files,previousAttempt.exported_bytes,previousAttempt.exported_adler32
        record.privacy_edits,record.storage = previousAttempt.privacy_edits,"shared_exact_raw_retry"
        record.matches_baseline_checksum_and_length = previousAttempt.matches_baseline_checksum_and_length
        record.baseline_comparison_is_exact_equality = false
        D.emit("recovery-attempts/game",record)
        return record
    end
    local filtered,edits,hasCode = D.filterSource(body)
    if not hasCode then
        record.status,record.reason = "not_exported","empty_or_comment_only"
        D.emit("recovery-attempts/game",record)
        return record
    end
    record.filtered_syntax = D.syntax(filtered)
    record.filter_comparison = D.sourceComparison(record.raw_syntax,record.filtered_syntax)
    record.exported_bytes,record.exported_adler32,record.privacy_edits = #filtered,D.adler(filtered),edits
    record.matches_baseline_checksum_and_length = #filtered == target.previous_filtered_bytes and record.exported_adler32 == target.previous_filtered_adler32
    record.baseline_comparison_is_exact_equality = false
    local previous = D.lastSources[target.key]
    local canonical = previous and D.readCanonical(previous)
    if canonical and canonical == filtered then
        record.files,record.storage,record.same_filtered_as_previous_capture_or_attempt = previous.files,"shared_exact_filtered_text",true
    else
        record.files,record.storage = {},"new_text"
        if canonical then record.same_filtered_as_previous_capture_or_attempt = false end
        if previous and not canonical then record.previous_text_comparison = "unavailable" end
        for start = 1,#filtered,CFG.sourceChunkBytes do
            local chunk = filtered:sub(start,start + CFG.sourceChunkBytes - 1)
            record.files[#record.files + 1] = D.payload("captures/" .. D.capture.key .. "/sources/game/" .. target.key
                .. string.format("_A%02d_part%03d.source.txt",attempt,#record.files + 1),chunk)
            if not D.cooperate(false) then
                record.status,record.reason = "partial_chunks","stopped_during_source_save"
                D.emit("recovery-attempts/game",record)
                return record
            end
        end
    end
    record.status = "exported"
    D.lastSources[target.key] = {files = record.files,capture = D.capture.key}
    D.c.redactions = D.c.redactions + edits
    if record.filter_comparison == "filter_regression" then D.recoveryCounts.filter_regressions = D.recoveryCounts.filter_regressions + 1 end
    D.emit("recovery-attempts/game",record)
    return record
end
function D.resolveTarget(path)
    local cursor = game
    for segment in path:gmatch("[^/]+") do
        if segment ~= "game" then
            segment = segment:gsub("~1","/"):gsub("~0","~")
            if cursor == Players and segment == "LocalPlayer" then cursor = player
            else
                local ok,found = pcall(function() return cursor:FindFirstChild(segment) end)
                if not ok or not found then return nil,"path_not_present" end
                cursor = found
            end
        end
    end
    if D.private(cursor) then return nil,"privacy_excluded" end
    local ok,class = D.read(cursor,"ClassName")
    local _,eligible = D.scriptType(cursor,ok and class or "")
    if not eligible then return nil,"not_eligible_client_source" end
    return cursor
end
function D.fetchSource(obj,target,attempt)
    local ok,body = D.read(obj,"Source")
    if ok and type(body) == "string" and #body > 0 then return true,body,"Source_property" end
    if not API.decompile then return false,"source_unavailable_no_decompiler","none" end
    local success,result = D.boundedCall(API.decompile,obj,CFG.sourceTimeoutSeconds,
        D.capture.mode .. " | " .. target.key .. " | attempt " .. attempt)
    return success,result,"decompile"
end
function D.recoverTargets()
    D.phase,D.current = "sources","Recovering 71 selected paths; Roblox platform sources remain in the prior export."
    D.capture.target_results = {}
    D.capture.source_status_counts = {}
    D.capture.targets_processed = 0
    local timeoutStreak = 0
    for index,target in ipairs(RECOVERY_PLAN.targets) do
        if not D.cooperate(false) or D.sourceAbortReason then break end
        D.sourceCursor = index
        D.current = string.format("%s sources: %d / %d | %s",D.capture.mode,index,#RECOVERY_PLAN.targets,target.key)
        local obj,missing = D.resolveTarget(target.path)
        local result = {target = target.key,path = target.path,previous_id = target.previous_id,reason_for_review = target.reason,
            attempted = false,attempts = 0,status = missing or "not_attempted"}
        if obj then
            result.instance_id,result.attempted = D.id(obj),true
            local lastRaw,lastAttempt = nil,nil
            for attempt = 1,2 do
                if D.stop or D.sourceAbortReason then break end
                local ok,body,method = D.fetchSource(obj,target,attempt)
                D.recoveryCounts.attempts = D.recoveryCounts.attempts + 1
                result.attempts = attempt
                if not ok or type(body) ~= "string" or #body == 0 then
                    local reason = body == "timeout" and "timeout" or body == "uncancellable_worker" and body
                        or body == "cancelled" and body or body == "source_unavailable_no_decompiler" and body or "source_api_error_or_empty"
                    D.emit("recovery-attempts/game",{target = target.key,path = target.path,attempt = attempt,method = method,status = "failed",reason = reason})
                    result.last_attempt_status = reason
                    if reason == "timeout" then
                        timeoutStreak = timeoutStreak + 1
                        if timeoutStreak >= CFG.maxConsecutiveTimeouts then D.sourceAbortReason = "repeated_decompiler_timeouts" end
                    else timeoutStreak = 0 end
                    if result.status ~= "exported" then result.status = reason end
                    if reason == "timeout" or reason == "uncancellable_worker" or reason == "cancelled" then break end
                else
                    timeoutStreak = 0
                    local attemptResult = D.exportAttempt(target,body,method,attempt,lastRaw,lastAttempt)
                    result.last_attempt_status = attemptResult.status
                    if attemptResult.status == "exported" then
                        result.status,result.selected_attempt,result.files = "exported",attempt,attemptResult.files
                        result.raw_syntax,result.filtered_syntax,result.filter_comparison = attemptResult.raw_syntax,attemptResult.filtered_syntax,attemptResult.filter_comparison
                        result.exported_bytes,result.exported_adler32 = attemptResult.exported_bytes,attemptResult.exported_adler32
                        result.matches_baseline_checksum_and_length = attemptResult.matches_baseline_checksum_and_length
                    elseif result.status ~= "exported" then result.status = attemptResult.reason or attemptResult.status end
                    if attemptResult.same_raw_as_previous_attempt then result.identical_retry_stopped = true; break end
                    if not attemptResult.filtered_syntax or attemptResult.filtered_syntax.status ~= "reject" then break end
                    lastRaw,lastAttempt = body,attemptResult
                end
                if not D.cooperate(true) then break end
            end
            lastRaw,lastAttempt,obj = nil,nil,nil
        else D.recoveryCounts.missing = D.recoveryCounts.missing + 1 end
        if result.status == "exported" then
            D.recoveryCounts.exported = D.recoveryCounts.exported + 1
            local status = result.filtered_syntax and result.filtered_syntax.status
            local key = status == "pass" and "syntax_pass" or status == "reject" and "syntax_reject" or "unchecked"
            D.recoveryCounts[key] = D.recoveryCounts[key] + 1
        else D.recoveryCounts.unexported = D.recoveryCounts.unexported + 1 end
        D.capture.target_results[#D.capture.target_results + 1] = result
        D.capture.source_status_counts[result.status] = (D.capture.source_status_counts[result.status] or 0) + 1
        D.capture.targets_processed = #D.capture.target_results
        D.emit("target-results/game",result)
    end
    -- Every target receives an explicit terminal record, including after Stop.
    for index = #D.capture.target_results + 1,#RECOVERY_PLAN.targets do
        local target = RECOVERY_PLAN.targets[index]
        local result = {target = target.key,path = target.path,attempted = false,attempts = 0,
            status = D.sourceAbortReason or (D.stop and "stopped_before_target" or "not_attempted")}
        D.capture.target_results[#D.capture.target_results + 1] = result
        D.capture.source_status_counts[result.status] = (D.capture.source_status_counts[result.status] or 0) + 1
        D.recoveryCounts.unexported = D.recoveryCounts.unexported + 1
        D.emit("target-results/game",result)
    end
    D.capture.source_pass_finished = not D.stop and not D.sourceAbortReason
    D.capture.targets_terminal = #D.capture.target_results
end
function D.setupPrivacy()
    D.refreshPrivacy()
    local ok,conn = pcall(function() return Players.PlayerAdded:Connect(function(other)
        if other ~= player then
            D.addPrivate(other)
            D.refreshPrivacy()
            D.watchers[#D.watchers + 1] = other.CharacterAdded:Connect(D.addPrivate)
        end
    end) end)
    if ok then D.watchers[#D.watchers + 1] = conn end
    local valid,list = pcall(function() return Players:GetPlayers() end)
    if valid then
        for _,other in ipairs(list) do if other ~= player then
            D.watchers[#D.watchers + 1] = other.CharacterAdded:Connect(D.addPrivate)
        end end
    end
end
function D.attributes(obj)
    if not obj then return {} end
    local ok,values = pcall(function() return obj:GetAttributes() end)
    if not ok then D.c.attributeFailures = D.c.attributeFailures + 1; return {unavailable = true} end
    local safe = {}
    for key,value in pairs(values) do
        local safeKey = D.secretString(key) and "[redacted-key]" or key
        safe[safeKey] = D.value(value,key,true)
    end
    return safe
end
function D.observe()
    local duration = D.capture.mode == "ingame" and D.traceSeconds or 2
    D.phase = "observing"
    local begin = os.clock()
    local pausedBefore = D.pausedSeconds or 0
    local function activeSeconds() return os.clock() - begin - ((D.pausedSeconds or 0) - pausedBefore) end
    D.capture.trace_samples,D.capture.trace_requested_seconds = 0,duration
    while activeSeconds() < duration and D.cooperate(false) do
        local context,character,humanoid = D.context()
        local props = {}
        if humanoid then
            for _,key in ipairs({"Health","MaxHealth","WalkSpeed","MoveDirection","FloorMaterial","Sit","PlatformStand"}) do
                local ok,value = D.read(humanoid,key)
                if ok then props[key] = D.value(value,key,false) end
            end
        end
        D.emit("observations/local",{seconds = os.clock() - begin,active_seconds = activeSeconds(),context = context,
            character_id = character and D.id(character) or nil,humanoid = props,
            character_attributes = D.attributes(character),player_attributes = D.attributes(player)})
        D.capture.trace_samples = D.capture.trace_samples + 1
        D.current = string.format("%s observation: %.1f / %ds | expected Tiger; active=%s",D.capture.mode,activeSeconds(),duration,tostring(context.active))
        task.wait(D.traceInterval)
    end
    D.capture.trace_observed_seconds = os.clock() - begin
    D.capture.trace_active_seconds = activeSeconds()
    D.capture.trace_finished = not D.stop and D.capture.trace_active_seconds >= duration
end
function D.captureInventory()
    D.phase = "inventory"
    D.visited,D.scripts,D.buckets = {},{},{{},{},{},{}}
    local complete = true
    -- Include ancestor context without traversing other Player roots. New
    -- instance IDs belong to this supplement, not the previous full scan.
    D.inspect(game,{path = "",category = "game"})
    D.inspect(Players,{path = "game",category = "game",service = "Players",parentId = D.id(game)})
    -- The previous complete export preserves platform roots. These additional
    -- observations cover current replicated game roots and this player's state.
    for _,name in ipairs({"ReplicatedFirst","ReplicatedStorage","Workspace","Lighting","SoundService","StarterPlayer","StarterGui","StarterPack","Teams"}) do
        if D.stop then complete = false; break end
        local root = game:FindFirstChild(name)
        if root then
            if not D.walk(root,{path = "game",category = "game",service = name,parentId = D.id(game)}) then complete = false end
        else D.emit("logs/scope",{root = name,status = "not_present"}) end
    end
    if not D.stop then
        if not D.walk(player,{path = "game/Players",category = "game",service = "Players",parentId = D.id(Players)}) then complete = false end
    else complete = false end
    local targetPaths = {}
    for _,target in ipairs(RECOVERY_PLAN.targets) do targetPaths[target.path] = true end
    for _,entry in ipairs(D.scripts) do
        if entry.eligible and not targetPaths[entry.path] then
            D.emit("source-scope/" .. entry.category,{id = entry.id,path = entry.path,status = "outside_targeted_source_pass",
                reason = "preserved_in_prior_full_export_or_requires_separate_followup_if_new"})
        end
    end
    D.capture.inventory_traversal_exhausted = complete
    D.scripts,D.buckets,D.visited = {},{{},{},{},{}},{}
end
function D.summary()
    local lines = {"FERAL Recovery Supplement v3.1 | " .. D.phase,
        "Folder: " .. (D.root ~= "" and D.root or "created when you capture"),
        "Buttons: MENU CAPTURE, then IN-GAME CAPTURE after spawning as a Tiger.",
        "Targets: 64 previous syntax failures + 7 semantic-review paths. Prior full export is retained.",
        "Session target results: " .. D.recoveryCounts.exported .. " exported | " .. D.recoveryCounts.unexported .. " unexported | " .. D.recoveryCounts.syntax_pass .. " syntax pass | "
            .. D.recoveryCounts.syntax_reject .. " syntax reject | " .. D.recoveryCounts.unchecked .. " unchecked",
        "Filter regressions: " .. D.recoveryCounts.filter_regressions .. " | missing paths: " .. D.recoveryCounts.missing,
        "Payloads: " .. D.payloadCount .. " | verified: " .. D.verifiedCount .. " | write errors: " .. D.c.writeErrors,
        "Compiler: " .. (D.compilerReason or "checked after first capture"),
        "No reconstructed code is executed. Syntax pass does not prove faithful reconstruction.",
        "ZIP this ENTIRE folder after both captures; upload that ZIP. No need to upload the old scan again."}
    for _,capture in ipairs(D.captures) do
        lines[#lines + 1] = capture.key .. ": " .. capture.status .. " | source pass " .. tostring(capture.source_pass_finished == true)
            .. " | trace " .. tostring(capture.trace_samples or 0) .. " samples"
    end
    if D.sourceAbortReason then lines[#lines + 1] = "Source stop reason: " .. D.sourceAbortReason end
    return table.concat(lines,"\n")
end
function D.manifest()
    local controls,streams,captures = {},{},{}
    for _,meta in pairs(D.controls) do controls[#controls + 1] = meta end
    for name,stream in pairs(D.streams) do streams[name] = {chunks = stream.number,records = stream.records,buffered_bytes = stream.bytes} end
    for _,capture in ipairs(D.captures) do
        local item = {}
        for key,value in pairs(capture) do if key ~= "target_results" then item[key] = value end end
        captures[#captures + 1] = item
    end
    return {schema = "feral-recovery-supplement/3.1",version = CFG.version,session_id = D.session,place_id = game.PlaceId,
        phase = D.phase,started_utc = D.startedUtc,updated_utc = os.date("!%Y-%m-%dT%H:%M:%SZ"),checkpoint = D.checkpointNumber,
        elapsed_seconds = math.floor(os.clock() - D.started),baseline_session = RECOVERY_PLAN.baseline_session,
        target_count = #RECOVERY_PLAN.targets,known_syntax_failure_targets = 64,additional_semantic_review_targets = 7,
        target_plan_file = D.controls["target-plan.json"] and D.controls["target-plan.json"].path or nil,
        captures = captures,recovery_counts = D.recoveryCounts,inventory_counts_are_cumulative_observations = true,counts = D.c,
        files = {payload_count = D.payloadCount,payload_bytes = D.filesBytes,read_back_verified = D.verifiedCount,
            unverified = D.unverifiedCount,checksum_algorithm = "adler32",checksums_are_authentication = false},
        catalogs = D.catalogs,controls = controls,streams = streams,upload_parts = D.partList(),output_format = "data_only_text",
        privacy_filter_applied = true,exact_original_sources = false,syntax_is_not_semantic_verification = true,
        raw_sources_exported = false,reconstructed_code_executed = false,gameplay_writes = false,remotes_invoked = false,
        compiler_ready = D.compilerReady == true,compiler_reason = D.compilerReason,capabilities = apiOrigins,
        last_file_failure = D.lastWriteFailure,limits_hit = D.limits,source_abort_reason = D.sourceAbortReason,
        scope = "71 source paths plus game-root inventory and local observations in each selected mode; supplements previous full export",
        collection_gaps = {"server_only_or_unreplicated_content","streamed_out_or_changed_instances","privacy_exclusions",
            "properties_outside_explicit_schema","sources_outside_target_plan","platform_sources_retained_in_prior_export",
            "runtime_function_state_and_module_returns_not_inspected","interpolated_string_sources_omitted_if_present"}}
end
function D.preflight()
    D.stage("checking_file_apis","Checking text export support...")
    if not API.write or not API.mkdir then D.failureCode = "missing_file_apis"; error("writefile/makefolder required",0) end
    local ok,guid = pcall(function() return Http:GenerateGUID(false) end)
    D.session = os.date("!%Y%m%d_%H%M%S") .. "_" .. (ok and guid:gsub("[^%w]",""):sub(1,12) or tostring(math.random(100000,999999)))
    D.root = "FERAL_Recovery_v3_1_" .. D.session
    if API.isfolder then local valid,exists = pcall(API.isfolder,D.root); if valid and exists then error("Folder collision",0) end end
    if not D.mkdir(D.root) then error("Cannot create export folder",0) end
    D.control("startup-check.txt","FERAL Recovery v3.1 text write/read probe\n")
    D.checkCompiler()
    D.control("target-plan.json",D.encode(RECOVERY_PLAN))
    local instructions = "FERAL Recovery Supplement v3.1\n\n1. Click MENU CAPTURE while in FERAL's animal menu; wait for it to finish.\n"
        .. "2. Spawn as a Tiger. Click IN-GAME CAPTURE. Stay alive for its 30-second observation, then wait for sources/inventory.\n"
        .. "3. After both captures finish, right-click this ENTIRE folder in Windows 11 > Compress to ZIP file. Upload that ZIP.\n"
        .. "If too large, ZIP and upload EVERY UPLOAD_PART_* folder, including part 000 metadata.\n\n"
        .. "This supplements baseline " .. RECOVERY_PLAN.baseline_session .. ". Keep the old full export. No automatic uploads occur.\n"
        .. "Only privacy-filtered text is exported. Raw sources are compile-checked in memory and discarded; compiled functions are never called.\n"
        .. "A decompiler can return the same invalid text twice. Syntax errors are recorded, not repaired or presented as recovered logic.\n"
        .. "STOP & SAVE keeps completed data. The window stays available between captures. Minimise/Hide uses the FERAL SHOW button.\n"
    D.control("README.txt",instructions)
    D.rawWrite("READ_FIRST.txt",instructions)
    D.control("coverage.json",D.encode({schema = "feral-recovery-coverage/3.1",configuration = CFG,properties_by_base_class = D.properties,
        source_targets = "64 prior syntax-failing file sets and 7 suspicious passing paths; resolved by path, not old IDs",
        source_retries = "At most two reads/decompilations per path per capture. Exact identical raw retries stop. Exact filtered text can share verified prior files.",
        syntax_checks = "loadstring compiler capability self-tested; compile returned closures never executed. Raw and filtered parse statuses compared.",
        compiler_limit = "Native calls can block the client; cooperative timeouts cannot guarantee preemption. One decompiler at a time.",
        observation = "LocalPlayer and own character only; no event interception. Requested sample interval 0.1 seconds; actual times recorded.",
        privacy = "No other-player subtrees, chat text/input, credentials, raw source, raw compiler error messages or raw bytecode exported.",
        scope = "Existing full export is preserved. Current game roots are inventoried; no repeat of full CorePackages/CoreGui source collection.",
        not_attempted = {"gameplay writes","remote calls","require of game modules","debug/getgc inspection","server-only sources","hidden properties"},
        snapshot_is_atomic = false,source_syntax_does_not_guarantee_semantics = true}))
    D.initialized = true
    D.checkpoint()
end
function D.runCapture(mode)
    D.capture = nil
    if not D.initialized then D.preflight() end
    local capture = {key = string.format("C%03d_%s",#D.captures + 1,mode),mode = mode,status = "running",
        started_utc = os.date("!%Y-%m-%dT%H:%M:%SZ"),context_at_start = D.context(),expected_species = D.expectedSpecies,
        target_count = #RECOVERY_PLAN.targets,targets_processed = 0}
    D.capture = capture
    D.captures[#D.captures + 1] = capture
    D.sourceCursor = 0
    D.setupPrivacy()
    D.observe()
    -- Targeted recovery is saved before the potentially much larger world inventory.
    D.recoverTargets()
    D.checkpoint()
    if not D.stop and not D.sourceAbortReason then D.captureInventory() end
    capture.context_at_end = D.context()
    capture.finished_utc = os.date("!%Y-%m-%dT%H:%M:%SZ")
    capture.status = D.stop and "stopped_partial" or D.sourceAbortReason and "source_gaps" or "finished"
    capture.limits_hit = {}
    for key,value in pairs(D.limits) do capture.limits_hit[key] = value end
    D.emit("capture-summary",{capture = capture.key,status = capture.status,context = capture.context_at_end,
        targets_processed = capture.targets_processed,inventory_traversal_exhausted = capture.inventory_traversal_exhausted,
        source_pass_finished = capture.source_pass_finished,trace_finished = capture.trace_finished})
    local menu,ingame = false,false
    for _,item in ipairs(D.captures) do
        if item.status == "finished" then
            if item.mode == "menu" then menu = true else ingame = true end
        end
    end
    D.phase = D.stop and "stopped_partial" or D.sourceAbortReason and "finished_with_source_gaps" or (menu and ingame and "finished" or "awaiting_other_capture")
    D.current = D.stop and "Stopped safely. Completed files are saved; this capture is partial."
        or D.sourceAbortReason and "Source recovery ended with gaps. Completed files are saved."
        or menu and ingame and "Both captures saved. ZIP the entire displayed folder and upload it."
        or mode == "menu" and "Menu saved. Spawn as a Tiger, then click IN-GAME CAPTURE."
        or "In-game capture saved. MENU CAPTURE is also available when you open the animal menu."
    D.notice = "Capture ended. Syntax rejection remains a reported reconstruction problem, not a repaired file."
    D.checkpoint()
    D.capture = nil
end
function D.launch(mode)
    if D.running then return end
    if D.blocked then D.notice = "A native worker could not be stopped or files failed verification. Keep completed exports and reload the panel for a fresh session."; D.safeRender(true); return end
    local context = D.context()
    if mode == "ingame" and not context.active then
        D.notice = "Spawn as a Tiger first, close the animal menu, then click IN-GAME CAPTURE. No capture started."
        D.safeRender(true); return
    end
    if mode == "menu" and context.active then
        D.notice = "Open FERAL's animal menu first, then click MENU CAPTURE. No capture started."
        D.safeRender(true); return
    end
    D.running,D.launched,D.stop,D.paused = true,true,false,false
    D.sourceAbortReason,D.failureCode,D.reportVisible = nil,nil,false
    D.startClicks = D.startClicks + 1
    D.phase,D.startupStage,D.startupStep = "starting",mode .. "_capture","Starting " .. mode .. " capture..."
    D.safeRender(true)
    local ok,err = pcall(D.runCapture,mode)
    if not ok then
        D.runtimeErrorKind,D.runtimeErrorLine = D.errorKind(err),tostring(err):match(":(%d+):")
        D.failureCode,D.phase = D.lastWriteFailure and "file_write_or_verification_failed" or "capture_failed","failed_partial"
        if D.capture then D.capture.status = "failed_partial" end
        D.current,D.notice,D.reportVisible = "Capture failed; completed checkpoints remain saved.","Click COPY STARTUP REPORT if needed.",true
        if not D.lastWriteFailure and D.initialized then pcall(D.checkpoint) end
        if D.root ~= "" then pcall(function()
            D.metadataWrite("FAILURE.json",D.encode({phase = D.phase,failure_code = D.failureCode,
                error_kind = D.runtimeErrorKind,diagnostic_line = D.runtimeErrorLine,last_file_failure = D.lastWriteFailure,
                last_intact_checkpoint = D.checkpointNumber,notice = "Use the last intact checkpoint; later files may be unreferenced."}))
        end) end
    end
    D.blocked = D.lastWriteFailure ~= nil or D.sourceAbortReason == "worker_could_not_be_cancelled" or not D.initialized
    for _,conn in ipairs(D.watchers) do pcall(function() conn:Disconnect() end) end
    D.watchers,D.scripts,D.buckets,D.visited = {},{},{{},{},{},{}},{}
    D.capture,D.running = nil,false
    D.safeRender(true)
end
function D.cleanupUI()
    for _,connection in ipairs(D.connections) do pcall(function() connection:Disconnect() end) end
    D.connections = {}
    if D.gui then pcall(function() D.gui:Destroy() end) end
end
function D.createUI()
    local colors = {bg = Color3.fromRGB(17,24,35),text = Color3.fromRGB(235,243,249),muted = Color3.fromRGB(161,184,202),
        blue = Color3.fromRGB(44,103,157),green = Color3.fromRGB(26,124,101),red = Color3.fromRGB(159,60,70)}
    local function make(class,props,parent)
        local obj = Instance.new(class)
        for key,value in pairs(props) do
            local ok = pcall(function() obj[key] = value end)
            if not ok and key ~= "TextEditable" then error("UI property unavailable: " .. key,0) end
        end
        obj.Parent = parent
        return obj
    end
    local gui = make("ScreenGui",{Name = "FeralRecoverySupplementV31",ResetOnSpawn = false,IgnoreGuiInset = true,DisplayOrder = 475},playerGui)
    D.gui = gui
    local panel = make("Frame",{Name = "Panel",Size = UDim2.fromOffset(640,505),Position = UDim2.fromScale(0.5,0.08),AnchorPoint = Vector2.new(0.5,0),
        BackgroundColor3 = colors.bg,BorderSizePixel = 0,Active = true},gui)
    make("UICorner",{CornerRadius = UDim.new(0,10)},panel)
    local camera = workspace.CurrentCamera
    if camera then make("UIScale",{Scale = math.max(0.45,math.min(1,camera.ViewportSize.X/670,camera.ViewportSize.Y/550))},panel) end
    local function label(name,text,y,h,size)
        return make("TextLabel",{Name = name,Text = text,Position = UDim2.fromOffset(14,y),Size = UDim2.fromOffset(612,h),
            BackgroundTransparency = 1,TextColor3 = colors.text,Font = Enum.Font.Gotham,TextSize = size or 12,TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Left,TextYAlignment = Enum.TextYAlignment.Center},panel)
    end
    local function button(name,text,x,y,w,color,parent)
        local b = make("TextButton",{Name = name,Text = text,Position = UDim2.fromOffset(x,y),Size = UDim2.fromOffset(w,34),BackgroundColor3 = color,
            BorderSizePixel = 0,Font = Enum.Font.GothamBold,TextSize = 11,TextColor3 = colors.text},parent or panel)
        make("UICorner",{CornerRadius = UDim.new(0,6)},b);return b
    end
    label("Heading","FERAL / RECOVERY SUPPLEMENT v3.1",8,28,15)
    D.ui = {panel = panel,status = label("Status","READY - CHOOSE A CAPTURE",42,24,13),
        current = label("Current",D.current,69,39),folder = label("Folder","Folder created after first capture",112,28,11),
        counts = label("Counts","64 syntax failures + 7 review paths | same folder for both captures",143,28,11)}
    D.ui.menu = button("MenuCapture","1. MENU CAPTURE",14,178,198,colors.green)
    D.ui.ingame = button("InGameCapture","2. IN-GAME CAPTURE",221,178,198,colors.blue)
    D.ui.stop = button("Stop","STOP & SAVE",428,178,198,colors.red)
    D.ui.pause = button("Pause","PAUSE",14,220,145,colors.blue)
    local save = button("Checkpoint","SAVE CHECKPOINT",168,220,145,colors.blue)
    local folder = button("CopyFolder","COPY FOLDER",322,220,145,colors.blue)
    local report = button("CopyStartup","COPY STARTUP REPORT",476,220,150,colors.green)
    local hide = button("Hide","HIDE",565,8,61,colors.blue)
    D.ui.show = button("Show","FERAL SHOW",14,12,120,colors.blue,gui)
    D.ui.show.Visible = false
    label("Help","Menu: click 1 and wait. Then spawn as a Tiger, close the animal menu and click 2. The in-game observation takes 30 seconds before source recovery and world inventory. ZIP the entire folder after both captures finish.",263,54,11)
    D.ui.preview = make("TextBox",{Name = "Summary",Text = D.summary(),Position = UDim2.fromOffset(14,326),Size = UDim2.fromOffset(612,165),
        BackgroundColor3 = Color3.fromRGB(10,16,24),TextColor3 = colors.muted,Font = Enum.Font.Code,TextSize = 11,TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,TextYAlignment = Enum.TextYAlignment.Top,ClearTextOnFocus = false,TextEditable = false,
        MultiLine = true},panel)
    local function connect(signal,fn)
        D.connections[#D.connections + 1] = signal:Connect(function(...)
            local ok,err = pcall(fn,...)
            if not ok then D.notice = "Control failed: " .. D.errorKind(err); D.safeRender(true) end
        end)
    end
    connect(D.ui.menu.Activated,function() D.launch("menu") end)
    connect(D.ui.ingame.Activated,function() D.launch("ingame") end)
    connect(D.ui.pause.Activated,function() if D.running then D.paused = not D.paused;D.safeRender(true) end end)
    connect(D.ui.stop.Activated,function() if D.running then D.stop,D.paused = true,false;D.notice = "Stopping; completed files will be kept." end end)
    connect(save.Activated,function()
        if D.running then D.saveRequested = true
        elseif D.initialized and not D.blocked then D.checkpoint();D.notice = "Checkpoint saved." end
        D.safeRender(true)
    end)
    connect(folder.Activated,function()
        if API.clipboard and D.root ~= "" then pcall(API.clipboard,D.root);D.notice = "Folder name copied." end
        D.safeRender(true)
    end)
    connect(report.Activated,function()
        D.reportVisible = true
        if API.clipboard then pcall(API.clipboard,D.startupReport()) end
        D.safeRender(true)
    end)
    connect(hide.Activated,function() panel.Visible,D.ui.show.Visible = false,true end)
    connect(D.ui.show.Activated,function() panel.Visible,D.ui.show.Visible = true,false;D.safeRender(true) end)
    connect(gui.Destroying,function() D.stop,D.paused = true,false end)
end
function D.render()
    if not D.ui then return end
    D.ui.status.Text = D.phase:upper() .. (D.running and (D.paused and " | PAUSED" or " | RUNNING") or "")
    D.ui.current.Text = D.current .. "\n" .. D.notice
    D.ui.folder.Text = D.root ~= "" and D.root or "Folder created after the first capture click"
    D.ui.counts.Text = "Capture: " .. (D.capture and D.capture.mode or "ready") .. " | sources " .. D.sourceCursor .. " / 71 | saved payloads " .. D.payloadCount
    D.ui.pause.Text = D.paused and "RESUME" or "PAUSE"
    D.ui.menu.Text = D.running and "CAPTURE RUNNING" or "1. MENU CAPTURE"
    D.ui.ingame.Text = D.running and "CAPTURE RUNNING" or "2. IN-GAME CAPTURE"
    D.ui.preview.Text = D.reportVisible and D.startupReport() or D.summary()
end
local uiOk,uiError = pcall(D.createUI)
if not uiOk then
    D.phase,D.failureCode = "ui_setup_failed","ui_setup_failed"
    D.runtimeErrorKind,D.runtimeErrorLine = D.errorKind(uiError),tostring(uiError):match(":(%d+):")
    warn(D.startupReport())
end
D.safeRender(true)
