# FERAL v3.0 - local export verification and independent upload ZIP parts.
# Windows PowerShell 5.1 / PowerShell 7. No network requests or game interaction.
[CmdletBinding()]
param(
    [string]$ExportFolder = $PSScriptRoot,
    [ValidateRange(8, 512)][int]$PartMiB = 48
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
if (-not ('FeralAdler32' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.IO;
public static class FeralAdler32 {
    public static string FileHash(string path) {
        uint a = 1, b = 0;
        byte[] buffer = new byte[65536];
        using (FileStream stream = File.OpenRead(path)) {
            int count;
            while ((count = stream.Read(buffer, 0, buffer.Length)) > 0) {
                for (int start = 0; start < count; start += 4096) {
                    int end = Math.Min(start + 4096, count);
                    for (int i = start; i < end; i++) { a += buffer[i]; b += a; }
                    a %= 65521; b %= 65521;
                }
            }
        }
        return ((b << 16) | a).ToString("x8");
    }
}
'@
}
$root = [IO.Path]::GetFullPath($ExportFolder).TrimEnd([IO.Path]::DirectorySeparatorChar)
$rootPrefix = $root + [IO.Path]::DirectorySeparatorChar
function Resolve-ExportPath([string]$relative) {
    if ([string]::IsNullOrWhiteSpace($relative) -or $relative.Contains(':') -or $relative.Contains('\') -or $relative.StartsWith('/')) {
        throw "Unsafe export path: $relative"
    }
    $absolute = [IO.Path]::GetFullPath((Join-Path $root $relative))
    if (-not $absolute.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Export path leaves its folder: $relative"
    }
    return $absolute
}
function Read-Json([string]$path) {
    return ([IO.File]::ReadAllText($path, [Text.Encoding]::UTF8) | ConvertFrom-Json)
}
$manifestPath = Join-Path $root 'manifest.json'
$usedFallback = $false
try {
    $manifest = Read-Json $manifestPath
    if ($manifest.schema -ne 'feral-diagnostic/3.0') { throw 'Unexpected manifest schema.' }
} catch {
    # The latest immutable checkpoint survives an interrupted manifest.json write.
    $candidates = @(Get-ChildItem -LiteralPath (Join-Path $root 'checkpoints') -Filter 'manifest_*.json' -File | Sort-Object Name -Descending)
    $found = $false
    foreach ($candidate in $candidates) {
        try {
            $possible = Read-Json $candidate.FullName
            if ($possible.schema -eq 'feral-diagnostic/3.0') {
                $manifest = $possible
                $manifestPath = $candidate.FullName
                $found = $true
                break
            }
        } catch { }
    }
    if (-not $found) { throw 'No valid FERAL manifest. Let the diagnostic save a checkpoint first.' }
    $usedFallback = $true
    Write-Warning "Using checkpoint $($candidate.Name); later uncheckpointed files are not claimed as collected."
}
if ($manifest.phase -eq 'inventory' -or $manifest.phase -eq 'sources' -or $manifest.phase -eq 'starting') {
    Write-Warning 'Packing an unfinished checkpoint only. Later files are not included. Stop & save in Roblox for the latest final export.'
}
$entries = New-Object 'System.Collections.Generic.List[object]'
$seen = @{}
function Add-VerifiedFile($descriptor) {
    $relative = [string]$descriptor.path
    if ($seen.ContainsKey($relative)) { throw "Duplicate manifest path: $relative" }
    $absolute = Resolve-ExportPath $relative
    if (-not [IO.File]::Exists($absolute)) { throw "Missing file: $relative" }
    $actualBytes = (Get-Item -LiteralPath $absolute).Length
    if ($actualBytes -ne [long]$descriptor.bytes) { throw "Size mismatch: $relative" }
    if (([FeralAdler32]::FileHash($absolute)) -ne [string]$descriptor.adler32) { throw "Checksum mismatch: $relative" }
    $seen[$relative] = $true
    $entries.Add([pscustomobject]@{ path = $relative; bytes = $actualBytes; absolute = $absolute; adler32 = [string]$descriptor.adler32 })
}
Write-Host 'Checking all catalogues and data files...'
foreach ($catalog in @($manifest.catalogs)) {
    Add-VerifiedFile $catalog
    $catalogPath = Resolve-ExportPath ([string]$catalog.path)
    foreach ($line in [IO.File]::ReadLines($catalogPath, [Text.Encoding]::UTF8)) {
        if ($line.Length -gt 0) { Add-VerifiedFile ($line | ConvertFrom-Json) }
    }
}
foreach ($control in @($manifest.controls)) { Add-VerifiedFile $control }
if (($entries.Count - @($manifest.catalogs).Count - @($manifest.controls).Count) -ne [long]$manifest.files.payload_count) {
    throw 'Catalogue entry count differs from the manifest.'
}
$failurePath = Join-Path $root 'FAILURE.json'
if ([IO.File]::Exists($failurePath)) {
    Write-Warning 'The diagnostic reported a pipeline failure. This archive contains the last checkpoint and FAILURE.json; it is a partial collection.'
    Add-VerifiedFile ([pscustomobject]@{ path = 'FAILURE.json'; bytes = (Get-Item -LiteralPath $failurePath).Length; adler32 = [FeralAdler32]::FileHash($failurePath) })
}
# Use the selected immutable snapshot, even when the mutable latest manifest was damaged.
$manifestBytes = [IO.File]::ReadAllBytes($manifestPath)
$target = [long]$PartMiB * 1MB - 1MB
if ($manifestBytes.Length -ge $target) { throw 'Manifest exceeds the ZIP target. Increase -PartMiB.' }
$parts = New-Object 'System.Collections.Generic.List[object]'
$batch = New-Object 'System.Collections.Generic.List[object]'
$batchBytes = [long]$manifestBytes.Length
foreach ($entry in $entries) {
    # Data chunks are <= 512 KiB, so no normal item needs a larger archive.
    if ($entry.bytes + $manifestBytes.Length -gt $target) { throw "File exceeds the ZIP target: $($entry.path). Increase -PartMiB." }
    $entryCost = [long]$entry.bytes + 256 + [Text.Encoding]::UTF8.GetByteCount($entry.path) * 2
    if ($batch.Count -gt 0 -and $batchBytes + $entryCost -gt $target) {
        $parts.Add(@($batch.ToArray()))
        $batch = New-Object 'System.Collections.Generic.List[object]'
        $batchBytes = [long]$manifestBytes.Length
    }
    $batch.Add($entry)
    $batchBytes += $entryCost
}
if ($batch.Count -gt 0) { $parts.Add(@($batch.ToArray())) }
if ($parts.Count -eq 0) { throw 'No export files were recorded.' }
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$destination = Join-Path ([IO.Directory]::GetParent($root).FullName) ((Split-Path $root -Leaf) + '_UPLOAD_' + $stamp + '_' + [Guid]::NewGuid().ToString('N').Substring(0,6))
[void][IO.Directory]::CreateDirectory($destination)
$indexParts = New-Object 'System.Collections.Generic.List[object]'
$partNumber = 0
foreach ($part in $parts) {
    $partNumber++
    $zipName = 'FERAL_v3_part{0:D3}_of{1:D3}.zip' -f $partNumber, $parts.Count
    $zipPath = Join-Path $destination $zipName
    Write-Host "Creating $zipName..."
    $zip = [IO.Compression.ZipFile]::Open($zipPath, [IO.Compression.ZipArchiveMode]::Create)
    try {
        $manifestEntry = $zip.CreateEntry('manifest.json', [IO.Compression.CompressionLevel]::Optimal)
        $stream = $manifestEntry.Open()
        try { $stream.Write($manifestBytes, 0, $manifestBytes.Length) } finally { $stream.Dispose() }
        foreach ($entry in $part) {
            [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $entry.absolute, $entry.path, [IO.Compression.CompressionLevel]::Optimal)
        }
        $partInfo = [ordered]@{ session_id = $manifest.session_id; part = $partNumber; total_parts = $parts.Count; manifest_phase = $manifest.phase; used_checkpoint_fallback = $usedFallback; pipeline_failure_reported = [IO.File]::Exists($failurePath); files = @($part | ForEach-Object { $_.path }) }
        $partEntry = $zip.CreateEntry('UPLOAD_PART.json')
        $writer = New-Object IO.StreamWriter($partEntry.Open(), (New-Object Text.UTF8Encoding($false)))
        try { $writer.Write(($partInfo | ConvertTo-Json -Depth 8)) } finally { $writer.Dispose() }
    } finally { $zip.Dispose() }
    # Read every archived byte back and compare it with its expected checksum.
    $zip = [IO.Compression.ZipFile]::OpenRead($zipPath)
    try {
        if ($zip.Entries.Count -ne @($part).Count + 2) { throw "ZIP entry count mismatch: $zipName" }
        foreach ($entry in $part) {
            $archived = $zip.GetEntry($entry.path)
            if ($null -eq $archived -or $archived.Length -ne $entry.bytes) { throw "ZIP entry missing or wrong size: $($entry.path)" }
            $scratchPath = Join-Path $destination '.verify.tmp'
            $archiveInput = $archived.Open()
            $archiveOutput = [IO.File]::Create($scratchPath)
            try { $archiveInput.CopyTo($archiveOutput) } finally { $archiveOutput.Dispose(); $archiveInput.Dispose() }
            try {
                if (([FeralAdler32]::FileHash($scratchPath)) -ne $entry.adler32) { throw "ZIP checksum mismatch: $($entry.path)" }
            } finally { if ([IO.File]::Exists($scratchPath)) { [IO.File]::Delete($scratchPath) } }
        }
    } finally { $zip.Dispose() }
    $indexParts.Add([ordered]@{ file = $zipName; bytes = (Get-Item -LiteralPath $zipPath).Length; sha256 = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash.ToLowerInvariant(); files = @($part | ForEach-Object { $_.path }) })
}
$index = [ordered]@{ schema = 'feral-upload/3.0'; session_id = $manifest.session_id; manifest_phase = $manifest.phase; used_checkpoint_fallback = $usedFallback; pipeline_failure_reported = [IO.File]::Exists($failurePath); total_parts = $parts.Count; verification = 'All manifest data files and archived payload bytes verified'; parts = @($indexParts.ToArray()) }
[IO.File]::WriteAllText((Join-Path $destination 'UPLOAD_INDEX.json'), ($index | ConvertTo-Json -Depth 10), (New-Object Text.UTF8Encoding($false)))
Write-Host "Verified $($entries.Count) files. Export phase: $($manifest.phase)."
Write-Host "Upload ALL $($parts.Count) ZIP file(s) and UPLOAD_INDEX.json from:"
Write-Host $destination
if ($env:OS -eq 'Windows_NT') { Start-Process explorer.exe -ArgumentList ('"' + $destination + '"') }
