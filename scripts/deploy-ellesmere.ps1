# Deploy local Ellesmere Brewmaster Extended Stagger Bar into Resource Bars.
#
# Usage:
#   .\scripts\deploy-ellesmere.ps1
#   .\scripts\deploy-ellesmere.ps1 -WoWAddOnsPath "D:\Other\Path\Interface\AddOns"
#   .\scripts\deploy-ellesmere.ps1 -WhatIf
#
# Re-run after any EllesmereUI / Resource Bars update (updater wipes our TOC,
# runtime hook, and copied Lua). Then /reload in WoW.

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$WoWAddOnsPath = "D:\Battle.net\World of Warcraft\_retail_\Interface\AddOns"
)

$ErrorActionPreference = "Stop"

$deployScript = Join-Path $PSScriptRoot "deploy.ps1"
if (-not (Test-Path -LiteralPath $deployScript)) {
    throw "Missing shared deploy script: $deployScript"
}

$forwardArgs = @{
    Target        = "Ellesmere"
    WoWAddOnsPath = $WoWAddOnsPath
}
if ($WhatIfPreference) {
    $forwardArgs["WhatIf"] = $true
}

& $deployScript @forwardArgs
exit $LASTEXITCODE
