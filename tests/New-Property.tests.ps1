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

Describe 'New-Property' {
    BeforeAll {
        # Import test helpers
        Import-Module -Name "$PSScriptRoot\Helpers\TestHelpers.psm1" -Force
    }

    Context 'Parameter validation' {
        It 'should require Name parameter' {
            { New-Property -Type 'string' -ErrorAction Stop } | Should -Throw
        }

        It 'should require Type parameter' {
            { New-Property -Name 'TestProp' -ErrorAction Stop } | Should -Throw
        }

        It 'should only accept valid types' {
            { New-Property -Name 'TestProp' -Type 'invalid' -ErrorAction Stop } | Should -Throw
        }

        It 'should accept string type' {
            { New-Property -Name 'TestProp' -Type 'string' -WhatIf } | Should -Not -Throw
        }

        It 'should accept integer type' {
            { New-Property -Name 'TestProp' -Type 'integer' -WhatIf } | Should -Not -Throw
        }

        It 'should accept boolean type' {
            { New-Property -Name 'TestProp' -Type 'boolean' -WhatIf } | Should -Not -Throw
        }
    }

    Context 'Basic property creation' {
        It 'should create a string property' {
            $property = New-Property -Name 'Environment' -Type 'string'
            $property | Should -Not -BeNullOrEmpty
            $property.Name | Should -Be 'Environment'
            $property.Type | Should -Be 'string'
        }

        It 'should create an integer property' {
            $property = New-Property -Name 'Count' -Type 'integer'
            $property | Should -Not -BeNullOrEmpty
            $property.Name | Should -Be 'Count'
            $property.Type | Should -Be 'integer'
        }

        It 'should create a boolean property' {
            $property = New-Property -Name 'IsEnabled' -Type 'boolean'
            $property | Should -Not -BeNullOrEmpty
            $property.Name | Should -Be 'IsEnabled'
            $property.Type | Should -Be 'boolean'
        }

        It 'should return PropertyDefinition type' {
            $property = New-Property -Name 'TestProp' -Type 'string'
            $property | Should -BeOfType [PropertyDefinition]
        }
    }

    Context 'Enum values' {
        It 'should accept enum values for string property' {
            $property = New-Property -Name 'Environment' -Type 'string' -EnumValues @('Dev', 'Prod')
            $property | Should -Not -BeNullOrEmpty
            $property.Enum | Should -Contain 'Dev'
            $property.Enum | Should -Contain 'Prod'
        }

        It 'should accept enum values for integer property' {
            $property = New-Property -Name 'Priority' -Type 'integer' -EnumValues @(1, 2, 3)
            $property | Should -Not -BeNullOrEmpty
            $property.Enum | Should -Contain 1
            $property.Enum | Should -Contain 2
            $property.Enum | Should -Contain 3
        }

        It 'should handle empty enum array' {
            $property = New-Property -Name 'TestProp' -Type 'string' -EnumValues @()
            $property | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Validation rules' {
        It 'should accept validation hashtable' {
            $validation = @{
                Pattern = '^[a-z]+$'
            }
            $property = New-Property -Name 'Username' -Type 'string' -Validation $validation
            $property | Should -Not -BeNullOrEmpty
            $property.Validation | Should -Not -BeNullOrEmpty
            $property.Validation.Pattern | Should -Be '^[a-z]+$'
        }

        It 'should accept minimum/maximum validation for integer' {
            $validation = @{
                Minimum = 0
                Maximum = 100
            }
            $property = New-Property -Name 'Percentage' -Type 'integer' -Validation $validation
            $property | Should -Not -BeNullOrEmpty
            $property.Validation.Minimum | Should -Be 0
            $property.Validation.Maximum | Should -Be 100
        }

        It 'should accept pattern validation for string' {
            $validation = @{
                Pattern = '^\d{3}-\d{2}-\d{4}$'
            }
            $property = New-Property -Name 'SSN' -Type 'string' -Validation $validation
            $property | Should -Not -BeNullOrEmpty
            $property.Validation.Pattern | Should -Be '^\d{3}-\d{2}-\d{4}$'
        }
    }

    Context 'Combined enum and validation' {
        It 'should accept both enum and validation' {
            $validation = @{
                Pattern = '^[A-Z][a-z]+$'
            }
            $property = New-Property -Name 'Environment' -Type 'string' -EnumValues @('Dev', 'Prod') -Validation $validation
            $property | Should -Not -BeNullOrEmpty
            $property.Enum | Should -Not -BeNullOrEmpty
            $property.Validation | Should -Not -BeNullOrEmpty
        }
    }

    Context 'ShouldProcess support' {
        It 'should support -WhatIf' {
            $result = New-Property -Name 'TestProp' -Type 'string' -WhatIf
            # With -WhatIf, the function should not create the property
            $result | Should -BeNullOrEmpty
        }

        It 'should create property without -WhatIf' {
            $result = New-Property -Name 'TestProp' -Type 'string'
            $result | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Edge cases' {
        It 'should handle property name with spaces' {
            $property = New-Property -Name 'Test Property' -Type 'string'
            $property.Name | Should -Be 'Test Property'
        }

        It 'should handle property name with special characters' {
            $property = New-Property -Name 'Test-Property_123' -Type 'string'
            $property.Name | Should -Be 'Test-Property_123'
        }

        It 'should handle long property names' {
            $longName = 'A' * 100
            $property = New-Property -Name $longName -Type 'string'
            $property.Name | Should -Be $longName
        }

        It 'should handle complex validation hashtables' {
            $validation = @{
                Pattern = '^[a-z]+$'
                MinLength = 5
                MaxLength = 20
                CustomRule = 'SomeValue'
            }
            $property = New-Property -Name 'TestProp' -Type 'string' -Validation $validation
            $property.Validation.Pattern | Should -Be '^[a-z]+$'
            $property.Validation.MinLength | Should -Be 5
            $property.Validation.MaxLength | Should -Be 20
            $property.Validation.CustomRule | Should -Be 'SomeValue'
        }
    }
}
