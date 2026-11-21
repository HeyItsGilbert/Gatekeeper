Version 5

Properties {
    # Set this to $true to create a module with a monolithic PSM1
    $PSBPreference.Build.CompileModule = $false
    $PSBPreference.Help.DefaultLocale = 'en-US'
    $PSBPreference.Test.OutputFile = 'out/testResults.xml'
}

Task Default -depends Test

Task Test -FromModule PowerShellBuild -minimumVersion '0.6.1'

# NOT VIABLE as currently architected. Root-caused via bisection, not guessed:
#
# 1. Pester 6 Run.Parallel runs each file's worker in its own runspace, but
#    *in the same process* (confirmed empirically - workers share $env: and
#    the CLR's process-wide TypeAccelerators table; this is not separate
#    child processes). See Pester.BeforeContainer.ps1 for the env-var
#    implication of that.
# 2. Gatekeeper.psm1 registers [PropertySet]/[FeatureFlag]/[Rule]/[Condition]/
#    etc. as type accelerators pointing at this module's `class` definitions.
#    Every runspace that imports the module compiles its *own distinct* CLR
#    Type for each `class`, and PowerShell `class` types are not shared
#    across separately-imported module instances. The accelerator table is
#    one shared, process-wide slot per name, so whichever runspace imports
#    last wins that slot - and every *other* runspace's objects, which were
#    built from a now-orphaned, no-longer-accelerator-bound Type, start
#    failing `-is`/`Should -BeOfType`/argument-transformation checks against
#    the type name with errors like "Cannot convert type to FeatureFlag:
#    FeatureFlag" and "Expected type [Rule] ... but got Rule with type
#    [Rule]" - identical name, no relation, because they're genuinely
#    different compiled types.
#
# A per-import lock (see Gatekeeper.psm1) fixes real corruption from
# concurrent, unsynchronized Add/Remove on that shared table (a genuine
# thread-safety bug independent of Pester), but does not and cannot fix this:
# the problem isn't corruption, it's that two valid, distinct Types are
# legitimately competing for one shared name slot. Fixing it for real needs
# an architecture change (e.g. Add-Type-based C# types, which - unlike
# PowerShell `class` - compile once per AppDomain and are shared correctly
# across runspaces), or running every module-importing file (which is nearly
# all of them) with `#pester:no-parallel`, which leaves nothing meaningful
# to parallelize. Neither is in scope here; left documented so the next
# person doesn't have to re-derive this from scratch.
Task TestParallel -depends Build -description 'NOT VIABLE (architectural, not a test bug) - see comment above task' {
    Import-Module -Name Pester -MinimumVersion 6.0.0 -Force -Verbose:$false

    $config = New-PesterConfiguration
    $config.Run.Path = $PSBPreference.Test.RootDir
    $config.Run.Parallel = $true
    $config.Run.PassThru = $true
    $config.Output.Verbosity = $PSBPreference.Test.OutputVerbosity
    $config.TestResult.Enabled = $true
    $config.TestResult.OutputPath = (Join-Path $PSBPreference.General.ProjectRoot 'out/testResults.parallel.xml')
    $config.TestResult.OutputFormat = $PSBPreference.Test.OutputFormat

    $result = Invoke-Pester -Configuration $config

    # Gate on the run's aggregate result rather than FailedCount alone, matching
    # Test-PSBuildPester's own check (a failed BeforeAll/AfterAll or a container
    # that errors during discovery leaves FailedCount at 0, but Result 'Failed').
    if ($result.Result -eq 'Failed') {
        throw 'One or more Pester tests failed (parallel run).'
    }
}
