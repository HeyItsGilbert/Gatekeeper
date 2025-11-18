BeforeDiscovery {
    $manifest = Import-PowerShellDataFile -Path $env:BHPSModuleManifest
    $outputDir = Join-Path -Path $env:BHProjectPath -ChildPath 'Output'
    $outputModDir = Join-Path -Path $outputDir -ChildPath $env:BHProjectName
    $outputModVerDir = Join-Path -Path $outputModDir -ChildPath $manifest.ModuleVersion
    $outputModVerManifest = Join-Path -Path $outputModVerDir -ChildPath "$($env:BHProjectName).psd1"

    # Get module commands
    # Remove all versions of the module from the session. Pester can't handle multiple versions.
    Get-Module $env:BHProjectName | Remove-Module -Force -ErrorAction Stop
    Import-Module -Name $outputModVerManifest -Verbose:$false -ErrorAction Stop
}

Describe 'New-Rule' {
    BeforeAll {
        # Import test helpers
        Import-Module -Name "$PSScriptRoot\Helpers\TestHelpers.psm1" -Force
    }

    Context 'Parameter validation' {
        It 'should require Name parameter' {
            $condition = New-TestCondition -Property 'Environment' -Operator 'Equals' -Value 'Production'
            { New-Rule -Effect 'Allow' -Conditions $condition -ErrorAction Stop } | Should -Throw
        }

        It 'should require Effect parameter' {
            $condition = New-TestCondition -Property 'Environment' -Operator 'Equals' -Value 'Production'
            { New-Rule -Name 'TestRule' -Conditions $condition -ErrorAction Stop } | Should -Throw
        }

        It 'should require Conditions parameter' {
            { New-Rule -Name 'TestRule' -Effect 'Allow' -ErrorAction Stop } | Should -Throw
        }

        It 'should accept valid Effect values' {
            $condition = New-TestCondition -Property 'Environment' -Operator 'Equals' -Value 'Production'
            $validEffects = @('Allow', 'Deny', 'Warn', 'Audit')

            foreach ($effect in $validEffects) {
                { New-Rule -Name 'TestRule' -Effect $effect -Conditions $condition -WhatIf } | Should -Not -Throw
            }
        }
    }

    Context 'Basic rule creation' {
        It 'should create rule with Allow effect' {
            $condition = New-TestCondition -Property 'Environment' -Operator 'Equals' -Value 'Production'
            $rule = New-Rule -Name 'AllowProduction' -Effect 'Allow' -Conditions $condition
            $rule | Should -Not -BeNullOrEmpty
            $rule | Should -BeOfType [Rule]
            $rule.Name | Should -Be 'AllowProduction'
            $rule.Effect | Should -Be 'Allow'
            $rule.Conditions | Should -Not -BeNullOrEmpty
        }

        It 'should create rule with Deny effect' {
            $condition = New-TestCondition -Property 'Environment' -Operator 'Equals' -Value 'Development'
            $rule = New-Rule -Name 'DenyDevelopment' -Effect 'Deny' -Conditions $condition
            $rule | Should -Not -BeNullOrEmpty
            $rule.Effect | Should -Be 'Deny'
        }

        It 'should create rule with Warn effect' {
            $condition = New-TestCondition -Property 'Percentage' -Operator 'LessThan' -Value 10
            $rule = New-Rule -Name 'WarnLowPercentage' -Effect 'Warn' -Conditions $condition
            $rule | Should -Not -BeNullOrEmpty
            $rule.Effect | Should -Be 'Warn'
        }

        It 'should create rule with Audit effect' {
            $condition = New-TestCondition -Property 'IsCompliant' -Operator 'Equals' -Value $false
            $rule = New-Rule -Name 'AuditNonCompliant' -Effect 'Audit' -Conditions $condition
            $rule | Should -Not -BeNullOrEmpty
            $rule.Effect | Should -Be 'Audit'
        }
    }

    Context 'Description parameter' {
        It 'should accept optional description' {
            $condition = New-TestCondition -Property 'Environment' -Operator 'Equals' -Value 'Production'
            $rule = New-Rule -Name 'TestRule' -Description 'Test description' -Effect 'Allow' -Conditions $condition
            $rule.Description | Should -Be 'Test description'
        }

        It 'should handle null description' {
            $condition = New-TestCondition -Property 'Environment' -Operator 'Equals' -Value 'Production'
            $rule = New-Rule -Name 'TestRule' -Effect 'Allow' -Conditions $condition
            # Description should be null or empty
            $rule.Description | Should -BeNullOrEmpty
        }

        It 'should handle empty string description' {
            $condition = New-TestCondition -Property 'Environment' -Operator 'Equals' -Value 'Production'
            $rule = New-Rule -Name 'TestRule' -Description '' -Effect 'Allow' -Conditions $condition
            $rule.Description | Should -Be ''
        }
    }

    Context 'Single condition' {
        It 'should accept single condition' {
            $condition = New-TestCondition -Property 'Environment' -Operator 'Equals' -Value 'Production'
            $rule = New-Rule -Name 'TestRule' -Effect 'Allow' -Conditions $condition
            $rule.Conditions | Should -Not -BeNullOrEmpty
            $rule.Conditions | Should -BeOfType [ConditionGroup]
        }

        It 'should wrap single condition in AllOf group' {
            $condition = New-TestCondition -Property 'Environment' -Operator 'Equals' -Value 'Production'
            $rule = New-Rule -Name 'TestRule' -Effect 'Allow' -Conditions $condition
            # The function wraps single conditions in an AllOf group
            $rule.Conditions.AllOf | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Multiple conditions via pipeline' {
        It 'should accept multiple conditions via pipeline' {
            $condition1 = New-TestCondition -Property 'Environment' -Operator 'Equals' -Value 'Production'
            $condition2 = New-TestCondition -Property 'Percentage' -Operator 'GreaterThan' -Value 50

            $rule = $condition1, $condition2 | New-Rule -Name 'MultiConditionRule' -Effect 'Allow'
            $rule | Should -Not -BeNullOrEmpty
            $rule.Conditions.AllOf | Should -Not -BeNullOrEmpty
            $rule.Conditions.AllOf.Count | Should -Be 2
        }

        It 'should combine piped conditions with AllOf logic' {
            $conditions = 1..5 | ForEach-Object {
                New-TestCondition -Property 'Percentage' -Operator 'GreaterThan' -Value ($_ * 10)
            }

            $rule = $conditions | New-Rule -Name 'ComplexRule' -Effect 'Allow'
            $rule.Conditions.AllOf.Count | Should -Be 5
        }
    }

    Context 'Empty conditions handling' {
        It 'should warn when no conditions provided' {
            # Create rule without piping any conditions
            $warningMessages = @()
            $rule = New-Rule -Name 'NoConditions' -Effect 'Allow' -Conditions @() -WarningVariable warningMessages -WarningAction SilentlyContinue
            $warningMessages | Should -Not -BeNullOrEmpty
            $warningMessages | Should -BeLike '*No conditions*'
        }
    }

    Context 'Complex condition groups' {
        It 'should accept AllOf condition group' {
            $condition1 = New-TestCondition -Property 'Environment' -Operator 'Equals' -Value 'Production'
            $condition2 = New-TestCondition -Property 'IsCompliant' -Operator 'Equals' -Value $true
            $allOfGroup = New-ConditionGroup -Operator 'AllOf' -Conditions @($condition1, $condition2)

            $rule = New-Rule -Name 'AllOfRule' -Effect 'Allow' -Conditions $allOfGroup
            $rule.Conditions | Should -Not -BeNullOrEmpty
        }

        It 'should accept AnyOf condition group' {
            $condition1 = New-TestCondition -Property 'Environment' -Operator 'Equals' -Value 'Development'
            $condition2 = New-TestCondition -Property 'Environment' -Operator 'Equals' -Value 'Staging'
            $anyOfGroup = New-ConditionGroup -Operator 'AnyOf' -Conditions @($condition1, $condition2)

            $rule = New-Rule -Name 'AnyOfRule' -Effect 'Deny' -Conditions $anyOfGroup
            $rule.Conditions | Should -Not -BeNullOrEmpty
        }

        It 'should accept Not condition group' {
            $condition = New-TestCondition -Property 'Environment' -Operator 'Equals' -Value 'Production'
            $notGroup = New-ConditionGroup -Operator 'Not' -Conditions $condition

            $rule = New-Rule -Name 'NotRule' -Effect 'Deny' -Conditions $notGroup
            $rule.Conditions | Should -Not -BeNullOrEmpty
        }

        It 'should accept nested condition groups' {
            $condition1 = New-TestCondition -Property 'Environment' -Operator 'Equals' -Value 'Production'
            $condition2 = New-TestCondition -Property 'IsCompliant' -Operator 'Equals' -Value $true
            $innerGroup = New-ConditionGroup -Operator 'AllOf' -Conditions @($condition1, $condition2)

            $condition3 = New-TestCondition -Property 'Percentage' -Operator 'GreaterThan' -Value 75
            $outerGroup = New-ConditionGroup -Operator 'AnyOf' -Conditions @($innerGroup, $condition3)

            $rule = New-Rule -Name 'NestedRule' -Effect 'Allow' -Conditions $outerGroup
            $rule.Conditions | Should -Not -BeNullOrEmpty
        }
    }

    Context 'ShouldProcess support' {
        It 'should support -WhatIf for rule creation' {
            $condition = New-TestCondition -Property 'Environment' -Operator 'Equals' -Value 'Production'
            $result = New-Rule -Name 'TestRule' -Effect 'Allow' -Conditions $condition -WhatIf
            # With -WhatIf, the function should not create the rule
            $result | Should -BeNullOrEmpty
        }

        It 'should support -WhatIf for adding conditions' {
            $condition = New-TestCondition -Property 'Environment' -Operator 'Equals' -Value 'Production'
            # With -WhatIf at condition level, conditions might not be added
            # This tests the ShouldProcess on the condition addition
            { New-Rule -Name 'TestRule' -Effect 'Allow' -Conditions $condition -WhatIf } | Should -Not -Throw
        }

        It 'should create rule without -WhatIf' {
            $condition = New-TestCondition -Property 'Environment' -Operator 'Equals' -Value 'Production'
            $result = New-Rule -Name 'TestRule' -Effect 'Allow' -Conditions $condition
            $result | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Edge cases' {
        It 'should handle rule name with special characters' {
            $condition = New-TestCondition -Property 'Environment' -Operator 'Equals' -Value 'Production'
            $rule = New-Rule -Name 'Test-Rule_123' -Effect 'Allow' -Conditions $condition
            $rule.Name | Should -Be 'Test-Rule_123'
        }

        It 'should handle long rule names' {
            $longName = 'A' * 200
            $condition = New-TestCondition -Property 'Environment' -Operator 'Equals' -Value 'Production'
            $rule = New-Rule -Name $longName -Effect 'Allow' -Conditions $condition
            $rule.Name | Should -Be $longName
        }

        It 'should handle long descriptions' {
            $longDescription = 'This is a very long description. ' * 100
            $condition = New-TestCondition -Property 'Environment' -Operator 'Equals' -Value 'Production'
            $rule = New-Rule -Name 'TestRule' -Description $longDescription -Effect 'Allow' -Conditions $condition
            $rule.Description.Length | Should -BeGreaterThan 1000
        }
    }

    Context 'Rule structure validation' {
        It 'should have all required properties' {
            $condition = New-TestCondition -Property 'Environment' -Operator 'Equals' -Value 'Production'
            $rule = New-Rule -Name 'TestRule' -Effect 'Allow' -Conditions $condition
            $rule.Name | Should -Not -BeNullOrEmpty
            $rule.Effect | Should -Not -BeNullOrEmpty
            $rule.Conditions | Should -Not -BeNullOrEmpty
        }

        It 'should be of correct type' {
            $condition = New-TestCondition -Property 'Environment' -Operator 'Equals' -Value 'Production'
            $rule = New-Rule -Name 'TestRule' -Effect 'Allow' -Conditions $condition
            $rule | Should -BeOfType [Rule]
        }
    }
}
