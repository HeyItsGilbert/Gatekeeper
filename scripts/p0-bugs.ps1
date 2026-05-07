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
$TrackerPath = Join-Path $RepoRoot 'trackers/p0-bugs-tracker.jsonl'
$PromptPath = Join-Path $RepoRoot 'scripts/p0-bugs-prompt.md'

if ($Type -eq 'copilot') {
    $EngineBin = '/home/vscode/.local/bin/copilot'
} elseif ($Type -eq 'codex') {
    $EngineBin = 'codex'
} else {
    $EngineBin = 'claude'
}

function Get-PendingCount {
    return @(Get-TrackerItems | Where-Object Status -EQ 'PENDING').Count
}

function Get-CompletedCount {
    $items = @(Get-TrackerItems)
    $done = @($items | Where-Object Status -EQ 'DONE').Count
    $needsWork = @($items | Where-Object Status -EQ 'NEEDS_WORK').Count
    $blocked = @($items | Where-Object Status -EQ 'BLOCKED').Count
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

function Get-TrackerItems {
    $items = foreach ($line in Get-Content $TrackerPath) {
        if ([string]::IsNullOrWhiteSpace($line)) {
            continue
        }

        $item = $line | ConvertFrom-Json
        [pscustomobject]@{
            Id = [int]$item.id
            Workstream = [string]$item.workstream
            Scope = [string]$item.scope
            Status = [string]$item.status
            Model = [string]$item.model
            Effort = [string]$item.effort
            Reason = [string]$item.reason
            Evidence = [string]$item.evidence
        }
    }

    return @($items | Sort-Object Id)
}

function Get-NextPendingItem {
    return Get-TrackerItems | Where-Object Status -EQ 'PENDING' | Select-Object -First 1
}

function Get-TrackerItem {
    param([int]$Id)

    return Get-TrackerItems | Where-Object Id -EQ $Id | Select-Object -First 1
}

function Save-TrackerItems {
    param([object[]]$Items)

    $lines = foreach ($item in ($Items | Sort-Object Id)) {
        [pscustomobject]@{
            id = [int]$item.Id
            workstream = [string]$item.Workstream
            scope = [string]$item.Scope
            status = [string]$item.Status
            model = [string]$item.Model
            effort = [string]$item.Effort
            reason = [string]$item.Reason
            evidence = [string]$item.Evidence
        } | ConvertTo-Json -Compress
    }

    Set-Content -Path $TrackerPath -Value $lines
}

function Get-IterationReport {
    param(
        [string[]]$Output,
        [int]$FallbackItemId
    )

    if (-not $Output -or $Output.Count -eq 0) {
        return $null
    }

    $text = ($Output | ForEach-Object { [string]$_ }) -join "`n"
    $statusMatch = [regex]::Match($text, '(?mi)^STATUS:\s*(DONE|BLOCKED|NEEDS_WORK)\b(.*)$')
    if (-not $statusMatch.Success) {
        return $null
    }

    $itemId = $FallbackItemId
    $itemMatch = [regex]::Match($text, '(?mi)^ITEM:\s*\[?(?:tracker\s+(?:object|row)\s+)?(?:ID\s*)?(\d+)\b')
    if ($itemMatch.Success) {
        $itemId = [int]$itemMatch.Groups[1].Value
    }

    $commit = $null
    $commitMatch = [regex]::Match($text, '(?mi)^COMMIT:\s*(.+)$')
    if ($commitMatch.Success) {
        $commit = $commitMatch.Groups[1].Value.Trim()
    }

    $pr = $null
    $prMatch = [regex]::Match($text, '(?mi)^PR:\s*(.+)$')
    if ($prMatch.Success) {
        $pr = $prMatch.Groups[1].Value.Trim()
    }

    if (-not $pr) {
        $prUrlMatch = [regex]::Match($text, 'https://github\.com/[^\s/]+/[^\s/]+/pull/\d+')
        if ($prUrlMatch.Success) {
            $pr = $prUrlMatch.Value
        }
    }

    $status = $statusMatch.Groups[1].Value.ToUpperInvariant()
    $statusRemainder = $statusMatch.Groups[2].Value.Trim()
    $evidence = if ($commit) {
        $commit
    } elseif ($statusRemainder) {
        $statusRemainder
    } else {
        'Updated from CLI structured report.'
    }

    return [pscustomobject]@{
        ItemId = $itemId
        Status = $status
        Evidence = $evidence
        PR = $pr
    }
}

function Update-TrackerFromReport {
    param([pscustomobject]$Report)

    if (-not $Report) {
        return $false
    }

    $items = @(Get-TrackerItems)
    $target = $items | Where-Object Id -EQ $Report.ItemId | Select-Object -First 1
    if (-not $target) {
        Write-Warning "Could not find tracker item #$($Report.ItemId) from CLI report."
        return $false
    }

    $changed = $false
    if ($target.Status -ne $Report.Status) {
        $target.Status = $Report.Status
        $changed = $true
    }

    if ($Report.Evidence -and $target.Evidence -ne $Report.Evidence) {
        $target.Evidence = $Report.Evidence
        $changed = $true
    }

    if ($changed) {
        Save-TrackerItems -Items $items
    }

    return $changed
}

function Invoke-Iteration {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param([int]$Iteration)

    $next = Get-NextPendingItem
    if (-not $next) {
        Write-Verbose 'No pending tracker item found for this iteration.'
        return $true
    }

    $beforeItem = Get-TrackerItem -Id $next.Id

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
        $cmdArgs = @('-p', $prompt, '--model', $iterModel, '--allow-all', '--reasoning-effort', $iterEffort, '--worktree')
    } elseif ($Type -eq 'codex') {
        $cmdArgs = @('exec', '--model', $iterModel, '--config', "model_reasoning_effort=`"$iterEffort`"",
            '--dangerously-bypass-approvals-and-sandbox', '--worktree', $prompt)
    } else {
        $cmdArgs = @('--dangerously-skip-permissions', '--no-session-persistence',
            '--model', $iterModel, '--effort', $iterEffort, '--worktree', '-p', $prompt)
    }

    $preview = Format-CommandPreview -Command $EngineBin -Arguments $cmdArgs
    Write-Verbose "Command preview: $preview"
    Write-Debug "Prompt length: $($prompt.Length)"

    if (-not $PSCmdlet.ShouldProcess("item #$($next.Id)", "Invoke: $preview")) {
        Write-Verbose 'Skipped due to WhatIf/ShouldProcess.'
        return [pscustomobject]@{
            Success = $true
            Simulated = $true
            ItemId = [int]$next.Id
            BeforeItem = $beforeItem
            AfterItem = $beforeItem
            ExitCode = 0
            Output = @()
            Preview = $preview
        }
    }

    & $EngineBin @cmdArgs 2>&1 | Tee-Object -Variable cliOutput | Out-Null
    $exitCode = $LASTEXITCODE
    $afterItem = Get-TrackerItem -Id $next.Id

    return [pscustomobject]@{
        Success = $exitCode -eq 0
        Simulated = $false
        ItemId = [int]$next.Id
        BeforeItem = $beforeItem
        AfterItem = $afterItem
        ExitCode = $exitCode
        Output = @($cliOutput)
        Preview = $preview
    }
}

$total = @(Get-TrackerItems).Count
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

    $result = Invoke-Iteration -Iteration $iteration
    if (-not $result.Success) {
        Write-Host "Iteration failed (exit code $($result.ExitCode))." -ForegroundColor Red
        if ($result.Output.Count -gt 0) {
            Write-Host 'CLI output:' -ForegroundColor DarkYellow
            $result.Output | Select-Object -Last 20 | ForEach-Object {
                Write-Host "  $_"
            }
        }
        exit 1
    }

    if ($result.Simulated) {
        Write-Host "Validation only: tracker item #$($result.ItemId) was not executed because WhatIf/ShouldProcess skipped the CLI call." -ForegroundColor DarkYellow
        continue
    }

    $report = Get-IterationReport -Output $result.Output -FallbackItemId $result.ItemId
    if ($report) {
        if (Update-TrackerFromReport -Report $report) {
            Write-Host "Tracker updated from CLI report: item #$($report.ItemId) => $($report.Status)." -ForegroundColor Green
        }

        if ($report.PR) {
            Write-Host "PR: $($report.PR)" -ForegroundColor Cyan
        }
    }

    $after = Get-CompletedCount
    $result.AfterItem = Get-TrackerItem -Id $result.ItemId
    if ($after -le $before) {
        $stalled++
        $beforeStatus = if ($result.BeforeItem) { $result.BeforeItem.Status } else { 'UNKNOWN' }
        $afterStatus = if ($result.AfterItem) { $result.AfterItem.Status } else { 'MISSING' }
        Write-Host "No progress detected ($stalled/3). Tracker item #$($result.ItemId) stayed $beforeStatus -> $afterStatus." -ForegroundColor Yellow
        if ($result.Output.Count -gt 0) {
            Write-Host 'CLI output:' -ForegroundColor DarkYellow
            $result.Output | Select-Object -Last 20 | ForEach-Object {
                Write-Host "  $_"
            }
        }
        Write-Host 'Validation check: the current checkout JSONL tracker did not change. If the CLI used an isolated worktree, inspect that worktree or disable --worktree for this loop.' -ForegroundColor DarkYellow
        if ($stalled -ge 3) { exit 1 }
    } else {
        $stalled = 0
        Write-Host "Progress: $before -> $after / $total" -ForegroundColor Green
    }
}
