# Dot-sourced by Pester 6 before every test file is discovered and run, in both
# sequential and parallel runs. Under Run.Parallel, each file runs in its own
# runspace but *within the same process* (confirmed empirically: concurrent
# workers share $env: and the module's process-wide TypeAccelerators table -
# this is not separate child processes).
#
# Each test file's own BeforeDiscovery assumes $env:BH* (BHProjectPath,
# BHProjectName, BHPSModuleManifest, ...) is already set by BuildHelpers before
# it reads them. Running this once per worker, before that worker's own
# file-level setup, makes every file self-contained regardless of how Pester
# schedules it.
#
# Anchor explicitly to this file's own directory (the repo root) instead of
# trusting $PWD: Test-PSBuildPester has already Push-Location'd into the tests
# directory by the time Pester runs, and Set-BuildEnvironment defaults to
# detecting the project root from $PWD - re-running from that location would
# detect the wrong root.
#
# Always pass -Force. Multiple same-process workers can both observe
# $env:BHProjectPath missing and race into this block at once (confirmed
# empirically); Set-BuildEnvironment's underlying `New-Item -Path Env:\` throws
# "already exists" on the second writer unless -Force makes it an idempotent
# overwrite instead. Both writers compute the same value from the same
# explicit -Path, so the redundant write is harmless.
if (-not $env:BHProjectPath) {
    if (-not (Get-Module -Name BuildHelpers -ListAvailable)) {
        throw 'BuildHelpers module is required to bootstrap the build environment for tests.'
    }
    Import-Module -Name BuildHelpers -Force -Verbose:$false
    BuildHelpers\Set-BuildEnvironment -Path $PSScriptRoot -Force -ErrorAction Stop
}
