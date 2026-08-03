# Deploy Better Stagger and/or local Ellesmere Extended Stagger integration.
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

$HookBegin = "-- BEGIN ExtendedStagger hook"
$HookEnd = "-- END ExtendedStagger hook"
$HookBlock = @"
            $HookBegin
            if powerType == "BREWMASTER_STAGGER" and sp.extendedStagger and ns.ExtendedStagger then
                ns.ExtendedStagger.OnSecondaryUpdate(secondaryBar, sp, cur, maxC)
            end
            $HookEnd
"@
$LegacyHookBegin = "-- BEGIN EnhancedStagger hook"
$LegacyHookEnd = "-- END EnhancedStagger hook"

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
        if ($line -match '^(?:Enhanced|Extended)Stagger(?:_Options)?\.lua\s*$') {
            continue
        }
        $line
    }

    $out = New-Object System.Collections.Generic.List[string]
    $inserted = $false
    foreach ($line in $filtered) {
        $out.Add($line)
        if (-not $inserted -and $line -match '^EUI_ResourceBars_Options\.lua\s*$') {
            $out.Add("ExtendedStagger.lua")
            $out.Add("ExtendedStagger_Options.lua")
            $inserted = $true
        }
    }

    if (-not $inserted) {
        throw "Could not find EUI_ResourceBars_Options.lua entry in TOC to insert Extended Stagger files."
    }

    $newContent = ($out -join "`r`n") + "`r`n"
    $oldContent = (Get-Content -LiteralPath $TocPath -Raw)
    if ($newContent -ne $oldContent) {
        Set-Content -LiteralPath $TocPath -Value $newContent -NoNewline
        Write-Step "Updated TOC load order for Extended Stagger"
    }
}

function Ensure-RuntimeHook {
    param([string]$MainLuaPath)

    $content = Get-Content -LiteralPath $MainLuaPath -Raw

    # Always strip previous marker blocks (current + legacy name) so re-deploy can relocate.
    foreach ($pair in @(
        @{ Begin = $HookBegin; End = $HookEnd },
        @{ Begin = $LegacyHookBegin; End = $LegacyHookEnd }
    )) {
        if ($content -match [regex]::Escape($pair.Begin)) {
            $pattern = "(?s)[ \t]*" + [regex]::Escape($pair.Begin) + ".*?" + [regex]::Escape($pair.End) + "\r?\n?"
            $content = [regex]::Replace($content, $pattern, "")
            Write-Step "Removed previous Extended Stagger runtime hook ($($pair.Begin))"
        }
    }

    $ceilingIdx = $content.IndexOf("Brewmaster stagger ceiling")
    if ($ceilingIdx -lt 0) {
        throw "Could not locate Brewmaster stagger ceiling block for Extended Stagger hook."
    }

    # Prefer AFTER the secondary-bar "-- Count text" block that follows the
    # Brewmaster ceiling / SetValue path (not earlier unrelated Count text comments).
    $afterCeiling = $content.Substring($ceilingIdx)
    $countRel = $afterCeiling.IndexOf("-- Count text")
    $closingEnd = -1
    $insertReason = $null

    if ($countRel -ge 0) {
        $searchFrom = $ceilingIdx + $countRel
        $depth = 0
        $seenIf = $false
        while ($searchFrom -lt $content.Length) {
            $nextLineEnd = $content.IndexOf("`n", $searchFrom)
            if ($nextLineEnd -lt 0) {
                $nextLineEnd = $content.Length
            }
            $line = $content.Substring($searchFrom, $nextLineEnd - $searchFrom).Trim()
            # Only count block-structured if/end (ignore inline if ... end).
            if ($line -match '^if\b' -and $line -notmatch '\bend\s*$') {
                $depth++
                $seenIf = $true
            } elseif ($line -eq 'end' -and $seenIf) {
                $depth--
                if ($depth -eq 0) {
                    $closingEnd = $nextLineEnd
                    $insertReason = "after secondary Count text block"
                    break
                }
            }
            $searchFrom = $nextLineEnd + 1
        }
    }

    # Fallback: AFTER the tainted/ease SetValue if/else (older insertion point).
    if ($closingEnd -lt 0) {
        $easeIdx = $afterCeiling.IndexOf("secondaryBar:SetValue(cur, ns.EASE)")
        if ($easeIdx -lt 0) {
            throw "Could not locate secondaryBar:SetValue(cur, ns.EASE) after stagger ceiling."
        }

        $absoluteEase = $ceilingIdx + $easeIdx
        $endIdx = $content.IndexOf("`n", $absoluteEase)
        if ($endIdx -lt 0) {
            throw "Could not find end of SetValue(ease) line."
        }

        $searchFrom = $endIdx + 1
        while ($searchFrom -lt $content.Length) {
            $nextLineEnd = $content.IndexOf("`n", $searchFrom)
            if ($nextLineEnd -lt 0) {
                $nextLineEnd = $content.Length
            }
            $line = $content.Substring($searchFrom, $nextLineEnd - $searchFrom).Trim()
            if ($line -eq "end") {
                $closingEnd = $nextLineEnd
                $insertReason = "after SetValue branch (fallback)"
                break
            }
            if ($line -ne "" -and $line -notmatch "^--") {
                break
            }
            $searchFrom = $nextLineEnd + 1
        }
    }

    if ($closingEnd -lt 0) {
        throw "Could not locate insertion point for Extended Stagger hook."
    }

    $insertion = $content.Substring(0, $closingEnd + 1) + $HookBlock + "`r`n" + $content.Substring($closingEnd + 1)
    Set-Content -LiteralPath $MainLuaPath -Value $insertion -NoNewline
    Write-Step "Inserted Extended Stagger runtime hook $insertReason"
}

function Deploy-Ellesmere {
    if (-not (Test-Path -LiteralPath $EllesmereIntegration)) {
        throw "Integration folder not found: $EllesmereIntegration"
    }
    if (-not (Test-Path -LiteralPath $ResourceBarsDestination)) {
        throw "EllesmereUIResourceBars not found: $ResourceBarsDestination`nInstall EllesmereUI first."
    }

    $files = @(
        "ExtendedStagger.lua",
        "ExtendedStagger_Options.lua"
    )

    Write-Step "Ellesmere integration: $EllesmereIntegration"
    Write-Step "Resource Bars dest:   $ResourceBarsDestination"

    if ($WhatIfPreference) {
        foreach ($fileName in $files) {
            Write-Host "  copy $fileName"
        }
        Write-Host "  patch EllesmereUIResourceBars.toc"
        Write-Host "  patch EllesmereUIResourceBars.lua (Extended Stagger hook)"
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

    # Remove legacy Enhanced* filenames from older local deploys.
    foreach ($legacyName in @("EnhancedStagger.lua", "EnhancedStagger_Options.lua")) {
        $legacyPath = Join-Path $ResourceBarsDestination $legacyName
        if (Test-Path -LiteralPath $legacyPath) {
            Remove-Item -LiteralPath $legacyPath -Force
            Write-Step "Removed legacy $legacyName"
        }
    }

    $tocPath = Join-Path $ResourceBarsDestination "EllesmereUIResourceBars.toc"
    $mainLua = Join-Path $ResourceBarsDestination "EllesmereUIResourceBars.lua"
    Ensure-TocEntries -TocPath $tocPath
    Ensure-RuntimeHook -MainLuaPath $mainLua

    Write-Host "Ellesmere Extended Stagger deploy complete." -ForegroundColor Green
    Write-Host "  Tip: disable the standalone BetterStagger addon while testing Extended Stagger." -ForegroundColor Yellow
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
