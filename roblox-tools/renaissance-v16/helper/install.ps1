# Scoped, on-demand installation of a reversible user-level input helper.
$ErrorActionPreference='Stop'
$ProgressPreference='SilentlyContinue'
$taskName='FERAL Left Hold Bridge (on demand)'
$reportName='FERAL_RENAISSANCE_TESTS_LATEST.json'
# Only the owner of the unique active Roblox desktop (or unique Explorer desktop).
$clients=@(Get-CimInstance Win32_Process -Filter "Name='RobloxPlayerBeta.exe'" | Where-Object {$_.SessionId -gt 0})
if ($clients.Count -gt 1) {throw 'Multiple game clients; refusing to select a desktop'}
if ($clients.Count -eq 1) {$client=$clients[0]}
else {
    $desktops=@(Get-CimInstance Win32_Process -Filter "Name='explorer.exe'" | Where-Object {$_.SessionId -gt 0} | Group-Object SessionId)
    if ($desktops.Count -ne 1) {throw 'No unique interactive desktop'}
    $client=$desktops[0].Group[0]
}
$owner=Invoke-CimMethod -InputObject $client -MethodName GetOwner
$sid=Invoke-CimMethod -InputObject $client -MethodName GetOwnerSid
if ($owner.ReturnValue -ne 0 -or $sid.ReturnValue -ne 0) {throw 'Could not establish interactive owner'}
$user=$owner.Domain+'\'+$owner.User
$desktopProfiles=@(Get-CimInstance Win32_UserProfile | Where-Object {$_.SID -eq $sid.Sid})
if ($desktopProfiles.Count -ne 1 -or !$desktopProfiles[0].LocalPath) {throw 'No unique desktop profile'}
$homePath=$desktopProfiles[0].LocalPath
$local=Join-Path $homePath 'AppData\Local'
$roaming=Join-Path $homePath 'AppData\Roaming'
$roots=[System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
function Add-Root([string]$p) {if ($p -and (Test-Path -LiteralPath $p -PathType Container)) {[void]$roots.Add([IO.Path]::GetFullPath($p))}}
Add-Root $env:FERAL_DIAGNOSTICS_DIR
foreach ($p in @($local,$roaming)) {Add-Root (Join-Path $p 'Potassium');Add-Root (Join-Path $p 'Potassium\workspace')}
Add-Root (Join-Path $homePath 'Documents\Potassium')
Add-Root (Join-Path $homePath 'Potassium')
foreach ($p in @(Get-Process -Name 'Potassium*' -ErrorAction SilentlyContinue | Where-Object {$_.SessionId -eq $client.SessionId})) {
    try {if ($p.Path) {Add-Root (Split-Path -Parent $p.Path)}} catch {}
}
$reports=@()
foreach ($root in $roots) {
    $reports+=@(Get-ChildItem -LiteralPath $root -Filter $reportName -File -Recurse -Depth 3 -ErrorAction SilentlyContinue |
        Where-Object {$_.Length -ge 20 -and $_.Length -le 1048576 -and $_.LastWriteTimeUtc -gt [DateTime]::UtcNow.AddDays(-2)})
}
$workspace=$null
foreach ($f in @($reports | Sort-Object LastWriteTimeUtc -Descending | Select-Object -Unique)) {
    try {
        $r=[IO.File]::ReadAllText($f.FullName)|ConvertFrom-Json
        if ($r.schema -ceq 'FERAL_RENAISSANCE_TESTS_V1' -and $r.version -cmatch '^16\.(2|3|4)\.[0-9]+(-rc[0-9]+)?$') {$workspace=$f.DirectoryName;break}
    } catch {}
}
if (!$workspace) {throw 'Recent matching hub report not found in the existing workspace'}
Write-Output 'FERAL_LEFT_HOLD_WORKSPACE=VERIFIED'
$compiler=Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (!(Test-Path -LiteralPath $compiler -PathType Leaf)) {throw 'Windows .NET Framework C# compiler unavailable; no downloads attempted'}
$temp=Join-Path $env:RUNNER_TEMP 'FERALLeftHoldBridge.exe'
& $compiler /nologo /target:winexe /platform:anycpu /optimize+ /r:System.Windows.Forms.dll /r:System.Drawing.dll /r:System.Web.Extensions.dll "/out:$temp" (Join-Path $PSScriptRoot 'LeftHoldBridge.cs')
if ($LASTEXITCODE -ne 0 -or !(Test-Path -LiteralPath $temp -PathType Leaf)) {throw 'Input helper compile failed'}
$check=Start-Process -FilePath $temp -ArgumentList '--self-test' -Wait -PassThru
if ($check.ExitCode -ne 0) {throw 'Input helper ABI self-test failed'}
Write-Output 'FERAL_LEFT_HOLD_COMPILE=PASS'
$dir=Join-Path $local 'FERALInputBridge'
New-Item -ItemType Directory -Path $dir -Force|Out-Null
$exe=Join-Path $dir 'FERALLeftHoldBridge.exe'
$backup=Join-Path $dir 'rollback'
New-Item -ItemType Directory -Path $backup -Force|Out-Null
foreach($name in @('FERALLeftHoldBridge.exe','LeftHoldBridge.cs')) {
    $old=Join-Path $dir $name
    $saved=Join-Path $backup $name
    if((Test-Path -LiteralPath $old -PathType Leaf) -and !(Test-Path -LiteralPath $saved)) {
        Copy-Item -LiteralPath $old -Destination $saved
    }
}
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'rollback.ps1') -Destination (Join-Path $dir 'rollback.ps1') -Force
$backupExe=Join-Path $backup 'FERALLeftHoldBridge.exe'
$backupHash=if(Test-Path -LiteralPath $backupExe){(Get-FileHash -LiteralPath $backupExe -Algorithm SHA256).Hash.ToLowerInvariant()}else{$null}
[IO.File]::WriteAllText((Join-Path $backup 'manifest.json'),(@{exe_sha256=$backupHash}|ConvertTo-Json),[Text.UTF8Encoding]::new($false))
try {
$previous=Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($previous) {
    if ($previous.State -eq 'Running') {Stop-ScheduledTask -TaskName $taskName;Start-Sleep -Milliseconds 300}
}
# The one-shot scheduled task can report Ready after launching its UI process.
# Stop only the verified FERAL helper executable in this same user session.
$expectedExe=[IO.Path]::GetFullPath($exe)
$running=@(Get-CimInstance Win32_Process -Filter "Name='FERALLeftHoldBridge.exe'" |
    Where-Object {$_.SessionId -eq $client.SessionId})
foreach ($p in $running) {
    if (!$p.ExecutablePath -or [IO.Path]::GetFullPath($p.ExecutablePath) -ine $expectedExe) {
        throw 'Unexpected helper process path; refusing to stop an unrelated binary'
    }
    Stop-Process -Id ([int]$p.ProcessId) -Force -ErrorAction Stop
}
for ($i=0;$i -lt 16;$i++) {
    $live=@(Get-CimInstance Win32_Process -Filter "Name='FERALLeftHoldBridge.exe'" |
        Where-Object {$_.SessionId -eq $client.SessionId -and
            $_.ExecutablePath -and [IO.Path]::GetFullPath($_.ExecutablePath) -ieq $expectedExe})
    if ($live.Count -eq 0) {break}
    Start-Sleep -Milliseconds 250
}
if ($live.Count -ne 0) {throw 'Previous helper did not exit; original executable preserved'}
Copy-Item -LiteralPath $temp -Destination $exe -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'LeftHoldBridge.cs') -Destination (Join-Path $dir 'LeftHoldBridge.cs') -Force
$status=Join-Path $dir 'status.txt'
if (Test-Path -LiteralPath $status) {Remove-Item -LiteralPath $status -Force}
$action=New-ScheduledTaskAction -Execute $exe -Argument ('"'+$workspace+'"') -WorkingDirectory $dir
$principal=New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Limited
$settings=New-ScheduledTaskSettingsSet -ExecutionTimeLimit ([TimeSpan]::Zero) -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -MultipleInstances IgnoreNew
# No boot/logon/scheduled trigger. Run once in the existing interactive session.
Register-ScheduledTask -TaskName $taskName -Action $action -Principal $principal -Settings $settings -Force|Out-Null
Start-ScheduledTask -TaskName $taskName
$ready=$false
for ($i=0;$i -lt 15;$i++) {
    Start-Sleep -Milliseconds 500
    $p=@(Get-Process -Name 'FERALLeftHoldBridge' -ErrorAction SilentlyContinue | Where-Object {$_.SessionId -eq $client.SessionId})
    if ($p.Count -eq 1 -and (Test-Path -LiteralPath $status) -and [IO.File]::ReadAllText($status) -ceq 'RUNNING') {$ready=$true;break}
}
if (!$ready) {Stop-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue;throw 'Interactive helper startup not verified'}
Write-Output 'FERAL_LEFT_HOLD_INSTALL=RUNNING_INTERACTIVE'
Write-Output 'FERAL_LEFT_HOLD_AUTOSTART=NONE'
Write-Output 'FERAL_LEFT_HOLD_EMERGENCY_TOGGLE=CTRL_ALT_F12'
$receipt=[ordered]@{schema='FERAL_LEFT_HOLD_INSTALL_V2';version='16.4.0-rc1';utc=[DateTime]::UtcNow.ToString('o');
    status='RUNNING_INTERACTIVE';source_sha256=(Get-FileHash -LiteralPath (Join-Path $dir 'LeftHoldBridge.cs') -Algorithm SHA256).Hash.ToLowerInvariant();
    exe_sha256=(Get-FileHash -LiteralPath $exe -Algorithm SHA256).Hash.ToLowerInvariant();
    rollback_available=($null -ne $backupHash);autostart=$false;gameplay_actions=0}
[IO.File]::WriteAllText((Join-Path $dir 'receipt.json'),($receipt|ConvertTo-Json),[Text.UTF8Encoding]::new($false))
Write-Output ('FERAL_LEFT_HOLD_INSTALL_RECEIPT='+($receipt|ConvertTo-Json -Compress))
} catch {
    $failure=$_
    try {
        & (Join-Path $dir 'rollback.ps1')
        Write-Output 'FERAL_LEFT_HOLD_FAILED_UPGRADE_ROLLBACK=RESTORED'
    } catch {Write-Output 'FERAL_LEFT_HOLD_FAILED_UPGRADE_ROLLBACK=UNCONFIRMED'}
    throw $failure
}

