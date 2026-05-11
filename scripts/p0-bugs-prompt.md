# Gatekeeper P0 Bug Fixes — Iteration Prompt

## Work this GitHub issue

- Number: #{{ISSUE_NUMBER}}
- Title: {{ISSUE_TITLE}}
- URL: {{ISSUE_URL}}

{{ISSUE_BODY}}

Work only this one issue. Do not batch multiple issues in one iteration.

## Before Editing

Find and read these files before touching anything:

- `Gatekeeper/Gatekeeper.psd1` — manifest (ScriptsToProcess, dot-source order)
- `Gatekeeper/Gatekeeper.psm1` — module loader (dot-source paths)
- The specific source file(s) implied by the issue
- The corresponding test file(s) in `tests/` if they exist
- `Gatekeeper/Configuration.psd1` for config-related issues

Follow the existing code style exactly. Do not refactor code outside the scope of the issue.

## Work the Issue

Make the smallest complete change that fixes the bug or addresses the work described in the issue body above.

## After Editing

- Run the tests: `.\build.ps1 -Task Test -OutputFormat Quiet`
  - Errors will be shown in the ErrorMessage object.
  - Success is indicated by zero exit code and the result object showing Success as True.
- Verify public commands use approved verbs.
- Verify exported commands are intentional.
- Verify parameters are typed and validated.
- Verify mutating commands use SupportsShouldProcess when appropriate.
- Verify help/docs/examples are updated when public behavior changes.
- Re-read every modified file.
- Commit the change.

## Creating PRs with `gh` CLI

Create a PR for the worktree branch after committing the fix.

```powershell
gh pr create `
    --title "fix(<area>): <short description>" `
    --body "Fixes #{{ISSUE_NUMBER}}.`n`nSummary of bug fix, tests, and impact."
```

The PR body **must** start with `Fixes #{{ISSUE_NUMBER}}` (or `Closes #...` / `Resolves #...`) so GitHub auto-links and closes the issue on merge. Do not put the closing keyword in the title.

If a PR already exists for the branch, return the existing PR URL instead of creating a duplicate.

### Return PR in report

The structured report **must** include the PR URL when available:

```text
PR: https://github.com/<owner>/<repo>/pull/<number>
```

## Commit Format

```
fix(<area>): <short description>
```

Keep the closing reference (`Fixes #{{ISSUE_NUMBER}}`) in the PR body, not the commit subject.

## Structured Report

End every iteration with:

```
ITEM: {{ISSUE_NUMBER}} [short scope]
STATUS: DONE | BLOCKED | NEEDS_WORK [reason]
FILES_MODIFIED: [files]
FILES_READ_BACK: yes | no [reason]
MODULE_IMPORT: PASS | FAIL | N/A [command]
TESTS: PASS | FAIL | N/A [counts]
ANALYZER: PASS | FAIL | N/A
HELP: UPDATED | UNCHANGED | N/A
COMMIT: [hash or reason]
PR: [PR]
```
