#!/usr/bin/env pwsh
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
param(
    [int]$MaxIterations = 16,
    [ValidateSet('claude', 'copilot', 'codex')]
    [string]$Type = 'claude',
    [string]$Model = 'opus',
    [ValidateSet('low', 'medium', 'high', 'max', 'xhigh')]
    [string]$Effort = 'high'
)

$ErrorActionPreference = 'Stop'
if (Get-Variable -Name PSNativeCommandUseErrorActionPreference -ErrorAction SilentlyContinue) {
    $PSNativeCommandUseErrorActionPreference = $false
}

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$TrackerPath = Join-Path $RepoRoot 'docs/trackers/p0-bugs-TRACKER.md'
$PromptPath = Join-Path $RepoRoot 'scripts/p0-bugs-prompt.md'

if ($Type -eq 'copilot') {
    $EngineBin = '/home/vscode/.local/bin/copilot'
} elseif ($Type -eq 'codex') {
    $EngineBin = 'codex'
} else {
    $EngineBin = 'claude'
}

function Get-PendingCount {
    $tracker = Get-Content $TrackerPath -Raw
    return ([regex]::Matches($tracker, '\| PENDING[\s|]')).Count
}

function Get-CompletedCount {
    $tracker = Get-Content $TrackerPath -Raw
    $done = ([regex]::Matches($tracker, '\| DONE[\s|]')).Count
    $needsWork = ([regex]::Matches($tracker, '\| NEEDS_WORK[\s|]')).Count
    $blocked = ([regex]::Matches($tracker, '\| BLOCKED[\s|]')).Count
    return $done + $needsWork + $blocked
}

function Resolve-ModelAlias {
    param([string]$Alias, [string]$EngineType)

    $claude = @{
        opus = 'claude-opus-4-7'
        sonnet = 'claude-sonnet-4-6'
        haiku = 'claude-haiku-4-5'
    }
    $copilot = @{
        opus = 'claude-opus-4.6'
        sonnet = 'claude-sonnet-4.6'
        haiku = 'claude-haiku-4.5'
    }
    $codex = @{
        opus = 'gpt-5.5'
        sonnet = 'gpt-5.4'
        haiku = 'gpt-5.4-mini'
        codex = 'gpt-5.5'
        'gpt-5.5' = 'gpt-5.5'
        'gpt-5.4' = 'gpt-5.4'
        'gpt-5.4-mini' = 'gpt-5.4-mini'
    }

    $map = switch ($EngineType) {
        copilot { $copilot }
        codex { $codex }
        default { $claude }
    }

    if ($map.ContainsKey($Alias)) { return $map[$Alias] }
    return $Alias
}

function Resolve-Effort {
    param([string]$Value, [string]$EngineType)

    if (($EngineType -eq 'copilot' -or $EngineType -eq 'codex') -and $Value -eq 'max') {
        return 'xhigh'
    }
    if ($EngineType -eq 'claude' -and $Value -eq 'xhigh') {
        return 'max'
    }
    return $Value
}

function Format-CommandPreview {
    param(
        [string]$Command,
        [string[]]$Arguments,
        [int]$MaxArgumentPreviewLength = 120
    )

    $quotedArgs = foreach ($arg in $Arguments) {
        if ($null -eq $arg) {
            '""'
            continue
        }

        $displayArg = [string]$arg
        if ($displayArg -match '[\r\n]' -or $displayArg.Length -gt $MaxArgumentPreviewLength) {
            $singleLine = ($displayArg -replace '[\r\n]+', '\n')
            $previewLen = [Math]::Min($singleLine.Length, $MaxArgumentPreviewLength)
            $displayArg = '{0}... [len={1}]' -f $singleLine.Substring(0, $previewLen), $arg.Length
        }

        if ($displayArg -match '[\s"'']') {
            '"{0}"' -f ($displayArg -replace '"', '\"')
        } else {
            $displayArg
        }
    }

    return "{0} {1}" -f $Command, ($quotedArgs -join ' ')
}

function Get-NextPendingItem {
    foreach ($line in Get-Content $TrackerPath) {
        if ($line -match '^\|\s*\d+\s*\|' -and $line -match '\|\s*PENDING\s*\|') {
            $cells = $line -split '\|' | ForEach-Object { $PSItem.Trim() }
            return @{
                Id = $cells[1]
                Model = $cells[5]
                Effort = $cells[6]
            }
        }
    }
    return $null
}

function Invoke-Iteration {
    param([int]$Iteration)

    $next = Get-NextPendingItem
    if (-not $next) {
        Write-Verbose 'No pending tracker item found for this iteration.'
        return $true
    }

    $modelAlias = if ($next -and $next.Model) { $next.Model } else { $Model }
    $effortAlias = if ($next -and $next.Effort) { $next.Effort } else { $Effort }
    $iterModel = Resolve-ModelAlias -Alias $modelAlias  -EngineType $Type
    $iterEffort = Resolve-Effort     -Value $effortAlias -EngineType $Type
    $prompt = Get-Content $PromptPath -Raw

    Write-Verbose "Tracker item: Id=$($next.Id), Model='$($next.Model)', Effort='$($next.Effort)'"
    Write-Verbose "Alias resolution: model '$modelAlias' -> '$iterModel'; effort '$effortAlias' -> '$iterEffort'"

    Write-Host ''
    Write-Host "Iteration $Iteration/$MaxIterations : item #$($next.Id), $Type, $iterModel, effort=$iterEffort" -ForegroundColor Cyan

    if ($Type -eq 'copilot') {
        $cmdArgs = @('-p', $prompt, '--model', $iterModel, '--allow-all', '--reasoning-effort', $iterEffort)
    } elseif ($Type -eq 'codex') {
        $cmdArgs = @('exec', '--model', $iterModel, '--config', "model_reasoning_effort=`"$iterEffort`"",
            '--dangerously-bypass-approvals-and-sandbox', $prompt)
    } else {
        $cmdArgs = @('--dangerously-skip-permissions', '--no-session-persistence',
            '--model', $iterModel, '--effort', $iterEffort, '-p', $prompt)
    }

    $preview = Format-CommandPreview -Command $EngineBin -Arguments $cmdArgs
    Write-Verbose "Command preview: $preview"
    Write-Debug "Prompt length: $($prompt.Length)"

    if (-not $PSCmdlet.ShouldProcess("item #$($next.Id)", "Invoke: $preview")) {
        Write-Verbose 'Skipped due to WhatIf/ShouldProcess.'
        return $true
    }

    & $EngineBin @cmdArgs
    return $LASTEXITCODE -eq 0
}

$total = 13
$iteration = 0
$stalled = 0

while ($iteration -lt $MaxIterations) {
    $iteration++
    $pending = Get-PendingCount
    $before = Get-CompletedCount

    Write-Verbose "Loop state: iteration=$iteration, pending=$pending, completed=$before, stalled=$stalled"

    if ($pending -eq 0) {
        Write-Host 'All items completed.' -ForegroundColor Green
        break
    }

    if (-not (Invoke-Iteration -Iteration $iteration)) {
        Write-Host 'Iteration failed.' -ForegroundColor Red
        exit 1
    }

    $after = Get-CompletedCount
    if ($after -le $before) {
        $stalled++
        Write-Host "No progress detected ($stalled/3)." -ForegroundColor Yellow
        if ($stalled -ge 3) { exit 1 }
    } else {
        $stalled = 0
        Write-Host "Progress: $before -> $after / $total" -ForegroundColor Green
    }
}
