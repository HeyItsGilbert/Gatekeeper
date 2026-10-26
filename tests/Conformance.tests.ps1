BeforeDiscovery {
    if ($env:BHPSModuleManifest -eq $null -or $env:BHProjectPath -eq $null -or $env:BHProjectName -eq $null) {
        . $PSScriptRoot\..\build.ps1 -Task Build
    }
    $manifest = Import-PowerShellDataFile -Path $env:BHPSModuleManifest
    $outputDir = Join-Path -Path $env:BHProjectPath -ChildPath 'Output'
    $outputModDir = Join-Path -Path $outputDir -ChildPath $env:BHProjectName
    $outputModVerDir = Join-Path -Path $outputModDir -ChildPath $manifest.ModuleVersion
    $outputModVerManifest = Join-Path -Path $outputModVerDir -ChildPath "$($env:BHProjectName).psd1"
    Get-Module $env:BHProjectName | Remove-Module -Force -ErrorAction Ignore
    Import-Module -Name $outputModVerManifest -Verbose:$false -ErrorAction Stop

    # Discover every conformance case across every category file. Each case
    # carries enough to resolve its own fixtures relative to the case file
    # (conformance/README.md documents the shape). $decisionCases/$errorCases
    # feed the -ForEach on the It blocks below.
    $conformanceRoot = Join-Path -Path $PSScriptRoot -ChildPath '..\conformance\cases' | Resolve-Path
    $allCases = foreach ($file in Get-ChildItem -Path $conformanceRoot -Filter '*.json') {
        $cases = Get-Content -Path $file.FullName -Raw | ConvertFrom-Json -AsHashtable
        foreach ($case in $cases) {
            $case['SourceFile'] = $file.BaseName
            $case['CaseDir'] = $file.DirectoryName
            $case
        }
    }
    $decisionCases = $allCases | Where-Object { $_.expect.ContainsKey('result') -or $_.expect.ContainsKey('decision') }
    $errorCases = $allCases | Where-Object { $_.expect.ContainsKey('error') }
}

Describe 'Conformance suite' {
    BeforeAll {
        # Resolves a case field that is either an inline object/hashtable
        # (used as-is) or a string path relative to the case file (loaded
        # from disk) — mirrors FeatureFlagTransformAttribute/
        # ConditionTransformAttribute's own inline-vs-path handling.
        function Resolve-ConformanceAsset {
            param($Value, [string]$CaseDir)
            if ($Value -is [string]) {
                return Join-Path -Path $CaseDir -ChildPath $Value
            }
            return $Value
        }

        Mock -CommandName Invoke-Logging -ModuleName $env:BHProjectName
    }

    Context 'Decision cases' {
        BeforeEach {
            Mock -CommandName Invoke-Logging -ModuleName $env:BHProjectName
        }

        It '<name> [<SourceFile>]' -ForEach $decisionCases {
            $propertySetPath = Resolve-ConformanceAsset -Value $propertySet -CaseDir $CaseDir
            $boundPropertySet = InModuleScope $env:BHProjectName -Parameters @{ Path = $propertySetPath } {
                param($Path)
                [PropertySet]::FromFile($Path)
            }

            if ($kind -eq 'condition') {
                $conditionArg = Resolve-ConformanceAsset -Value $condition -CaseDir $CaseDir
                $result = Test-Condition -Context $context -PropertySet $boundPropertySet -Condition $conditionArg
                $result | Should -Be $expect.result -Because $description
            }
            elseif ($kind -eq 'flag') {
                $flagArg = Resolve-ConformanceAsset -Value $flag -CaseDir $CaseDir
                $result = Test-FeatureFlag -FeatureFlag $flagArg -PropertySet $boundPropertySet -Context $context
                $result | Should -Be $expect.decision.result -Because $description

                if ($expect.ContainsKey('events')) {
                    foreach ($expectedEvent in $expect.events) {
                        Should -Invoke -CommandName Invoke-Logging -ModuleName $env:BHProjectName `
                            -ParameterFilter { $Effect -eq $expectedEvent.effect -and $Rule.Name -eq $expectedEvent.ruleName } `
                            -Times 1
                    }
                }
            }
            else {
                throw "Unknown case kind: $kind"
            }
        }
    }

    Context 'Error cases — target contract from issue #96, not yet implemented' {
        # Fail-closed error records, up-front flag-scoped context validation
        # and bind-time schema/unknown-property checks are PS hand-off work
        # this map lists but does not execute (see conformance/README.md).
        # These cases are the acceptance criteria for that hand-off: skipped,
        # not deleted, so un-skipping + passing is how the hand-off is proven
        # done.
        It '<name> [<SourceFile>]' -ForEach $errorCases -Skip {
            $propertySetPath = Resolve-ConformanceAsset -Value $propertySet -CaseDir $CaseDir
            $boundPropertySet = InModuleScope $env:BHProjectName -Parameters @{ Path = $propertySetPath } {
                param($Path)
                [PropertySet]::FromFile($Path)
            }

            $errorRecord = $null
            if ($kind -eq 'condition') {
                $conditionArg = Resolve-ConformanceAsset -Value $condition -CaseDir $CaseDir
                $result = Test-Condition -Context $context -PropertySet $boundPropertySet -Condition $conditionArg -ErrorVariable errorRecord -ErrorAction SilentlyContinue
            }
            else {
                $flagArg = Resolve-ConformanceAsset -Value $flag -CaseDir $CaseDir
                $result = Test-FeatureFlag -FeatureFlag $flagArg -PropertySet $boundPropertySet -Context $context -ErrorVariable errorRecord -ErrorAction SilentlyContinue
            }

            $result | Should -BeFalse -Because 'every non-Decision outcome fails closed'
            $actualPairs = $errorRecord | ForEach-Object { [PSCustomObject]@{ code = $_.FullyQualifiedErrorId; property = $_.TargetObject } }
            foreach ($pair in $expect.error.pairs) {
                $actualPairs | Where-Object { $_.code -eq $pair.code -and $_.property -eq $pair.property } |
                    Should -Not -BeNullOrEmpty -Because "expected ($($pair.code), $($pair.property)) among the reported errors"
            }
        }
    }
}
