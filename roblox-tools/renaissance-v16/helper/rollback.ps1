# Restore the saved helper only; the hub's settings and releases are untouched.
$ErrorActionPreference='Stop'
$taskName='FERAL Left Hold Bridge (on demand)'
$dir=$PSScriptRoot
$exe=Join-Path $dir 'FERALLeftHoldBridge.exe'
$backup=Join-Path $dir 'rollback'
$saved=Join-Path $backup 'FERALLeftHoldBridge.exe'
$manifest=Get-Content -LiteralPath (Join-Path $backup 'manifest.json') -Raw|ConvertFrom-Json
if(!$manifest.exe_sha256 -or (Get-FileHash -LiteralPath $saved -Algorithm SHA256).Hash.ToLowerInvariant() -cne $manifest.exe_sha256){throw 'Saved helper hash unavailable or mismatched'}
$task=Get-ScheduledTask -TaskName $taskName -ErrorAction Stop
if([IO.Path]::GetFullPath($task.Actions[0].Execute) -ine [IO.Path]::GetFullPath($exe)){throw 'Scheduled task executable differs; original preserved'}
$running=@(Get-CimInstance Win32_Process -Filter "Name='FERALLeftHoldBridge.exe'")
foreach($p in $running) {
    if($p.ExecutablePath -and [IO.Path]::GetFullPath($p.ExecutablePath) -ieq [IO.Path]::GetFullPath($exe)) {
        Stop-Process -Id ([int]$p.ProcessId) -Force -ErrorAction Stop
    }
}
Stop-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
Start-Sleep -Milliseconds 500
Copy-Item -LiteralPath $saved -Destination $exe -Force
$savedSource=Join-Path $backup 'LeftHoldBridge.cs'
if(Test-Path -LiteralPath $savedSource){Copy-Item -LiteralPath $savedSource -Destination (Join-Path $dir 'LeftHoldBridge.cs') -Force}
Start-ScheduledTask -TaskName $taskName
Write-Output 'FERAL_LEFT_HOLD_ROLLBACK=PREVIOUS_HELPER_RESTORED'
