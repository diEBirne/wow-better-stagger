# Deploy BetterStagger from this repository to a local WoW AddOns folder.
#
# Usage:
#   .\scripts\deploy.ps1
#   .\scripts\deploy.ps1 -WoWAddOnsPath "D:\Other\Path\Interface\AddOns"
#   .\scripts\deploy.ps1 -WhatIf

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$WoWAddOnsPath = "D:\Battle.net\World of Warcraft\_retail_\Interface\AddOns"
)

$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot
$Source = Join-Path $RepoRoot "BetterStagger"
$Destination = Join-Path $WoWAddOnsPath "BetterStagger"

function Write-Step {
    param([string]$Message)
    Write-Host "==> $Message" -ForegroundColor Cyan
}

if (-not (Test-Path -LiteralPath $Source)) {
    throw "Source folder not found: $Source"
}

if (-not (Test-Path -LiteralPath $WoWAddOnsPath)) {
    throw "WoW AddOns folder not found: $WoWAddOnsPath`nAdjust the path with -WoWAddOnsPath if your install location differs."
}

Write-Step "Repository: $RepoRoot"
Write-Step "Source:      $Source"
Write-Step "Destination: $Destination"

if ($WhatIfPreference) {
    Write-Step "WhatIf: would mirror BetterStagger to WoW AddOns folder"
    Get-ChildItem -LiteralPath $Source -Recurse -File | ForEach-Object {
        $relativePath = $_.FullName.Substring($Source.Length).TrimStart("\")
        Write-Host "  copy $relativePath"
    }
    exit 0
}

if (-not (Test-Path -LiteralPath $Destination)) {
    Write-Step "Creating destination folder"
    New-Item -ItemType Directory -Path $Destination -Force | Out-Null
}

Write-Step "Syncing files (mirror)"

# /MIR keeps the WoW folder identical to the repo addon folder.
# Exit codes 0-7 are success for robocopy; >= 8 indicates an error.
$robocopyArgs = @(
    $Source,
    $Destination,
    "/MIR",
    "/NFL",
    "/NDL",
    "/NJH",
    "/NJS",
    "/NP",
    "/R:2",
    "/W:1"
)

& robocopy @robocopyArgs | Out-Null
$robocopyExitCode = $LASTEXITCODE

if ($robocopyExitCode -ge 8) {
    throw "Robocopy failed with exit code $robocopyExitCode"
}

$fileCount = (Get-ChildItem -LiteralPath $Destination -Recurse -File).Count
Write-Host ""
Write-Host "Deploy complete." -ForegroundColor Green
Write-Host "  Files in destination: $fileCount"
Write-Host "  Next step in WoW: /reload"

exit 0
