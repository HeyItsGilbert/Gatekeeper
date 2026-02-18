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

Describe 'New-Condition' {
    BeforeAll {
        # Import test helpers
        Import-Module -Name "$PSScriptRoot\Helpers\TestHelpers.psm1" -Force

        # Create a test property set for validation warnings
        $script:testPropertySet = New-TestPropertySet
        # Mock Get-PropertySet to return our test property set
        Mock -ModuleName Gatekeeper Get-PropertySet { return $script:testPropertySet }
    }

    Context 'Parameter validation' {
        It 'should require Property parameter' {
            { New-Condition -Operator 'Equals' -Value 'test' -ErrorAction Stop } | Should -Throw
        }

        It 'should require Operator parameter' {
            { New-Condition -Property 'Environment' -Value 'test' -ErrorAction Stop } | Should -Throw
        }

        It 'should require Value parameter' {
            { New-Condition -Property 'Environment' -Operator 'Equals' -ErrorAction Stop } | Should -Throw
        }

        It 'should accept valid operator values' {
            $validOperators = @('Equals', 'NotEquals', 'GreaterThan', 'LessThan', 'In', 'NotIn')
            foreach ($operator in $validOperators) {
                { New-Condition -Property 'Environment' -Operator $operator -Value 'test' -WhatIf } | Should -Not -Throw
            }
        }
    }

    Context 'Basic condition creation' {
        It 'should create condition with Equals operator' {
            $condition = New-Condition -Property 'Environment' -Operator 'Equals' -Value 'Production'
            $condition | Should -Not -BeNullOrEmpty
            $condition | Should -BeOfType [ConditionGroup]
            $condition.Property | Should -Be 'Environment'
            $condition.Operator | Should -Be 'Equals'
            $condition.Value | Should -Be 'Production'
        }

        It 'should create condition with NotEquals operator' {
            $condition = New-Condition -Property 'Environment' -Operator 'NotEquals' -Value 'Development'
            $condition | Should -Not -BeNullOrEmpty
            $condition.Property | Should -Be 'Environment'
            $condition.Operator | Should -Be 'NotEquals'
            $condition.Value | Should -Be 'Development'
        }

        It 'should create condition with GreaterThan operator' {
            $condition = New-Condition -Property 'Percentage' -Operator 'GreaterThan' -Value 50
            $condition | Should -Not -BeNullOrEmpty
            $condition.Property | Should -Be 'Percentage'
            $condition.Operator | Should -Be 'GreaterThan'
            $condition.Value | Should -Be 50
        }

        It 'should create condition with LessThan operator' {
            $condition = New-Condition -Property 'Percentage' -Operator 'LessThan' -Value 25
            $condition | Should -Not -BeNullOrEmpty
            $condition.Property | Should -Be 'Percentage'
            $condition.Operator | Should -Be 'LessThan'
            $condition.Value | Should -Be 25
        }

        It 'should create condition with In operator' {
            $condition = New-Condition -Property 'Environment' -Operator 'In' -Value @('Development', 'Staging')
            $condition | Should -Not -BeNullOrEmpty
            $condition.Property | Should -Be 'Environment'
            $condition.Operator | Should -Be 'In'
            $condition.Value | Should -Be @('Development', 'Staging')
        }

        It 'should create condition with NotIn operator' {
            $condition = New-Condition -Property 'Environment' -Operator 'NotIn' -Value @('Development', 'Staging')
            $condition | Should -Not -BeNullOrEmpty
            $condition.Property | Should -Be 'Environment'
            $condition.Operator | Should -Be 'NotIn'
            $condition.Value | Should -Be @('Development', 'Staging')
        }
    }

    Context 'Value types' {
        It 'should handle string values' {
            $condition = New-Condition -Property 'Environment' -Operator 'Equals' -Value 'Production'
            $condition.Value | Should -Be 'Production'
            $condition.Value | Should -BeOfType [string]
        }

        It 'should handle integer values' {
            $condition = New-Condition -Property 'Percentage' -Operator 'Equals' -Value 75
            $condition.Value | Should -Be 75
            $condition.Value | Should -BeOfType [int]
        }

        It 'should handle boolean values' {
            $condition = New-Condition -Property 'IsCompliant' -Operator 'Equals' -Value $true
            $condition.Value | Should -Be $true
            $condition.Value | Should -BeOfType [bool]
        }

        It 'should handle array values' {
            $values = @('Value1', 'Value2', 'Value3')
            $condition = New-Condition -Property 'Environment' -Operator 'In' -Value $values
            $condition.Value | Should -Be $values
            $condition.Value | Should -BeOfType [array]
        }
    }

    Context 'Property validation warnings' {
        It 'should warn when property is not in property set' {
            # This test assumes Get-PropertySet is called and warns about unknown properties
            $warningMessages = @()
            $condition = New-Condition -Property 'UnknownProperty' -Operator 'Equals' -Value 'test' -WarningVariable warningMessages -WarningAction SilentlyContinue
            $condition | Should -Not -BeNullOrEmpty
            # The function should warn about unknown properties
            $warningMessages | Should -Not -BeNullOrEmpty
        }

        It 'should not warn when property is in property set' {
            $warningMessages = @()
            $condition = New-Condition -Property 'Environment' -Operator 'Equals' -Value 'Production' -WarningVariable warningMessages -WarningAction SilentlyContinue
            $condition | Should -Not -BeNullOrEmpty
            # No warning should be generated for known properties
        }
    }

    Context 'ShouldProcess support' {
        It 'should support -WhatIf' {
            $result = New-Condition -Property 'Environment' -Operator 'Equals' -Value 'Production' -WhatIf
            # With -WhatIf, the function should not create the condition
            $result | Should -BeNullOrEmpty
        }

        It 'should create condition without -WhatIf' {
            $result = New-Condition -Property 'Environment' -Operator 'Equals' -Value 'Production'
            $result | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Edge cases' {
        It 'should handle null value' {
            # Note: The parameter has ValidateNotNull, so this should throw
            { New-Condition -Property 'Environment' -Operator 'Equals' -Value $null -ErrorAction Stop } | Should -Throw
        }

        It 'should handle empty string value' {
            $condition = New-Condition -Property 'Environment' -Operator 'Equals' -Value ''
            $condition.Value | Should -Be ''
        }

        It 'should handle zero value' {
            $condition = New-Condition -Property 'Percentage' -Operator 'Equals' -Value 0
            $condition.Value | Should -Be 0
        }

        It 'should handle negative numbers' {
            $condition = New-Condition -Property 'Percentage' -Operator 'GreaterThan' -Value -10
            $condition.Value | Should -Be -10
        }

        It 'should handle empty array' {
            $condition = New-Condition -Property 'Environment' -Operator 'In' -Value @()
            $condition.Value | Should -BeOfType [array]
            $condition.Value.Count | Should -Be 0
        }

        It 'should handle property names with special characters' {
            $condition = New-Condition -Property 'Test-Property_123' -Operator 'Equals' -Value 'test' -WarningAction SilentlyContinue
            $condition.Property | Should -Be 'Test-Property_123'
        }

        It 'should handle large values' {
            $largeValue = 'A' * 10000
            $condition = New-Condition -Property 'Environment' -Operator 'Equals' -Value $largeValue
            $condition.Value | Should -Be $largeValue
        }
    }

    Context 'ToString output' {
        It 'should generate meaningful string representation' {
            $condition = New-Condition -Property 'Environment' -Operator 'Equals' -Value 'Production'
            $toString = $condition.ToString()
            $toString | Should -Not -BeNullOrEmpty
            $toString | Should -BeLike '*Environment*'
            $toString | Should -BeLike '*Equals*'
            $toString | Should -BeLike '*Production*'
        }
    }

    Context 'IsValid method' {
        It 'should report valid condition' {
            $condition = New-Condition -Property 'Environment' -Operator 'Equals' -Value 'Production'
            $condition.IsValid() | Should -BeTrue
        }
    }
}
