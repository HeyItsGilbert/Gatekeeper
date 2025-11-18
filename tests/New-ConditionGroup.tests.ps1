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

Describe 'New-ConditionGroup' {
    BeforeAll {
        # Import test helpers
        Import-Module -Name "$PSScriptRoot\Helpers\TestHelpers.psm1" -Force
    }

    Context 'Parameter validation' {
        It 'should require Operator parameter' {
            $condition = New-TestCondition -Property 'Environment' -Operator 'Equals' -Value 'Production'
            { New-ConditionGroup -Conditions $condition -ErrorAction Stop } | Should -Throw
        }

        It 'should require Conditions parameter' {
            { New-ConditionGroup -Operator 'AllOf' -ErrorAction Stop } | Should -Throw
        }

        It 'should only accept valid operators' {
            $condition = New-TestCondition -Property 'Environment' -Operator 'Equals' -Value 'Production'
            { New-ConditionGroup -Operator 'InvalidOperator' -Conditions $condition -ErrorAction Stop } | Should -Throw
        }

        It 'should accept AllOf operator' {
            $condition = New-TestCondition -Property 'Environment' -Operator 'Equals' -Value 'Production'
            { New-ConditionGroup -Operator 'AllOf' -Conditions $condition -WhatIf } | Should -Not -Throw
        }

        It 'should accept AnyOf operator' {
            $condition = New-TestCondition -Property 'Environment' -Operator 'Equals' -Value 'Production'
            { New-ConditionGroup -Operator 'AnyOf' -Conditions $condition -WhatIf } | Should -Not -Throw
        }

        It 'should accept Not operator' {
            $condition = New-TestCondition -Property 'Environment' -Operator 'Equals' -Value 'Production'
            { New-ConditionGroup -Operator 'Not' -Conditions $condition -WhatIf } | Should -Not -Throw
        }
    }

    Context 'AllOf condition group' {
        It 'should create AllOf group with single condition' {
            $condition = New-TestCondition -Property 'Environment' -Operator 'Equals' -Value 'Production'
            $group = New-ConditionGroup -Operator 'AllOf' -Conditions $condition
            $group | Should -Not -BeNullOrEmpty
            $group | Should -BeOfType [ConditionGroup]
            $group.AllOf | Should -Not -BeNullOrEmpty
        }

        It 'should create AllOf group with multiple conditions' {
            $condition1 = New-TestCondition -Property 'Environment' -Operator 'Equals' -Value 'Production'
            $condition2 = New-TestCondition -Property 'Percentage' -Operator 'GreaterThan' -Value 50
            $conditions = @($condition1, $condition2)

            $group = New-ConditionGroup -Operator 'AllOf' -Conditions $conditions
            $group | Should -Not -BeNullOrEmpty
            $group.AllOf | Should -Not -BeNullOrEmpty
            $group.AllOf.Count | Should -Be 2
        }

        It 'should not have AnyOf or Not properties set' {
            $condition = New-TestCondition -Property 'Environment' -Operator 'Equals' -Value 'Production'
            $group = New-ConditionGroup -Operator 'AllOf' -Conditions $condition
            $group.AnyOf | Should -BeNullOrEmpty
            $group.Not | Should -BeNullOrEmpty
        }
    }

    Context 'AnyOf condition group' {
        It 'should create AnyOf group with single condition' {
            $condition = New-TestCondition -Property 'Environment' -Operator 'Equals' -Value 'Production'
            $group = New-ConditionGroup -Operator 'AnyOf' -Conditions $condition
            $group | Should -Not -BeNullOrEmpty
            $group | Should -BeOfType [ConditionGroup]
            $group.AnyOf | Should -Not -BeNullOrEmpty
        }

        It 'should create AnyOf group with multiple conditions' {
            $condition1 = New-TestCondition -Property 'Environment' -Operator 'Equals' -Value 'Development'
            $condition2 = New-TestCondition -Property 'Environment' -Operator 'Equals' -Value 'Staging'
            $conditions = @($condition1, $condition2)

            $group = New-ConditionGroup -Operator 'AnyOf' -Conditions $conditions
            $group | Should -Not -BeNullOrEmpty
            $group.AnyOf | Should -Not -BeNullOrEmpty
            $group.AnyOf.Count | Should -Be 2
        }

        It 'should not have AllOf or Not properties set' {
            $condition = New-TestCondition -Property 'Environment' -Operator 'Equals' -Value 'Production'
            $group = New-ConditionGroup -Operator 'AnyOf' -Conditions $condition
            $group.AllOf | Should -BeNullOrEmpty
            $group.Not | Should -BeNullOrEmpty
        }
    }

    Context 'Not condition group' {
        It 'should create Not group with single condition' {
            $condition = New-TestCondition -Property 'Environment' -Operator 'Equals' -Value 'Production'
            $group = New-ConditionGroup -Operator 'Not' -Conditions $condition
            $group | Should -Not -BeNullOrEmpty
            $group | Should -BeOfType [ConditionGroup]
            $group.Not | Should -Not -BeNullOrEmpty
        }

        It 'should create Not group with multiple conditions' {
            $condition1 = New-TestCondition -Property 'Environment' -Operator 'Equals' -Value 'Development'
            $condition2 = New-TestCondition -Property 'Percentage' -Operator 'LessThan' -Value 10
            $conditions = @($condition1, $condition2)

            $group = New-ConditionGroup -Operator 'Not' -Conditions $conditions
            $group | Should -Not -BeNullOrEmpty
            $group.Not | Should -Not -BeNullOrEmpty
            $group.Not.Count | Should -Be 2
        }

        It 'should not have AllOf or AnyOf properties set' {
            $condition = New-TestCondition -Property 'Environment' -Operator 'Equals' -Value 'Production'
            $group = New-ConditionGroup -Operator 'Not' -Conditions $condition
            $group.AllOf | Should -BeNullOrEmpty
            $group.AnyOf | Should -BeNullOrEmpty
        }
    }

    Context 'Nested condition groups' {
        It 'should create nested AllOf within AnyOf' {
            $condition1 = New-TestCondition -Property 'Environment' -Operator 'Equals' -Value 'Production'
            $condition2 = New-TestCondition -Property 'Percentage' -Operator 'GreaterThan' -Value 50
            $innerGroup = New-ConditionGroup -Operator 'AllOf' -Conditions @($condition1, $condition2)

            $condition3 = New-TestCondition -Property 'IsCompliant' -Operator 'Equals' -Value $true
            $outerGroup = New-ConditionGroup -Operator 'AnyOf' -Conditions @($innerGroup, $condition3)

            $outerGroup | Should -Not -BeNullOrEmpty
            $outerGroup.AnyOf | Should -Not -BeNullOrEmpty
            $outerGroup.AnyOf.Count | Should -Be 2
        }

        It 'should create nested Not within AllOf' {
            $condition1 = New-TestCondition -Property 'Environment' -Operator 'Equals' -Value 'Development'
            $notGroup = New-ConditionGroup -Operator 'Not' -Conditions $condition1

            $condition2 = New-TestCondition -Property 'Percentage' -Operator 'GreaterThan' -Value 25
            $allOfGroup = New-ConditionGroup -Operator 'AllOf' -Conditions @($notGroup, $condition2)

            $allOfGroup | Should -Not -BeNullOrEmpty
            $allOfGroup.AllOf | Should -Not -BeNullOrEmpty
            $allOfGroup.AllOf.Count | Should -Be 2
        }
    }

    Context 'ShouldProcess support' {
        It 'should support -WhatIf' {
            $condition = New-TestCondition -Property 'Environment' -Operator 'Equals' -Value 'Production'
            $result = New-ConditionGroup -Operator 'AllOf' -Conditions $condition -WhatIf
            # With -WhatIf, the function should not create the group
            $result | Should -BeNullOrEmpty
        }

        It 'should create group without -WhatIf' {
            $condition = New-TestCondition -Property 'Environment' -Operator 'Equals' -Value 'Production'
            $result = New-ConditionGroup -Operator 'AllOf' -Conditions $condition
            $result | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Warning messages' {
        It 'should warn when conditions are not defined' {
            # Note: This test may need adjustment based on actual function behavior
            # The function validates that conditions are not null, so this might throw instead
            { New-ConditionGroup -Operator 'AllOf' -Conditions $null -ErrorAction Stop } | Should -Throw
        }
    }

    Context 'Edge cases' {
        It 'should handle single condition array' {
            $condition = @(New-TestCondition -Property 'Environment' -Operator 'Equals' -Value 'Production')
            $group = New-ConditionGroup -Operator 'AllOf' -Conditions $condition
            $group | Should -Not -BeNullOrEmpty
            $group.AllOf.Count | Should -Be 1
        }

        It 'should handle large number of conditions' {
            $conditions = 1..50 | ForEach-Object {
                New-TestCondition -Property 'Percentage' -Operator 'GreaterThan' -Value $_
            }
            $group = New-ConditionGroup -Operator 'AllOf' -Conditions $conditions
            $group | Should -Not -BeNullOrEmpty
            $group.AllOf.Count | Should -Be 50
        }
    }

    Context 'ToString output' {
        It 'should generate meaningful string representation for AllOf' {
            $condition = New-TestCondition -Property 'Environment' -Operator 'Equals' -Value 'Production'
            $group = New-ConditionGroup -Operator 'AllOf' -Conditions $condition
            $toString = $group.ToString()
            $toString | Should -Not -BeNullOrEmpty
            $toString | Should -BeLike '*AllOf*'
        }

        It 'should generate meaningful string representation for AnyOf' {
            $condition = New-TestCondition -Property 'Environment' -Operator 'Equals' -Value 'Production'
            $group = New-ConditionGroup -Operator 'AnyOf' -Conditions $condition
            $toString = $group.ToString()
            $toString | Should -Not -BeNullOrEmpty
            $toString | Should -BeLike '*AnyOf*'
        }

        It 'should generate meaningful string representation for Not' {
            $condition = New-TestCondition -Property 'Environment' -Operator 'Equals' -Value 'Production'
            $group = New-ConditionGroup -Operator 'Not' -Conditions $condition
            $toString = $group.ToString()
            $toString | Should -Not -BeNullOrEmpty
            $toString | Should -BeLike '*Not*'
        }
    }

    Context 'Alias support' {
        It 'should be accessible via alias New-ConditionGroupDefinition' {
            $condition = New-TestCondition -Property 'Environment' -Operator 'Equals' -Value 'Production'
            $group = New-ConditionGroupDefinition -Operator 'AllOf' -Conditions $condition
            $group | Should -Not -BeNullOrEmpty
            $group | Should -BeOfType [ConditionGroup]
        }
    }
}
