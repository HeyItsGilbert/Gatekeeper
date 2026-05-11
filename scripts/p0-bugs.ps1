#!/usr/bin/env pwsh
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
param(
    [int]$MaxIterations = 16,
    [ValidateSet('claude', 'copilot', 'codex')]
    [string]$Type = 'claude',
    [string]$Model = 'opus',
    [ValidateSet('low', 'medium', 'high', 'max', 'xhigh')]
    [string]$Effort = 'high',
    [string]$IssueLabel = 'ralph',
    [string]$InProgressLabel = 'in-progress',
    [ValidateSet('claude', 'copilot', 'codex')]
    [string]$TriageType = 'claude',
    [string]$TriageModel = 'haiku',
    [switch]$SkipTriage,
    [switch]$SkipUpdate
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
    [CmdletBinding()]
    param([object[]]$Items)

    $lines = foreach ($item in ($Items | Sort-Object Id)) {
        [PSCustomObject]@{
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

    $trackerDir = Split-Path -Parent $TrackerPath
    if ($trackerDir -and -not (Test-Path -LiteralPath $trackerDir)) {
        New-Item -ItemType Directory -Path $trackerDir -Force | Out-Null
    }

    Set-Content -Path $TrackerPath -Value $lines -WhatIf:$false
}

function Get-IssueContext {
    param([int]$Number)

    $json = gh issue view $Number --json number,title,body,url,labels,state,closedByPullRequestsReferences 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $json) {
        return $null
    }
    return ($json | ConvertFrom-Json)
}

function Find-LinkedOpenPR {
    param([int]$Number)

    $json = gh pr list --state open --search "#$Number" --json number,body,state,url,title 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $json) {
        return $null
    }
    $prs = $json | ConvertFrom-Json
    $pattern = "(?i)(close[sd]?|fix(es|ed)?|resolve[sd]?)\s+#$Number\b"
    foreach ($pr in $prs) {
        $haystack = "$($pr.title)`n$($pr.body)"
        if ($haystack -match $pattern) {
            return $pr
        }
    }
    return $null
}

function Test-IssueHasOpenPR {
    param([pscustomobject]$Issue)

    if (-not $Issue) { return $false }
    $refs = $Issue.closedByPullRequestsReferences
    if ($refs) {
        foreach ($pr in $refs) {
            if ($pr.state -eq 'OPEN') { return $true }
        }
    }
    if (Find-LinkedOpenPR -Number ([int]$Issue.number)) {
        return $true
    }
    return $false
}

function Set-IssueInProgress {
    param([int]$Number)

    gh issue edit $Number --add-label $InProgressLabel 2>&1 | Out-Null
}

function Remove-IssueInProgress {
    param([int]$Number)

    gh issue edit $Number --remove-label $InProgressLabel 2>&1 | Out-Null
}

function Invoke-TriageModel {
    param([pscustomobject]$Issue)

    $triageBin = if ($TriageType -eq 'copilot') {
        '/home/vscode/.local/bin/copilot'
    } elseif ($TriageType -eq 'codex') {
        'codex'
    } else {
        'claude'
    }
    $triageModelResolved = Resolve-ModelAlias -Alias $TriageModel -EngineType $TriageType

    $labels = @($Issue.labels | ForEach-Object { $_.name }) -join ', '
    $bodyExcerpt = if ($Issue.body) {
        $b = [string]$Issue.body
        if ($b.Length -gt 1500) { $b.Substring(0, 1500) } else { $b }
    } else {
        ''
    }

    $triagePrompt = @"
You are triaging a GitHub issue. Decide which model and effort level to use to fix it.

Reply with ONE LINE of JSON, no prose, no code fences:
{"model":"opus|sonnet|haiku","effort":"low|medium|high|max","reason":"<one short sentence>"}

Guidelines:
- haiku/low for trivial renames, typo fixes, dead-variable removal.
- sonnet/medium for ordinary bug fixes or small refactors.
- opus/high for security work, multi-file coordination, or anything touching public contracts.

Issue #$($Issue.number): $($Issue.title)
Labels: $labels

$bodyExcerpt
"@

    try {
        if ($TriageType -eq 'codex') {
            $triageArgs = @('exec', '--model', $triageModelResolved, '--dangerously-bypass-approvals-and-sandbox', $triagePrompt)
        } else {
            $triageArgs = @('-p', $triagePrompt, '--model', $triageModelResolved)
            if ($TriageType -eq 'claude') {
                $triageArgs += @('--dangerously-skip-permissions', '--no-session-persistence')
            } elseif ($TriageType -eq 'copilot') {
                $triageArgs += @('--allow-all')
            }
        }
        $raw = & $triageBin @triageArgs 2>$null
        $text = ($raw | ForEach-Object { [string]$_ }) -join "`n"
        $jsonMatch = [regex]::Match($text, '\{[^{}]*"model"[^{}]*\}')
        if ($jsonMatch.Success) {
            $parsed = $jsonMatch.Value | ConvertFrom-Json
            return [pscustomobject]@{
                Model = [string]$parsed.model
                Effort = [string]$parsed.effort
                Reason = [string]$parsed.reason
            }
        }
    } catch {
        Write-Verbose "Triage call failed for #$($Issue.number): $_"
    }

    return [pscustomobject]@{
        Model = $Model
        Effort = $Effort
        Reason = "Issue #$($Issue.number)"
    }
}

function Sync-TrackerFromGitHub {
    Write-Host "Syncing tracker from GitHub issues (label: $IssueLabel)..." -ForegroundColor Cyan

    $listJson = gh issue list --label $IssueLabel --state open --limit 200 --json number,title,labels,url 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $listJson) {
        throw "gh issue list failed (label '$IssueLabel'). Is the gh CLI authenticated?"
    }
    $issues = $listJson | ConvertFrom-Json

    $existing = @{}
    if (Test-Path -LiteralPath $TrackerPath) {
        foreach ($item in Get-TrackerItems) {
            $existing[[int]$item.Id] = $item
        }
    }

    $rows = New-Object System.Collections.Generic.List[object]
    $kept = 0
    $added = 0
    $skipped = 0

    foreach ($issue in $issues) {
        $labelNames = @($issue.labels | ForEach-Object { $_.name })
        if ($labelNames -contains $InProgressLabel) {
            Write-Host "  skip #$($issue.number) — has '$InProgressLabel' label" -ForegroundColor DarkGray
            $skipped++
            continue
        }

        $detail = Get-IssueContext -Number $issue.number
        if (Test-IssueHasOpenPR -Issue $detail) {
            Write-Host "  skip #$($issue.number) — open PR already linked" -ForegroundColor DarkGray
            $skipped++
            continue
        }

        if ($existing.ContainsKey([int]$issue.number)) {
            $prior = $existing[[int]$issue.number]
            if ($prior.Status -in @('DONE', 'BLOCKED', 'NEEDS_WORK')) {
                $rows.Add($prior) | Out-Null
                $kept++
                continue
            }
        }

        $workstream = ($labelNames | Where-Object { $_ -ne $InProgressLabel -and $_ -ne $IssueLabel } | Select-Object -First 1)
        if (-not $workstream) { $workstream = 'general' }

        $triage = Invoke-TriageModel -Issue $detail
        Write-Host ("  add  #{0} — {1}/{2} ({3})" -f $issue.number, $triage.Model, $triage.Effort, $issue.title) -ForegroundColor Green
        $added++

        $rows.Add([pscustomobject]@{
            Id = [int]$issue.number
            Workstream = $workstream
            Scope = [string]$issue.title
            Status = 'PENDING'
            Model = $triage.Model
            Effort = $triage.Effort
            Reason = "Issue #$($issue.number)"
            Evidence = [string]$issue.url
        }) | Out-Null
    }

    foreach ($id in $existing.Keys) {
        $hit = $rows | Where-Object Id -EQ $id | Select-Object -First 1
        if (-not $hit -and $existing[$id].Status -in @('DONE', 'BLOCKED', 'NEEDS_WORK')) {
            $rows.Add($existing[$id]) | Out-Null
            $kept++
        }
    }

    Save-TrackerItems -Items $rows.ToArray()
    Write-Host "Tracker synced: $added added, $kept kept, $skipped skipped." -ForegroundColor Cyan
}

function Resolve-IssueStatusFromGitHub {
    param([int]$Number)

    $issue = Get-IssueContext -Number $Number
    if (-not $issue) {
        return $null
    }
    if ($issue.state -eq 'CLOSED') {
        return [pscustomobject]@{ Status = 'DONE'; PR = $null; Evidence = "Issue #$Number closed." }
    }
    $refs = $issue.closedByPullRequestsReferences
    if ($refs) {
        $open = $refs | Where-Object state -EQ 'OPEN' | Select-Object -First 1
        $merged = $refs | Where-Object state -EQ 'MERGED' | Select-Object -First 1
        if ($merged) {
            return [pscustomobject]@{ Status = 'DONE'; PR = $merged.url; Evidence = "PR merged: $($merged.url)" }
        }
        if ($open) {
            return [pscustomobject]@{ Status = 'DONE'; PR = $open.url; Evidence = "PR open: $($open.url)" }
        }
    }
    $pr = Find-LinkedOpenPR -Number $Number
    if ($pr) {
        return [pscustomobject]@{ Status = 'DONE'; PR = $pr.url; Evidence = "PR open: $($pr.url)" }
    }
    return $null
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
    $iterEffort = Resolve-Effort -Value $effortAlias -EngineType $Type

    $issue = Get-IssueContext -Number $next.Id
    if (-not $issue) {
        Write-Warning "Could not fetch GitHub issue #$($next.Id); skipping iteration."
        return [PSCustomObject]@{
            Success = $false
            Simulated = $false
            ItemId = [int]$next.Id
            BeforeItem = $beforeItem
            AfterItem = $beforeItem
            ExitCode = 1
            Output = @()
            Preview = ''
        }
    }

    $promptTemplate = Get-Content $PromptPath -Raw
    $prompt = $promptTemplate.
        Replace('{{ISSUE_NUMBER}}', [string]$issue.number).
        Replace('{{ISSUE_TITLE}}',  [string]$issue.title).
        Replace('{{ISSUE_URL}}',    [string]$issue.url).
        Replace('{{ISSUE_BODY}}',   [string]$issue.body)

    Write-Verbose "Tracker item: Id=$($next.Id), Model='$($next.Model)', Effort='$($next.Effort)'"
    Write-Verbose "Alias resolution: model '$modelAlias' -> '$iterModel'; effort '$effortAlias' -> '$iterEffort'"

    Write-Host ''
    Write-Host "Iteration $Iteration/$MaxIterations : item #$($next.Id), $Type, $iterModel, effort=$iterEffort" -ForegroundColor Cyan

    if ($Type -eq 'copilot') {
        $cmdArgs = @(
            '-p',
            $prompt,
            '--model',
            $iterModel,
            '--allow-all',
            '--reasoning-effort',
            $iterEffort,
            '--worktree'
        )
    } elseif ($Type -eq 'codex') {
        $cmdArgs = @(
            'exec',
            '--model',
            $iterModel,
            '--config',
            "model_reasoning_effort=`"$iterEffort`"",
            '--dangerously-bypass-approvals-and-sandbox',
            '--worktree',
            $prompt
        )
    } else {
        $cmdArgs = @(
            '--dangerously-skip-permissions',
            '--no-session-persistence',
            '--model',
            $iterModel,
            '--effort',
            $iterEffort,
            '--worktree',
            '-p',
            $prompt
        )
    }

    $preview = Format-CommandPreview -Command $EngineBin -Arguments $cmdArgs
    Write-Verbose "Command preview: $preview"
    Write-Debug "Prompt length: $($prompt.Length)"

    if (-not $PSCmdlet.ShouldProcess("item #$($next.Id)", "Invoke: $preview")) {
        Write-Verbose 'Skipped due to WhatIf/ShouldProcess.'
        return [PSCustomObject]@{
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

    Set-IssueInProgress -Number $next.Id

    try {
        & $EngineBin @cmdArgs 2>&1 | Tee-Object -Variable cliOutput | Out-Null
        $exitCode = $LASTEXITCODE
    } finally {
        Remove-IssueInProgress -Number $next.Id
    }

    $ghStatus = Resolve-IssueStatusFromGitHub -Number $next.Id
    if ($ghStatus) {
        $items = @(Get-TrackerItems)
        $row = $items | Where-Object Id -EQ $next.Id | Select-Object -First 1
        if ($row) {
            $row.Status = $ghStatus.Status
            if ($ghStatus.Evidence) { $row.Evidence = $ghStatus.Evidence }
            Save-TrackerItems -Items $items
            Write-Host "GitHub state: issue #$($next.Id) -> $($ghStatus.Status). $($ghStatus.Evidence)" -ForegroundColor Green
        }
    }

    $afterItem = Get-TrackerItem -Id $next.Id

    return [PSCustomObject]@{
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

function Update-MainBranch {
    Write-Host "Fetching origin/main..." -ForegroundColor Cyan
    git -C $RepoRoot fetch origin main --quiet 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "git fetch failed; continuing with current state." -ForegroundColor DarkYellow
        return
    }

    $branch = (git -C $RepoRoot rev-parse --abbrev-ref HEAD 2>$null).Trim()
    if ($branch -ne 'main') {
        Write-Host "Not on main (currently '$branch'). Skipping fast-forward; worktrees branch from current HEAD." -ForegroundColor DarkYellow
        return
    }

    $ahead = (git -C $RepoRoot rev-list --count origin/main..HEAD 2>$null).Trim()
    if ($ahead -and [int]$ahead -gt 0) {
        Write-Host "main is $ahead commit(s) ahead of origin/main. Skipping fast-forward." -ForegroundColor DarkYellow
        return
    }

    git -C $RepoRoot merge --ff-only origin/main 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "main fast-forwarded to origin/main." -ForegroundColor Green
    } else {
        Write-Host "Could not fast-forward main (working tree may conflict). Continuing." -ForegroundColor DarkYellow
    }
}

if (-not $SkipUpdate) {
    Update-MainBranch
}

if (-not $SkipTriage) {
    Sync-TrackerFromGitHub
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
        Write-Host "Validation check: GitHub issue #$($result.ItemId) did not move to closed/has no linked PR. Inspect the issue and any associated worktree, or remove the '$IssueLabel' label to skip it." -ForegroundColor DarkYellow
        if ($stalled -ge 3) { exit 1 }
    } else {
        $stalled = 0
        Write-Host "Progress: $before -> $after / $total" -ForegroundColor Green
    }
}
