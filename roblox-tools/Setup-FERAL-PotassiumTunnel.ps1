<#
.SYNOPSIS
Connects the installed Potassium MCP bridge to an existing OpenAI Secure MCP Tunnel.

.DESCRIPTION
Run this on the Windows PC with Potassium installed. It downloads the current full
OpenAI tunnel-client release, checks the ZIP against that release's SHA256SUMS.txt,
creates a stdio profile, runs doctor, and starts the tunnel in this window.
The Platform runtime API key is entered locally and is not written to this repo or
the tunnel profile. Closing the PowerShell window stops the tunnel.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^tunnel_(?:[a-z0-9]{4}_)?[a-z0-9]{32}$')]
    [string]$TunnelId
)

$ErrorActionPreference = 'Stop'

if ($env:OS -ne 'Windows_NT') {
    throw 'Run this script in PowerShell on the Windows PC where Potassium is installed.'
}

$bridge = Join-Path $env:LOCALAPPDATA 'Programs\Potassium MCP\PotassiumMcp.Launcher.exe'
if (-not (Test-Path -LiteralPath $bridge -PathType Leaf)) {
    throw "Potassium MCP launcher was not found at $bridge. Run its Windows Setup first."
}

$architecture = switch ($env:PROCESSOR_ARCHITECTURE.ToUpperInvariant()) {
    'AMD64' { 'amd64' }
    'ARM64' { 'arm64' }
    default { throw "Unsupported Windows architecture: $env:PROCESSOR_ARCHITECTURE" }
}

Write-Host 'Finding the current OpenAI tunnel-client release...'
$release = Invoke-RestMethod -Uri 'https://api.github.com/repos/openai/tunnel-client/releases/latest' -Headers @{ 'User-Agent' = 'FERAL-Potassium-Tunnel-Setup' }
$releaseTag = [string]$release.tag_name
if ($releaseTag -notmatch '^v[0-9]+\.[0-9]+\.[0-9]+$') {
    throw 'The OpenAI release response did not contain a stable version tag.'
}

$archiveName = "tunnel-client-$releaseTag-windows-$architecture.zip"
$archiveAsset = @($release.assets | Where-Object { $_.name -eq $archiveName })
$checksumsAsset = @($release.assets | Where-Object { $_.name -eq 'SHA256SUMS.txt' })
if ($archiveAsset.Count -ne 1 -or $checksumsAsset.Count -ne 1) {
    throw "The $releaseTag release is missing the full Windows client or SHA256SUMS.txt."
}

foreach ($asset in @($archiveAsset[0], $checksumsAsset[0])) {
    $prefix = "https://github.com/openai/tunnel-client/releases/download/$releaseTag/"
    if (-not ([string]$asset.browser_download_url).StartsWith($prefix, [StringComparison]::Ordinal)) {
        throw "Unexpected download URL for $($asset.name)."
    }
}

$installRoot = Join-Path $env:LOCALAPPDATA "FERAL\PotassiumTunnel\$releaseTag"
$clientRoot = Join-Path $installRoot 'client'
New-Item -ItemType Directory -Path $installRoot -Force | Out-Null
$archivePath = Join-Path $installRoot $archiveName
$checksumsPath = Join-Path $installRoot 'SHA256SUMS.txt'

if (-not (Test-Path -LiteralPath $archivePath -PathType Leaf)) {
    Write-Host "Downloading $archiveName..."
    Invoke-WebRequest -Uri $archiveAsset[0].browser_download_url -OutFile $archivePath -UseBasicParsing
}
Invoke-WebRequest -Uri $checksumsAsset[0].browser_download_url -OutFile $checksumsPath -UseBasicParsing

$checksumRows = @(Get-Content -LiteralPath $checksumsPath | Where-Object {
    $fields = $_.Trim() -split '\s+', 2
    $fields.Count -eq 2 -and $fields[1].TrimStart('*') -eq $archiveName
})
if ($checksumRows.Count -ne 1) {
    throw "Could not find exactly one checksum for $archiveName."
}
$expectedHash = ($checksumRows[0].Trim() -split '\s+', 2)[0]
if ($expectedHash -notmatch '^[a-fA-F0-9]{64}$') {
    throw 'The published checksum is not a SHA-256 digest.'
}
$actualHash = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash
if ($actualHash -ine $expectedHash) {
    throw 'The tunnel-client ZIP does not match the published checksum. It will not be run.'
}

if (-not (Test-Path -LiteralPath $clientRoot -PathType Container)) {
    Write-Host 'Extracting the verified client...'
    Expand-Archive -LiteralPath $archivePath -DestinationPath $clientRoot
}
$clientFiles = @(Get-ChildItem -LiteralPath $clientRoot -Recurse -File -Filter 'tunnel-client.exe')
if ($clientFiles.Count -ne 1) {
    throw 'Expected one tunnel-client.exe in the verified archive.'
}
$clientExe = $clientFiles[0].FullName

$keyWasEnteredHere = [string]::IsNullOrWhiteSpace($env:CONTROL_PLANE_API_KEY)
if ($keyWasEnteredHere) {
    Write-Host 'Create a Restricted Platform runtime key with Tunnels Read + Use if you have not already.'
    Write-Host 'https://platform.openai.com/settings/organization/api-keys'
    $secureKey = Read-Host 'Paste the Platform runtime API key here (input is hidden)' -AsSecureString
    $env:CONTROL_PLANE_API_KEY = [System.Net.NetworkCredential]::new('', $secureKey).Password
    Remove-Variable secureKey
}
if ([string]::IsNullOrWhiteSpace($env:CONTROL_PLANE_API_KEY)) {
    throw 'The Platform runtime API key is required.'
}

# The command parser uses shell quoting, even on Windows. The inner single quotes
# keep the spaces and backslashes in the installed executable path together.
$quotedBridge = "'" + $bridge.Replace("'", "'`"'`"'") + "'"
$profileName = 'feral-potassium'

try {
    & $clientExe init --force --sample sample_mcp_stdio_local --profile $profileName --tunnel-id $TunnelId --mcp-command $quotedBridge
    if ($LASTEXITCODE -ne 0) { throw 'tunnel-client init failed.' }

    & $clientExe doctor --profile $profileName --explain
    if ($LASTEXITCODE -ne 0) { throw 'tunnel-client doctor failed. Review the error above.' }

    Write-Host ''
    Write-Host 'The tunnel is ready to start. Leave this PowerShell window open.'
    Write-Host 'In ChatGPT, use Tunnel, select No authentication, tick the acknowledgement, and Create as a plugin.'
    Write-Host 'Starting the tunnel now...'
    & $clientExe run --profile $profileName
    if ($LASTEXITCODE -ne 0) { throw 'tunnel-client run stopped with an error.' }
}
finally {
    if ($keyWasEnteredHere) {
        Remove-Item Env:CONTROL_PLANE_API_KEY -ErrorAction SilentlyContinue
    }
}
