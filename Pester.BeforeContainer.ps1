# Dot-sourced by Pester 6 before every test file is discovered and run, in both
# sequential and parallel runs (one file per runspace/process under Run.Parallel).
#
# Each test file's own BeforeDiscovery assumes $env:BH* (BHProjectPath,
# BHProjectName, BHPSModuleManifest, ...) is already set by BuildHelpers before it
# reads them. Under Run.Parallel, workers do not inherit the parent session's
# environment, so without this bootstrap every file's BeforeDiscovery would read
# empty values and fail (or, for files with a defensive "rebuild if missing"
# fallback, trigger a full concurrent `build.ps1 -Task Build` per worker - a race
# on the shared Output/ directory). Running this once per worker, before that
# worker's own file-level setup, makes every file self-contained regardless of
# how Pester schedules it.
# Only set up when missing - never -Force here. Test-PSBuildPester has already
# Push-Location'd into the tests directory by the time Pester runs, and
# Set-BuildEnvironment defaults to detecting the project root from $PWD; a
# blind -Force re-run from that location would overwrite the correct values
# (already set once, from the repo root, by the outer build's Init task) with
# wrong ones detected from tests/. Anchor explicitly to this file's own
# directory (the repo root) instead of trusting $PWD.
if (-not $env:BHProjectPath) {
    if (-not (Get-Module -Name BuildHelpers -ListAvailable)) {
        throw 'BuildHelpers module is required to bootstrap the build environment for tests.'
    }
    Import-Module -Name BuildHelpers -Force -Verbose:$false
    BuildHelpers\Set-BuildEnvironment -Path $PSScriptRoot -ErrorAction Stop
}
