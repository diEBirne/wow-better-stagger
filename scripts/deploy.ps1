# Deploy Better Stagger and/or local Ellesmere Enhanced Stagger integration.
#
# Usage:
#   .\scripts\deploy.ps1
#   .\scripts\deploy.ps1 -Target Standalone
#   .\scripts\deploy.ps1 -Target Ellesmere
#   .\scripts\deploy.ps1 -Target Both
#   .\scripts\deploy.ps1 -Target Ellesmere -WoWAddOnsPath "D:\Other\Path\Interface\AddOns"
#   .\scripts\deploy.ps1 -WhatIf

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [ValidateSet("Standalone", "Ellesmere", "Both")]
    [string]$Target = "Standalone",

    [string]$WoWAddOnsPath = "D:\Battle.net\World of Warcraft\_retail_\Interface\AddOns"
)

$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot
$StandaloneSource = Join-Path $RepoRoot "BetterStagger"
$StandaloneDestination = Join-Path $WoWAddOnsPath "BetterStagger"
$EllesmereIntegration = Join-Path $RepoRoot "integrations\ellesmere"
$ResourceBarsDestination = Join-Path $WoWAddOnsPath "EllesmereUIResourceBars"

$HookBegin = "-- BEGIN EnhancedStagger hook"
$HookEnd = "-- END EnhancedStagger hook"
$HookBlock = @"
            $HookBegin
            if powerType == "BREWMASTER_STAGGER" and ns.EnhancedStagger then
                ns.EnhancedStagger.OnSecondaryUpdate(secondaryBar, sp, cur, maxC)
            end
            $HookEnd
"@

function Write-Step {
    param([string]$Message)
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Invoke-RobocopyMirror {
    param(
        [string]$Source,
        [string]$Destination
    )

    if (-not (Test-Path -LiteralPath $Destination)) {
        New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    }

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
}

function Deploy-Standalone {
    if (-not (Test-Path -LiteralPath $StandaloneSource)) {
        throw "Source folder not found: $StandaloneSource"
    }

    Write-Step "Standalone source:      $StandaloneSource"
    Write-Step "Standalone destination: $StandaloneDestination"

    if ($WhatIfPreference) {
        Write-Step "WhatIf: would mirror BetterStagger to WoW AddOns folder"
        Get-ChildItem -LiteralPath $StandaloneSource -Recurse -File | ForEach-Object {
            $relativePath = $_.FullName.Substring($StandaloneSource.Length).TrimStart("\")
            Write-Host "  copy $relativePath"
        }
        return
    }

    Invoke-RobocopyMirror -Source $StandaloneSource -Destination $StandaloneDestination
    $fileCount = (Get-ChildItem -LiteralPath $StandaloneDestination -Recurse -File).Count
    Write-Host "Standalone deploy complete ($fileCount files)." -ForegroundColor Green
}

function Ensure-TocEntries {
    param([string]$TocPath)

    $lines = @(Get-Content -LiteralPath $TocPath)
    $filtered = foreach ($line in $lines) {
        if ($line -match '^EnhancedStagger(?:_Options)?\.lua\s*$') {
            continue
        }
        $line
    }

    $out = New-Object System.Collections.Generic.List[string]
    $inserted = $false
    foreach ($line in $filtered) {
        $out.Add($line)
        if (-not $inserted -and $line -match '^EUI_ResourceBars_Options\.lua\s*$') {
            $out.Add("EnhancedStagger.lua")
            $out.Add("EnhancedStagger_Options.lua")
            $inserted = $true
        }
    }

    if (-not $inserted) {
        throw "Could not find EUI_ResourceBars_Options.lua entry in TOC to insert Enhanced Stagger files."
    }

    $newContent = ($out -join "`r`n") + "`r`n"
    $oldContent = (Get-Content -LiteralPath $TocPath -Raw)
    if ($newContent -ne $oldContent) {
        Set-Content -LiteralPath $TocPath -Value $newContent -NoNewline
        Write-Step "Updated TOC load order for Enhanced Stagger"
    }
}

function Ensure-RuntimeHook {
    param([string]$MainLuaPath)

    $content = Get-Content -LiteralPath $MainLuaPath -Raw

    # Always strip previous marker block so re-deploy can relocate the hook.
    if ($content -match [regex]::Escape($HookBegin)) {
        $pattern = "(?s)[ \t]*" + [regex]::Escape($HookBegin) + ".*?" + [regex]::Escape($HookEnd) + "\r?\n?"
        $content = [regex]::Replace($content, $pattern, "")
        Write-Step "Removed previous Enhanced Stagger runtime hook"
    }

    # Insert AFTER the tainted/ease SetValue if/else that follows the stagger ceiling logic.
    $ceilingIdx = $content.IndexOf("Brewmaster stagger ceiling")
    if ($ceilingIdx -lt 0) {
        throw "Could not locate Brewmaster stagger ceiling block for Enhanced Stagger hook."
    }

    $afterCeiling = $content.Substring($ceilingIdx)
    $easeIdx = $afterCeiling.IndexOf("secondaryBar:SetValue(cur, ns.EASE)")
    if ($easeIdx -lt 0) {
        throw "Could not locate secondaryBar:SetValue(cur, ns.EASE) after stagger ceiling."
    }

    $absoluteEase = $ceilingIdx + $easeIdx
    $endIdx = $content.IndexOf("`n", $absoluteEase)
    if ($endIdx -lt 0) {
        throw "Could not find end of SetValue(ease) line."
    }

    # Next non-empty line should be the closing `end` of the tainted if/else.
    $searchFrom = $endIdx + 1
    $closingEnd = -1
    while ($searchFrom -lt $content.Length) {
        $nextLineEnd = $content.IndexOf("`n", $searchFrom)
        if ($nextLineEnd -lt 0) {
            $nextLineEnd = $content.Length
        }
        $line = $content.Substring($searchFrom, $nextLineEnd - $searchFrom).Trim()
        if ($line -eq "end") {
            $closingEnd = $nextLineEnd
            break
        }
        if ($line -ne "" -and $line -notmatch "^--") {
            break
        }
        $searchFrom = $nextLineEnd + 1
    }

    if ($closingEnd -lt 0) {
        throw "Could not locate closing end after SetValue(ease) for Enhanced Stagger hook."
    }

    $insertion = $content.Substring(0, $closingEnd + 1) + $HookBlock + "`r`n" + $content.Substring($closingEnd + 1)
    Set-Content -LiteralPath $MainLuaPath -Value $insertion -NoNewline
    Write-Step "Inserted Enhanced Stagger runtime hook after SetValue branch"
}

function Deploy-Ellesmere {
    if (-not (Test-Path -LiteralPath $EllesmereIntegration)) {
        throw "Integration folder not found: $EllesmereIntegration"
    }
    if (-not (Test-Path -LiteralPath $ResourceBarsDestination)) {
        throw "EllesmereUIResourceBars not found: $ResourceBarsDestination`nInstall EllesmereUI first."
    }

    $files = @(
        "EnhancedStagger.lua",
        "EnhancedStagger_Options.lua"
    )

    Write-Step "Ellesmere integration: $EllesmereIntegration"
    Write-Step "Resource Bars dest:   $ResourceBarsDestination"

    if ($WhatIfPreference) {
        foreach ($fileName in $files) {
            Write-Host "  copy $fileName"
        }
        Write-Host "  patch EllesmereUIResourceBars.toc"
        Write-Host "  patch EllesmereUIResourceBars.lua (Enhanced Stagger hook)"
        return
    }

    foreach ($fileName in $files) {
        $src = Join-Path $EllesmereIntegration $fileName
        $dst = Join-Path $ResourceBarsDestination $fileName
        if (-not (Test-Path -LiteralPath $src)) {
            throw "Missing integration file: $src"
        }
        Copy-Item -LiteralPath $src -Destination $dst -Force
        Write-Step "Copied $fileName"
    }

    $tocPath = Join-Path $ResourceBarsDestination "EllesmereUIResourceBars.toc"
    $mainLua = Join-Path $ResourceBarsDestination "EllesmereUIResourceBars.lua"
    Ensure-TocEntries -TocPath $tocPath
    Ensure-RuntimeHook -MainLuaPath $mainLua

    Write-Host "Ellesmere Enhanced Stagger deploy complete." -ForegroundColor Green
    Write-Host "  Tip: disable the standalone BetterStagger addon while testing Enhanced Stagger." -ForegroundColor Yellow
}

if (-not (Test-Path -LiteralPath $WoWAddOnsPath)) {
    throw "WoW AddOns folder not found: $WoWAddOnsPath`nAdjust the path with -WoWAddOnsPath if your install location differs."
}

Write-Step "Repository: $RepoRoot"
Write-Step "Target:     $Target"

if ($Target -eq "Standalone" -or $Target -eq "Both") {
    Deploy-Standalone
}

if ($Target -eq "Ellesmere" -or $Target -eq "Both") {
    Deploy-Ellesmere
}

Write-Host ""
Write-Host "Next step in WoW: /reload" -ForegroundColor Green
exit 0
