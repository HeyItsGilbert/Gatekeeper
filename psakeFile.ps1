Version 5

Properties {
    # Set this to $true to create a module with a monolithic PSM1
    $PSBPreference.Build.CompileModule = $false
    $PSBPreference.Help.DefaultLocale = 'en-US'
    $PSBPreference.Test.OutputFile = 'out/testResults.xml'
}

Task Default -depends Test

Task Test -FromModule PowerShellBuild -minimumVersion '0.6.1'

# KNOWN BROKEN: reproducibly hangs (not a fluke - reproduced across fresh
# sessions, with and without a ParallelThrottleLimit). Several test files still
# drive the real on-disk Configuration/PropertySet state (Import-Configuration,
# Get-ConfigurationPath, Export-GatekeeperConfig) rather than a fully mocked
# path; the leading suspect is cross-process file-lock contention on that
# shared state once files genuinely run concurrently as separate processes.
# Not yet root-caused far enough to fix - left here, clearly labeled, as a
# starting point rather than undocumented/rediscovered from scratch.
Task TestParallel -depends Build -description 'EXPERIMENTAL, CURRENTLY HANGS: Pester 6 Run.Parallel - see comment above task' {
    Import-Module -Name Pester -MinimumVersion 6.0.0 -Force -Verbose:$false

    $config = New-PesterConfiguration
    $config.Run.Path = $PSBPreference.Test.RootDir
    $config.Run.Parallel = $true
    $config.Run.ParallelThrottleLimit = 4
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
