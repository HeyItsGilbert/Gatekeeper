# Gatekeeper P0 Bug Fixes — Iteration Prompt

Open `trackers/p0-bugs-tracker.jsonl` and pick the **first PENDING object only**.
Work only that one object. Do not batch multiple objects in one iteration.

Each line in the tracker file is one JSON object with these fields:

- `id`
- `workstream`
- `scope`
- `status`
- `model`
- `effort`
- `reason`
- `evidence`

## Before Editing

Find and read these files before touching anything:

- `Gatekeeper/Gatekeeper.psd1` — manifest (ScriptsToProcess, dot-source order)
- `Gatekeeper/Gatekeeper.psm1` — module loader (dot-source paths)
- The specific source file(s) implied by the tracker object's `scope`
- The corresponding test file(s) in `tests/` if they exist
- `Gatekeeper/Configuration.psd1` for config-related rows

Follow the existing code style exactly. Do not refactor code outside the scope of the object.

## Work the Object

Make the smallest complete change that fixes the bug described in the `scope` field.
The GitHub issue number in the `reason` field contains the detailed description.

### Key fixes reference

**ID 1 — break-in-switch (Issue #9)**
`break` inside `switch` does not exit the enclosing `foreach`. Use a labeled break:

```powershell
:ruleLoop foreach ($rule in $FeatureFlag.Rules) {
    if (Test-Condition @testConditionSplat) {
        switch ($rule.Effect) {
            'Allow' { Invoke-Logging -Effect 'Allow' -Rule $rule; $finalResult = $true;  break ruleLoop }
            'Deny'  { Invoke-Logging -Effect 'Deny'  -Rule $rule; $finalResult = $false; break ruleLoop }
            'Audit' { Invoke-Logging -Effect 'Audit' -Rule $rule }
            'Warn'  { Invoke-Logging -Effect 'Warn'  -Rule $rule }
        }
    }
}
```

**ID 2 — DefaultEffect (Issue #10)**
Track whether a terminal rule fired. In `end{}`, use DefaultEffect only when no terminal rule matched:

```powershell
begin { $finalResult = $false; $terminalHit = $false }
# process: set $terminalHit = $true on Allow/Deny
end {
    if (-not $terminalHit) {
        $finalResult = $FeatureFlag.DefaultEffect -eq [Effect]::Allow
    }
    return $finalResult
}
```

**ID 3 — AddProperty (Issue #11)**
`$this.Properties.Add($Property)` → `$this.Properties.Add($Property.Name, $Property)`

**ID 4 — ConditionGroup.FromJson (Issue #12)**
Add to the `ConditionGroup` class:

```powershell
static [ConditionGroup] FromJson([string]$json) {
    $data = ConvertFrom-JsonToHashtable -InputObject $json
    return [ConditionGroup]::new($data)
}
```

**ID 5 — Two-group guard (Issue #13)**
Replace the `ContainsKey('AllOf') -and ContainsKey('AnyOf') -and ContainsKey('Not')` check with:

```powershell
$groupKeys = @('AllOf', 'AnyOf', 'Not') | Where-Object { $data.ContainsKey($_) }
if ($groupKeys.Count -gt 1) {
    throw "ConditionGroup may only define one of: AllOf, AnyOf, Not. Got: $($groupKeys -join ', ')"
}
```

**ID 6 — FromFile Name (Issue #14)**
`$ps.Name = $ps.FilePath.BaseName` → `$ps.Name = [System.IO.Path]::GetFileNameWithoutExtension($ps.FilePath)`

**ID 7 — Warn/Warning mismatch (Issue #15)**
In `Configuration.psd1`, rename the `Warning` logging key to `Warn`.
In `guides/logging.md`, fix the example that uses `$config.Logging.Warning` → `$config.Logging.Warn`.
Verify `Invoke-Logging.ps1` uses `$config.Logging.$Effect` (it already does; the config key change is the fix).

**ID 8 — Dead variables (Issue #33)**
Remove `$config = Import-GatekeeperConfig` from `Test-FeatureFlag.ps1` begin{}.
Remove `$validation = $meta.Validation` from `Test-Condition.ps1`.

**ID 9 — New-FeatureFlag Mandatory (Issue #35)**
Remove `Mandatory` from the `$Rules` parameter attribute. Keep `= @()` default.

**ID 10 — Rename Convert-ToTypeValue (Issue #34)**
Rename the file `Convert-ToTypeValue.ps1` → `Convert-ToTypedValue.ps1`.
Rename the function declaration from `Convert-ToTypeValue` to `Convert-ToTypedValue`.
Search `Gatekeeper.psm1` for any dot-source of `Convert-ToTypeValue` and update it.
Verify `Test-Condition.ps1` already uses the correct name `Convert-ToTypedValue` (it should).

**ID 11 — IsValid() misleading (Issue #31)**
Rename `IsValid()` to `IsLeaf()` so the name matches what it actually tests (flat leaf conditions).
Search for any callers of `IsValid()` in the module and update them.
Alternatively, extend `IsValid()` to return `$true` for well-formed group conditions — see Issue #31 for trade-offs. Pick the simpler option.

**ID 12 — CmdletBinding (Issue #32)**
Add `[CmdletBinding()]` before the `param` block in:

- `Public/Test-Condition.ps1`
- `Private/Test-TypedValue.ps1`
- `Private/Invoke-Logging.ps1`
- `Private/Convert-ToTypeValue.ps1` (or `Convert-ToTypedValue.ps1` after ID 10)

**ID 13 — Boolean coercion (Issue #28)**
Replace `$Value -as [bool]` with an explicit switch:

```powershell
"boolean" {
    if ($Value -is [bool])   { return $Value }
    if ($Value -is [int])    { return [bool]$Value }
    switch ($Value.ToString().ToLower()) {
        'true'  { return $true  }
        'false' { return $false }
        '1'     { return $true  }
        '0'     { return $false }
        default { throw "Cannot convert '$Value' to boolean" }
    }
}
```

## After Editing

Open the tracker and pick the first PENDING object. Work only that object.

Before editing:

- Find the manifest (*.psd1).
- Find the module entry point (*.psm1).
- Find public commands, private helpers, tests, and docs.
- Follow the existing layout.

After editing:

- Run the tests: `.\build.ps1 -Task Test -OutputFormat Quiet`
  - Errors will be show in ErrorMessage object.
  - Success is indicated by zero exit code and the result object show Success as True.
- Verify public commands use approved verbs.
- Verify exported commands are intentional.
- Verify parameters are typed and validated.
- Verify mutating commands use SupportsShouldProcess when appropriate.
- Verify help/docs/examples are updated when public behavior changes.
- Re-read every modified file.
- Update the JSONL object's `evidence` field.
- Commit the item.

## Creating PRs with `gh` CLI

Create a PR for the worktree branch after committing the fix.

```powershell
gh pr create `
    --title "fix(<area>): <short description> (closes #<issue>)" `
    --body "Summary of bug fix, tests, and impact"
```

If a PR already exists for the branch, return the existing PR URL instead of creating a duplicate.

### Return PR in report

The structured report **must** include the PR URL when available:

```text
PR: https://github.com/<owner>/<repo>/pull/<number>
```

## Commit Format

```
fix(<area>): <short description> (closes #<issue>)
```

Example: `fix(Classes): correct PropertySet.AddProperty hashtable key (closes #11)`

## Structured Report

End every iteration with:

```
ITEM: [tracker object id and scope]
STATUS: DONE | BLOCKED [reason]
FILES_MODIFIED: [files]
FILES_READ_BACK: yes | no [reason]
MODULE_IMPORT: PASS | FAIL | N/A [command]
TESTS: PASS | FAIL | N/A [counts]
ANALYZER: PASS | FAIL | N/A
HELP: UPDATED | UNCHANGED | N/A
COMMIT: [hash or reason]
PR: [PR]
```
