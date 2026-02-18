BeforeDiscovery {
    $manifest = Import-PowerShellDataFile -Path $env:BHPSModuleManifest
    $outputDir = Join-Path -Path $env:BHProjectPath -ChildPath 'Output'
    $outputModDir = Join-Path -Path $outputDir -ChildPath $env:BHProjectName
    $outputModVerDir = Join-Path -Path $outputModDir -ChildPath $manifest.ModuleVersion
    $outputModVerManifest = Join-Path -Path $outputModVerDir -ChildPath "$($env:BHProjectName).psd1"

    # Get module commands
    # Remove all versions of the module from the session. Pester can't handle multiple versions.
    Get-Module $env:BHProjectName | Remove-Module -Force -ErrorAction Ignore
    Import-Module -Name $outputModVerManifest -Verbose:$false -ErrorAction Stop
}

Describe 'Save-FeatureFlag' {
    BeforeAll {
        # Import test helpers
        Import-Module -Name "$PSScriptRoot\Helpers\TestHelpers.psm1" -Force
    }

    AfterEach {
        # Clean up any test files created
        Get-ChildItem -Path ([System.IO.Path]::GetTempPath()) -Filter 'GatekeeperTest_*.json' -ErrorAction SilentlyContinue |
            Remove-Item -Force -ErrorAction SilentlyContinue
    }

    Context 'Parameter validation' {
        It 'should require FeatureFlag parameter' {
            { Save-FeatureFlag -ErrorAction Stop } | Should -Throw
        }

        It 'should accept FeatureFlag object' {
            $flag = New-TestFeatureFlag -Name 'TestFlag'
            $testFile = Get-TestFilePath
            { Save-FeatureFlag -FeatureFlag $flag -FilePath $testFile } | Should -Not -Throw
        }
    }

    Context 'Saving with explicit FilePath' {
        It 'should save to specified file path' {
            $flag = New-TestFeatureFlag -Name 'TestFlag'
            $testFile = Get-TestFilePath

            Save-FeatureFlag -FeatureFlag $flag -FilePath $testFile
            Test-Path $testFile | Should -BeTrue
        }

        It 'should create parent directory if it does not exist' {
            $flag = New-TestFeatureFlag -Name 'TestFlag'
            $tempPath = Join-Path ([System.IO.Path]::GetTempPath()) "GatekeeperTest_$(New-Guid)"
            $testFile = Join-Path $tempPath 'test.json'

            try {
                Save-FeatureFlag -FeatureFlag $flag -FilePath $testFile
                Test-Path $testFile | Should -BeTrue
                Test-Path $tempPath | Should -BeTrue
            } finally {
                if (Test-Path $tempPath) {
                    Remove-Item $tempPath -Recurse -Force -ErrorAction SilentlyContinue
                }
            }
        }

        It 'should update FeatureFlag FilePath property' {
            $flag = New-TestFeatureFlag -Name 'TestFlag'
            $testFile = Get-TestFilePath

            Save-FeatureFlag -FeatureFlag $flag -FilePath $testFile
            $flag.FilePath | Should -Be $testFile
        }

        It 'should save valid JSON' {
            $flag = New-TestFeatureFlag -Name 'TestFlag'
            $testFile = Get-TestFilePath

            Save-FeatureFlag -FeatureFlag $flag -FilePath $testFile
            { Get-Content $testFile -Raw | ConvertFrom-Json } | Should -Not -Throw
        }

        It 'should preserve feature flag properties' {
            $flag = New-TestFeatureFlag -Name 'SaveTest' -DefaultEffect 'Deny'
            $testFile = Get-TestFilePath

            Save-FeatureFlag -FeatureFlag $flag -FilePath $testFile
            $json = Get-Content $testFile -Raw | ConvertFrom-Json
            $json.Name | Should -Be 'SaveTest'
            $json.DefaultEffect | Should -Be 'Deny'
        }
    }

    Context 'Saving with default FilePath' {
        It 'should use FeatureFlag existing FilePath when not specified' {
            $flag = New-TestFeatureFlag -Name 'TestFlag'
            $testFile = Get-TestFilePath
            $flag.FilePath = $testFile

            Save-FeatureFlag -FeatureFlag $flag
            Test-Path $testFile | Should -BeTrue
        }

        It 'should throw when FeatureFlag has no FilePath' {
            $flag = [FeatureFlag]::new()
            $flag.Name = 'TestFlag'
            $flag.FilePath = $null

            { Save-FeatureFlag -FeatureFlag $flag -ErrorAction Stop } | Should -Throw
        }
    }

    Context 'Pipeline support' {
        It 'should accept FeatureFlag via pipeline' {
            $flag = New-TestFeatureFlag -Name 'TestFlag'
            $testFile = Get-TestFilePath

            { $flag | Save-FeatureFlag -FilePath $testFile } | Should -Not -Throw
            Test-Path $testFile | Should -BeTrue
        }

        It 'should save multiple FeatureFlags via pipeline' {
            $flag1 = New-TestFeatureFlag -Name 'Flag1'
            $flag2 = New-TestFeatureFlag -Name 'Flag2'

            $testFile1 = Get-TestFilePath
            $testFile2 = Get-TestFilePath

            $flag1.FilePath = $testFile1
            $flag2.FilePath = $testFile2

            $flag1, $flag2 | Save-FeatureFlag

            Test-Path $testFile1 | Should -BeTrue
            Test-Path $testFile2 | Should -BeTrue
        }
    }

    Context 'Content validation' {
        It 'should save Name correctly' {
            $flag = New-TestFeatureFlag -Name 'ContentTest'
            $testFile = Get-TestFilePath

            Save-FeatureFlag -FeatureFlag $flag -FilePath $testFile
            $json = Get-Content $testFile -Raw | ConvertFrom-Json
            $json.Name | Should -Be 'ContentTest'
        }

        It 'should save DefaultEffect correctly' {
            $flag = New-TestFeatureFlag -Name 'TestFlag' -DefaultEffect 'Allow'
            $testFile = Get-TestFilePath

            Save-FeatureFlag -FeatureFlag $flag -FilePath $testFile
            $json = Get-Content $testFile -Raw | ConvertFrom-Json
            $json.DefaultEffect | Should -Be 'Allow'
        }

        It 'should save Rules correctly' {
            $rule = New-TestRule -Name 'TestRule' -Effect 'Allow'
            $flag = New-TestFeatureFlag -Name 'TestFlag' -Rules @($rule)
            $testFile = Get-TestFilePath

            Save-FeatureFlag -FeatureFlag $flag -FilePath $testFile
            $json = Get-Content $testFile -Raw | ConvertFrom-Json
            $json.Rules.Count | Should -Be 1
            $json.Rules[0].Name | Should -Be 'TestRule'
        }

        It 'should save Tags correctly' {
            $flag = New-FeatureFlag -Name 'TestFlag' -Tags @('tag1', 'tag2')
            $testFile = Get-TestFilePath
            $flag.FilePath = $testFile

            Save-FeatureFlag -FeatureFlag $flag
            $json = Get-Content $testFile -Raw | ConvertFrom-Json
            $json.Tags.Count | Should -Be 2
        }

        It 'should save Version correctly' {
            $flag = New-FeatureFlag -Name 'TestFlag' -Version '2.0.0'
            $testFile = Get-TestFilePath
            $flag.FilePath = $testFile

            Save-FeatureFlag -FeatureFlag $flag
            $json = Get-Content $testFile -Raw | ConvertFrom-Json
            $json.Version | Should -Be '2.0.0'
        }
    }

    Context 'Round-trip serialization' {
        It 'should allow reading back saved feature flag' {
            $originalFlag = New-TestFeatureFlag -Name 'RoundTripTest' -DefaultEffect 'Deny'
            $rule = New-TestRule -Name 'TestRule' -Effect 'Allow'
            $originalFlag.Rules = @($rule)
            $testFile = Get-TestFilePath

            Save-FeatureFlag -FeatureFlag $originalFlag -FilePath $testFile
            $loadedFlag = [FeatureFlag]::FromFile($testFile)

            $loadedFlag.Name | Should -Be 'RoundTripTest'
            $loadedFlag.DefaultEffect | Should -Be 'Deny'
            $loadedFlag.Rules.Count | Should -Be 1
        }

        It 'should preserve complex rule structures' {
            $condition1 = New-TestCondition -Property 'Environment' -Operator 'Equals' -Value 'Production'
            $condition2 = New-TestCondition -Property 'Percentage' -Operator 'GreaterThan' -Value 50
            $conditions = New-ConditionGroup -Operator 'AllOf' -Conditions @($condition1, $condition2)
            $rule = New-Rule -Name 'ComplexRule' -Effect 'Allow' -Conditions $conditions

            $flag = New-TestFeatureFlag -Name 'ComplexTest' -Rules @($rule)
            $testFile = Get-TestFilePath

            Save-FeatureFlag -FeatureFlag $flag -FilePath $testFile
            $loadedFlag = [FeatureFlag]::FromFile($testFile)

            $loadedFlag.Rules[0].Name | Should -Be 'ComplexRule'
            $loadedFlag.Rules[0].Conditions | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Overwriting existing files' {
        It 'should overwrite existing file' {
            $flag1 = New-TestFeatureFlag -Name 'Original'
            $testFile = Get-TestFilePath

            Save-FeatureFlag -FeatureFlag $flag1 -FilePath $testFile
            $originalContent = Get-Content $testFile -Raw

            $flag2 = New-TestFeatureFlag -Name 'Updated'
            Save-FeatureFlag -FeatureFlag $flag2 -FilePath $testFile
            $updatedContent = Get-Content $testFile -Raw

            $updatedContent | Should -Not -Be $originalContent
            $json = $updatedContent | ConvertFrom-Json
            $json.Name | Should -Be 'Updated'
        }
    }

    Context 'Edge cases' {
        It 'should handle feature flag with no rules' {
            $flag = New-TestFeatureFlag -Name 'NoRules'
            $testFile = Get-TestFilePath

            Save-FeatureFlag -FeatureFlag $flag -FilePath $testFile
            $json = Get-Content $testFile -Raw | ConvertFrom-Json
            $json.Rules | Should -BeOfType [array]
            $json.Rules.Count | Should -Be 0
        }

        It 'should handle feature flag with many rules' {
            $rules = 1..50 | ForEach-Object {
                New-TestRule -Name "Rule$_" -Effect 'Allow'
            }
            $flag = New-TestFeatureFlag -Name 'ManyRules' -Rules $rules
            $testFile = Get-TestFilePath

            Save-FeatureFlag -FeatureFlag $flag -FilePath $testFile
            $json = Get-Content $testFile -Raw | ConvertFrom-Json
            $json.Rules.Count | Should -Be 50
        }

        It 'should handle special characters in properties' {
            $flag = New-FeatureFlag -Name 'Special-Chars_Test' -Description "Test with 'quotes' and `"double quotes`""
            $testFile = Get-TestFilePath
            $flag.FilePath = $testFile

            Save-FeatureFlag -FeatureFlag $flag
            $json = Get-Content $testFile -Raw | ConvertFrom-Json
            $json.Name | Should -Be 'Special-Chars_Test'
        }
    }
}
