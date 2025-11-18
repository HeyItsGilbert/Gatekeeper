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

Describe 'New-FeatureFlag' {
    BeforeAll {
        # Import test helpers
        Import-Module -Name "$PSScriptRoot\Helpers\TestHelpers.psm1" -Force
    }

    Context 'Parameter validation' {
        It 'should require Name parameter' {
            { New-FeatureFlag -ErrorAction Stop } | Should -Throw
        }

        It 'should not allow null or empty Name' {
            { New-FeatureFlag -Name '' -ErrorAction Stop } | Should -Throw
            { New-FeatureFlag -Name $null -ErrorAction Stop } | Should -Throw
        }

        It 'should accept valid Effect values for DefaultEffect' {
            $validEffects = @('Allow', 'Deny', 'Warn', 'Audit')
            foreach ($effect in $validEffects) {
                { New-FeatureFlag -Name 'TestFlag' -DefaultEffect $effect -WhatIf } | Should -Not -Throw
            }
        }
    }

    Context 'Basic feature flag creation' {
        It 'should create feature flag with minimal parameters' {
            $flag = New-FeatureFlag -Name 'MinimalFlag'
            $flag | Should -Not -BeNullOrEmpty
            $flag | Should -BeOfType [FeatureFlag]
            $flag.Name | Should -Be 'MinimalFlag'
        }

        It 'should set default description' {
            $flag = New-FeatureFlag -Name 'TestFlag'
            $flag.Description | Should -BeLike '*TestFlag*'
        }

        It 'should use default version 1.0.0' {
            $flag = New-FeatureFlag -Name 'TestFlag'
            $flag.Version | Should -Be ([version]'1.0.0')
        }

        It 'should use current username as default author' {
            $flag = New-FeatureFlag -Name 'TestFlag'
            $flag.Author | Should -Be $env:USERNAME
        }

        It 'should use Warn as default effect' {
            $flag = New-FeatureFlag -Name 'TestFlag'
            $flag.DefaultEffect | Should -Be 'Warn'
        }

        It 'should have empty Rules array by default' {
            $flag = New-FeatureFlag -Name 'TestFlag'
            $flag.Rules | Should -BeOfType [array]
            $flag.Rules.Count | Should -Be 0
        }

        It 'should set FilePath property' {
            $flag = New-FeatureFlag -Name 'TestFlag'
            $flag.FilePath | Should -Not -BeNullOrEmpty
            $flag.FilePath | Should -BeLike '*TestFlag.json'
        }
    }

    Context 'Custom parameters' {
        It 'should accept custom description' {
            $flag = New-FeatureFlag -Name 'TestFlag' -Description 'Custom description'
            $flag.Description | Should -Be 'Custom description'
        }

        It 'should accept custom version' {
            $flag = New-FeatureFlag -Name 'TestFlag' -Version '2.5.3'
            $flag.Version | Should -Be ([version]'2.5.3')
        }

        It 'should accept custom author' {
            $flag = New-FeatureFlag -Name 'TestFlag' -Author 'John Doe'
            $flag.Author | Should -Be 'John Doe'
        }

        It 'should accept custom default effect' {
            $flag = New-FeatureFlag -Name 'TestFlag' -DefaultEffect 'Deny'
            $flag.DefaultEffect | Should -Be 'Deny'
        }

        It 'should accept tags' {
            $tags = @('feature', 'beta', 'experimental')
            $flag = New-FeatureFlag -Name 'TestFlag' -Tags $tags
            $flag.Tags | Should -Be $tags
            $flag.Tags.Count | Should -Be 3
        }

        It 'should accept empty tags array' {
            $flag = New-FeatureFlag -Name 'TestFlag' -Tags @()
            $flag.Tags | Should -BeOfType [array]
        }
    }

    Context 'Rules parameter' {
        It 'should accept single rule' {
            $rule = New-TestRule -Name 'AllowProd' -Effect 'Allow'
            $flag = New-FeatureFlag -Name 'TestFlag' -Rules $rule
            $flag.Rules.Count | Should -Be 1
            $flag.Rules[0].Name | Should -Be 'AllowProd'
        }

        It 'should accept multiple rules' {
            $rule1 = New-TestRule -Name 'Rule1' -Effect 'Allow'
            $rule2 = New-TestRule -Name 'Rule2' -Effect 'Deny'
            $rules = @($rule1, $rule2)

            $flag = New-FeatureFlag -Name 'TestFlag' -Rules $rules
            $flag.Rules.Count | Should -Be 2
        }

        It 'should accept rules via pipeline' {
            $rule1 = New-TestRule -Name 'Rule1' -Effect 'Allow'
            $rule2 = New-TestRule -Name 'Rule2' -Effect 'Deny'

            $flag = $rule1, $rule2 | New-FeatureFlag -Name 'TestFlag'
            $flag.Rules.Count | Should -Be 2
        }

        It 'should handle empty rules array' {
            $flag = New-FeatureFlag -Name 'TestFlag' -Rules @()
            $flag.Rules.Count | Should -Be 0
        }
    }

    Context 'FilePath handling' {
        It 'should use default folder when no FilePath specified' {
            $expectedFolder = Get-FeatureFlagFolder
            $flag = New-FeatureFlag -Name 'TestFlag'
            $flag.FilePath | Should -BeLike "$expectedFolder*"
        }

        It 'should use custom FilePath when specified' {
            $customPath = [System.IO.Path]::GetTempPath()
            $flag = New-FeatureFlag -Name 'TestFlag' -FilePath $customPath
            $flag.FilePath | Should -BeLike "$customPath*"
        }

        It 'should create directory if FilePath does not exist' {
            $tempPath = Join-Path ([System.IO.Path]::GetTempPath()) "GatekeeperTest_$(New-Guid)"
            try {
                Test-Path $tempPath | Should -BeFalse
                $flag = New-FeatureFlag -Name 'TestFlag' -FilePath $tempPath
                Test-Path $tempPath | Should -BeTrue
            } finally {
                if (Test-Path $tempPath) {
                    Remove-Item $tempPath -Force -ErrorAction SilentlyContinue
                }
            }
        }
    }

    Context 'ShouldProcess support' {
        It 'should support -WhatIf for rule addition' {
            $rule = New-TestRule -Name 'TestRule' -Effect 'Allow'
            # With -WhatIf, rules should not be added
            $flag = New-FeatureFlag -Name 'TestFlag' -Rules $rule -WhatIf
            if ($flag) {
                $flag.Rules.Count | Should -Be 0
            }
        }

        It 'should add rules without -WhatIf' {
            $rule = New-TestRule -Name 'TestRule' -Effect 'Allow'
            $flag = New-FeatureFlag -Name 'TestFlag' -Rules $rule
            $flag.Rules.Count | Should -Be 1
        }
    }

    Context 'Complex scenarios' {
        It 'should create fully configured feature flag' {
            $condition = New-TestCondition -Property 'Environment' -Operator 'Equals' -Value 'Production'
            $rule1 = New-Rule -Name 'AllowProd' -Description 'Allow in production' -Effect 'Allow' -Conditions $condition
            $rule2 = New-TestRule -Name 'DenyDev' -Effect 'Deny'

            $flag = New-FeatureFlag `
                -Name 'FullyConfiguredFlag' `
                -Description 'A fully configured feature flag' `
                -Version '1.2.3' `
                -Author 'Test Author' `
                -DefaultEffect 'Deny' `
                -Tags @('important', 'production') `
                -Rules @($rule1, $rule2)

            $flag.Name | Should -Be 'FullyConfiguredFlag'
            $flag.Description | Should -Be 'A fully configured feature flag'
            $flag.Version | Should -Be ([version]'1.2.3')
            $flag.Author | Should -Be 'Test Author'
            $flag.DefaultEffect | Should -Be 'Deny'
            $flag.Tags.Count | Should -Be 2
            $flag.Rules.Count | Should -Be 2
        }

        It 'should handle multiple rules via pipeline with complex conditions' {
            $rules = 1..5 | ForEach-Object {
                $condition = New-TestCondition -Property 'Percentage' -Operator 'GreaterThan' -Value ($_ * 10)
                New-Rule -Name "Rule$_" -Effect 'Allow' -Conditions $condition
            }

            $flag = $rules | New-FeatureFlag -Name 'MultiRuleFlag'
            $flag.Rules.Count | Should -Be 5
        }
    }

    Context 'Edge cases' {
        It 'should handle feature flag name with special characters' {
            $flag = New-FeatureFlag -Name 'Test-Flag_123'
            $flag.Name | Should -Be 'Test-Flag_123'
        }

        It 'should handle long feature flag names' {
            $longName = 'A' * 200
            $flag = New-FeatureFlag -Name $longName
            $flag.Name | Should -Be $longName
        }

        It 'should handle long descriptions' {
            $longDescription = 'This is a very long description. ' * 100
            $flag = New-FeatureFlag -Name 'TestFlag' -Description $longDescription
            $flag.Description.Length | Should -BeGreaterThan 1000
        }

        It 'should handle many tags' {
            $tags = 1..100 | ForEach-Object { "Tag$_" }
            $flag = New-FeatureFlag -Name 'TestFlag' -Tags $tags
            $flag.Tags.Count | Should -Be 100
        }

        It 'should handle many rules' {
            $rules = 1..50 | ForEach-Object {
                New-TestRule -Name "Rule$_" -Effect 'Allow'
            }
            $flag = $rules | New-FeatureFlag -Name 'ManyRulesFlag'
            $flag.Rules.Count | Should -Be 50
        }
    }

    Context 'Feature flag structure validation' {
        It 'should have all required properties' {
            $flag = New-FeatureFlag -Name 'TestFlag'
            $flag.Name | Should -Not -BeNullOrEmpty
            $flag.Description | Should -Not -BeNullOrEmpty
            $flag.Version | Should -Not -BeNullOrEmpty
            $flag.Author | Should -Not -BeNullOrEmpty
            $flag.DefaultEffect | Should -Not -BeNullOrEmpty
            $flag.Rules | Should -Not -BeNull
            $flag.FilePath | Should -Not -BeNullOrEmpty
        }

        It 'should be of correct type' {
            $flag = New-FeatureFlag -Name 'TestFlag'
            $flag | Should -BeOfType [FeatureFlag]
        }
    }

    Context 'Integration with Get-FeatureFlagFolder' {
        It 'should use Get-FeatureFlagFolder for default FilePath' {
            $expectedFolder = Get-FeatureFlagFolder
            $flag = New-FeatureFlag -Name 'TestFlag'
            $flag.FilePath | Should -Match [regex]::Escape($expectedFolder)
        }
    }
}
