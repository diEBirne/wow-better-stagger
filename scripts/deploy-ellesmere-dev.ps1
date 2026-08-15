# Deploy the local Ellesmere integration and its separate screenshot helper.
#
# Usage:
#   .\scripts\deploy-ellesmere-dev.ps1
#   .\scripts\deploy-ellesmere-dev.ps1 -WoWAddOnsPath "D:\Other\Path\Interface\AddOns"
#   .\scripts\deploy-ellesmere-dev.ps1 -WhatIf

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$WoWAddOnsPath = "D:\Battle.net\World of Warcraft\_retail_\Interface\AddOns"
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$integrationDeploy = Join-Path $PSScriptRoot "deploy-ellesmere.ps1"
$source = Join-Path $repoRoot "integrations\ellesmere-dev\BrewmasterExtendedStaggerBarDev"
$destination = Join-Path $WoWAddOnsPath "BrewmasterExtendedStaggerBarDev"

if (-not (Test-Path -LiteralPath $integrationDeploy)) {
    throw "Missing Ellesmere deploy script: $integrationDeploy"
}
if (-not (Test-Path -LiteralPath $source)) {
    throw "Missing screenshot helper source: $source"
}

$forwardArgs = @{ WoWAddOnsPath = $WoWAddOnsPath }
if ($WhatIfPreference) {
    $forwardArgs["WhatIf"] = $true
}

& $integrationDeploy @forwardArgs
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

if ($WhatIfPreference) {
    Write-Host "==> WhatIf: would mirror screenshot helper to $destination" -ForegroundColor Cyan
    Get-ChildItem -LiteralPath $source -File | ForEach-Object {
        Write-Host "  copy $($_.Name)"
    }
    exit 0
}

if (-not (Test-Path -LiteralPath $destination)) {
    New-Item -ItemType Directory -Path $destination -Force | Out-Null
}

$robocopyArgs = @(
    $source,
    $destination,
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

Write-Host "Ellesmere screenshot helper deploy complete." -ForegroundColor Green
Write-Host "  Enable Brewmaster Extended Stagger Bar Dev, then /reload." -ForegroundColor Yellow
exit 0
