-- Final scoped orchestration. Appended after the reusable v3.1 functions.
D.current = "Spawn as a Tiger and click CAPTURE LIVE SOURCE. Menu snapshot is optional."
D.notice = "Your previous full/menu/Tiger exports are retained. No repeat of the 64 failed reconstructions."
D.planRecovery = D.recoverTargets
D.fullManifest = D.manifest
function D.summary()
    local lines = {"FERAL Final Live Supplement v3.2 | " .. D.phase,
        "Folder: " .. (D.root ~= "" and D.root or "created on capture"),
        "Live target: game/Workspace/LocalPlayer/Animate",
        "Previous 64 decompiler failures remain documented; they are not retried.",
        "Sources: " .. D.recoveryCounts.exported .. " exported | " .. D.recoveryCounts.unexported .. " unexported",
        "Syntax: " .. D.recoveryCounts.syntax_pass .. " pass | " .. D.recoveryCounts.syntax_reject .. " reject | " .. D.recoveryCounts.unchecked .. " unchecked",
        "Files: " .. D.payloadCount .. " | verified " .. D.verifiedCount .. " | unverified " .. D.unverifiedCount,
        "Only your own hierarchy is added. No full world or platform decompilation.",
        "ZIP the entire displayed folder and upload that ZIP. Old exports need not be resent."}
    for _,capture in ipairs(D.captures) do lines[#lines + 1] = capture.key .. ": " .. capture.status end
    return table.concat(lines,"\n")
end
function D.manifest()
    local manifest = D.fullManifest()
    manifest.schema = "feral-final-supplement/3.2"
    manifest.known_syntax_failure_targets,manifest.additional_semantic_review_targets = 0,0
    manifest.unresolved_baseline_syntax_failures = 64
    manifest.verified_recovery_session = RECOVERY_PLAN.verified_recovery_session
    manifest.target_count = 1
    local inventoryCounts = {}
    for key,value in pairs(D.c) do
        if key:sub(1,6) ~= "source" and key:sub(1,8) ~= "bytecode" then inventoryCounts[key] = value end
    end
    inventoryCounts.eligible_inventory_scripts,inventoryCounts.eligible = inventoryCounts.eligible,nil
    manifest.inventory_counts,manifest.counts = inventoryCounts,nil
    manifest.source_counts,manifest.recovery_counts = D.recoveryCounts,nil
    manifest.scope = "Live local-character Animate source plus own Player/character hierarchy; previous full and recovery exports are retained"
    manifest.live_source_collected = false
    for _,capture in ipairs(D.captures) do
        if capture.mode == "ingame" and capture.live_source_exported then manifest.live_source_collected = true end
    end
    manifest.all_original_game_sources_recovered = false
    manifest.baseline_comparison_kind = "StarterCharacterScripts Animate template; live clone equality is not assumed"
    return manifest
end
function D.preflight()
    D.stage("checking_file_apis","Checking text export support...")
    if not API.write or not API.mkdir then D.failureCode = "missing_file_apis"; error("writefile/makefolder required",0) end
    local ok,guid = pcall(function() return Http:GenerateGUID(false) end)
    D.session = os.date("!%Y%m%d_%H%M%S") .. "_" .. (ok and guid:gsub("[^%w]",""):sub(1,12) or tostring(math.random(100000,999999)))
    D.root = "FERAL_Final_v3_2_" .. D.session
    if API.isfolder then local valid,exists = pcall(API.isfolder,D.root); if valid and exists then error("Folder collision",0) end end
    if not D.mkdir(D.root) then error("Cannot create export folder",0) end
    D.control("startup-check.txt","FERAL Final v3.2 text write/read probe\n")
    D.checkCompiler()
    D.control("target-plan.json",D.encode(RECOVERY_PLAN))
    local instructions = "FERAL Final Live Supplement v3.2\n\nSpawn as a Tiger, close the animal menu, click CAPTURE LIVE SOURCE.\n"
        .. "Wait for the 5-second observation, source capture and own hierarchy inventory to finish.\n"
        .. "Click COPY FOLDER. In Velocity's workspace, compress that ENTIRE folder to ZIP and upload the ZIP.\n"
        .. "MENU SNAPSHOT is optional; it does not attempt the live source while you are despawned.\n"
        .. "Keep the previous complete and recovery exports. The 64 decompiler failures are not retried or repaired.\n"
        .. "Only filtered source text is exported. Compile checks never execute game code. No gameplay writes or remote calls.\n"
        .. "A final status with source/quality gaps means the export is partial or reconstructed text still fails checks.\n"
        .. "If split folders exist, upload EVERY UPLOAD_PART_* folder including metadata part 000.\n"
    D.control("README.txt",instructions)
    D.rawWrite("READ_FIRST.txt",instructions)
    D.control("coverage.json",D.encode({schema = "feral-final-coverage/3.2",configuration = CFG,
        properties_by_base_class = D.properties,source_target = RECOVERY_PLAN.targets[1].path,
        prior_exports_retained = {RECOVERY_PLAN.baseline_session,RECOVERY_PLAN.verified_recovery_session},
        hierarchy_scope = "LocalPlayer, own Character, and ancestor context only; no traversal of other-player/world roots",
        source_scope = "Only live Animate; other script paths in the local hierarchy are inventoried with explicit source-scope records",
        baseline_comparison = "Checksum/length comparison against the starter Animate template, not proof of clone identity",
        source_checks = "Raw and filtered compiler statuses; closures never executed; unsupported interpolation explicitly omitted",
        privacy = "No other-player subtrees, chat/input text, credentials, raw source, raw error text or raw bytecode exports",
        timeout_limit = "Cooperative timeout cannot preempt a blocking native call; at most one decompiler worker",
        snapshot_is_atomic = false,source_syntax_is_not_semantic_verification = true}))
    D.initialized = true
    D.checkpoint()
end
function D.captureInventory()
    D.phase = "inventory"
    D.visited,D.scripts,D.buckets = {},{},{{},{},{},{}}
    D.inspect(game,{path = "",category = "game"})
    D.inspect(Players,{path = "game",category = "game",parentId = D.id(game),service = "Players"})
    D.inspect(workspace,{path = "game",category = "game",parentId = D.id(game),service = "Workspace"})
    local complete = D.walk(player,{path = "game/Players",category = "game",parentId = D.id(Players),service = "Players"})
    local _,character = D.context()
    if character and not D.stop then
        if not D.walk(character,{path = "game/Workspace",forcePath = "game/Workspace/LocalPlayer",category = "game",
            parentId = D.id(workspace),service = "Workspace"}) then complete = false end
    end
    for _,entry in ipairs(D.scripts) do
        if entry.eligible and entry.path ~= RECOVERY_PLAN.targets[1].path then
            D.emit("source-scope/" .. entry.category,{id = entry.id,path = entry.path,
                status = "outside_final_live_source_pass",reason = "Previous sources retained; this supplement targets live Animate only"})
        end
    end
    D.capture.inventory_traversal_exhausted = complete and not D.stop
    D.scripts,D.buckets,D.visited = {},{{},{},{},{}},{}
end
function D.runCapture(mode)
    D.capture = nil
    if not D.initialized then D.preflight() end
    local capture = {key = string.format("C%03d_%s",#D.captures + 1,mode),mode = mode,status = "running",
        context_at_start = D.context(),started_utc = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        target_count = mode == "ingame" and 1 or 0,live_source_required = mode == "ingame",expected_species = "Tiger"}
    D.capture = capture
    D.captures[#D.captures + 1] = capture
    D.sourceCursor = 0
    D.setupPrivacy()
    D.observe()
    if mode == "ingame" then D.planRecovery()
    else
        D.emit("source-scope/game",{path = RECOVERY_PLAN.targets[1].path,status = "deferred_until_ingame",attempted = false})
        capture.source_pass_finished,capture.targets_terminal,capture.targets_processed = true,0,0
    end
    D.checkpoint()
    if not D.stop and not D.sourceAbortReason then D.captureInventory() end
    local result = capture.target_results and capture.target_results[1]
    capture.live_source_exported = result ~= nil and result.status == "exported"
    capture.live_source_syntax = result and result.filtered_syntax and result.filtered_syntax.status or "not_checked"
    capture.context_at_end = D.context()
    capture.finished_utc = os.date("!%Y-%m-%dT%H:%M:%SZ")
    if D.stop then capture.status = "stopped_partial"
    elseif D.sourceAbortReason or mode == "ingame" and not capture.live_source_exported then capture.status = "finished_with_source_gaps"
    elseif mode == "ingame" and capture.live_source_syntax ~= "pass" then capture.status = "finished_with_source_quality_gaps"
    elseif D.unverifiedCount > 0 then capture.status = "finished_with_unverified_files"
    elseif not capture.inventory_traversal_exhausted or D.c.readErrors > 0 or D.c.propertyFailures > 0
        or D.c.attributeFailures > 0 or D.c.childFailures > 0 then capture.status = "finished_with_inventory_gaps"
    else capture.status = mode == "ingame" and "live_supplement_saved" or "menu_snapshot_saved" end
    D.phase = capture.status
    D.current = capture.live_source_exported and "Live source exported. ZIP the entire displayed folder and upload it."
        or mode == "menu" and "Menu snapshot saved. Spawn as a Tiger and click CAPTURE LIVE SOURCE."
        or "The live source was not fully collected. Completed files and explicit gap records are saved."
    D.notice = "The previous 64 decompiler limitations remain unresolved and documented."
    D.emit("capture-summary",{status = capture.status,live_source_exported = capture.live_source_exported,
        live_source_syntax = capture.live_source_syntax,inventory_traversal_exhausted = capture.inventory_traversal_exhausted})
    D.checkpoint()
    D.capture = nil
end
local uiOk,uiError = pcall(D.createUI)
if not uiOk then
    D.phase,D.failureCode = "ui_setup_failed","ui_setup_failed"
    D.runtimeErrorKind,D.runtimeErrorLine = D.errorKind(uiError),tostring(uiError):match(":(%d+):")
    warn(D.startupReport())
end
D.safeRender(true)
