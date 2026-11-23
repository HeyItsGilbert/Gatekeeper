Version 5

Properties {
    # Set this to $true to create a module with a monolithic PSM1
    $PSBPreference.Build.CompileModule = $false
    $PSBPreference.Help.DefaultLocale = 'en-US'
    $PSBPreference.Test.OutputFile = 'out/testResults.xml'
}

Task Default -depends Test

Task Test -FromModule PowerShellBuild -minimumVersion '0.6.1'

# RESOLVED via a full migration (previously NOT VIABLE - see git history on
# this file for the original root-cause analysis). Every Gatekeeper domain
# type (Effect, Operator, Condition, PropertyValidation, Property,
# PropertySet, Rule, FeatureFlag, GatekeeperPath, and the three
# ArgumentTransformationAttribute classes) was converted from PowerShell
# `class`/`enum` definitions to C#-compiled types (Classes/CompiledTypes.ps1,
# registered once per process via Add-Type, not re-compiled per runspace) -
# see that file for the full design and the TOCTOU/PSObject-unwrapping/
# exception-wrapping/stream-redirection pitfalls that came with it.
#
# Verified via repeated fresh-session full-suite parallel runs: 399 passed,
# 0 failed, 5 skipped - identical to the sequential Test task, 3 consecutive
# clean runs after also fixing a BuildHelpers module-discovery race (see
# Pester.BeforeContainer.ps1 - `Get-Module -ListAvailable` transiently found
# nothing under 17-way concurrency even though BuildHelpers was genuinely
# installed; serialized with the same Monitor-lock pattern).
Task TestParallel -depends Build -description 'Execute Pester tests with each file in its own runspace (experimental, Pester 6 Run.Parallel)' {
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
