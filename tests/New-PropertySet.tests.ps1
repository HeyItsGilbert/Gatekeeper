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

Describe 'New-PropertySet' {
    BeforeAll {
        # Import test helpers
        Import-Module -Name "$PSScriptRoot\Helpers\TestHelpers.psm1" -Force
    }

    Context 'Basic property set creation' {
        It 'should create an empty property set' {
            $set = New-PropertySet -Name 'TestSet'
            $set | Should -Not -BeNullOrEmpty
            $set | Should -BeOfType [PropertySet]
            $set.Name | Should -Be 'TestSet'
        }

        It 'should create property set with a single property' {
            $property = New-Property -Name 'Environment' -Type 'string'
            $set = New-PropertySet -Name 'TestSet' -Properties $property
            $set | Should -Not -BeNullOrEmpty
            $set.Properties.Count | Should -Be 1
            $set.Properties['Environment'] | Should -Not -BeNullOrEmpty
        }

        It 'should create property set with multiple properties' {
            $properties = @(
                (New-Property -Name 'Environment' -Type 'string'),
                (New-Property -Name 'Count' -Type 'integer'),
                (New-Property -Name 'IsEnabled' -Type 'boolean')
            )
            $set = New-PropertySet -Name 'TestSet' -Properties $properties
            $set | Should -Not -BeNullOrEmpty
            $set.Properties.Count | Should -Be 3
            $set.Properties['Environment'] | Should -Not -BeNullOrEmpty
            $set.Properties['Count'] | Should -Not -BeNullOrEmpty
            $set.Properties['IsEnabled'] | Should -Not -BeNullOrEmpty
        }

        It 'should set FilePath property' {
            $set = New-PropertySet -Name 'TestSet'
            $set.FilePath | Should -Not -BeNullOrEmpty
            $set.FilePath | Should -BeLike '*TestSet.json'
        }
    }

    Context 'Pipeline support' {
        It 'should accept properties via pipeline' {
            $property1 = New-Property -Name 'Prop1' -Type 'string'
            $property2 = New-Property -Name 'Prop2' -Type 'integer'

            $set = $property1, $property2 | New-PropertySet -Name 'PipelineTest'
            $set | Should -Not -BeNullOrEmpty
            $set.Properties.Count | Should -Be 2
            $set.Properties['Prop1'] | Should -Not -BeNullOrEmpty
            $set.Properties['Prop2'] | Should -Not -BeNullOrEmpty
        }

        It 'should handle multiple pipeline calls' {
            $properties = 1..5 | ForEach-Object {
                New-Property -Name "Prop$_" -Type 'string'
            }

            $set = $properties | New-PropertySet -Name 'MultiPipelineTest'
            $set | Should -Not -BeNullOrEmpty
            $set.Properties.Count | Should -Be 5
        }
    }

    Context 'ShouldProcess support' {
        It 'should support -WhatIf' {
            $property = New-Property -Name 'TestProp' -Type 'string'
            # With -WhatIf, properties should not be added
            $set = New-PropertySet -Name 'TestSet' -Properties $property -WhatIf
            # The set should be created but properties not added
            if ($set) {
                $set.Properties.Count | Should -Be 0
            }
        }

        It 'should add properties without -WhatIf' {
            $property = New-Property -Name 'TestProp' -Type 'string'
            $set = New-PropertySet -Name 'TestSet' -Properties $property
            $set.Properties.Count | Should -Be 1
        }
    }

    Context 'Property organization' {
        It 'should store properties by name' {
            $property = New-Property -Name 'MyProperty' -Type 'string'
            $set = New-PropertySet -Name 'TestSet' -Properties $property
            $set.Properties.Keys | Should -Contain 'MyProperty'
        }

        It 'should handle duplicate property names by overwriting' {
            $property1 = New-Property -Name 'Duplicate' -Type 'string'
            $property2 = New-Property -Name 'Duplicate' -Type 'integer'

            $set = New-PropertySet -Name 'TestSet' -Properties @($property1, $property2)
            $set.Properties.Count | Should -Be 1
            # The last property should win
            $set.Properties['Duplicate'].Type | Should -Be 'integer'
        }
    }

    Context 'Integration with Get-PropertySetFolder' {
        It 'should use Get-PropertySetFolder for FilePath' {
            $expectedFolder = Get-PropertySetFolder
            $set = New-PropertySet -Name 'TestSet'
            $set.FilePath | Should -BeLike "$expectedFolder*"
        }

        It 'should construct correct file path' {
            $set = New-PropertySet -Name 'MyCustomSet'
            $set.FilePath | Should -Match 'MyCustomSet\.json$'
        }
    }

    Context 'Edge cases' {
        It 'should handle empty property array' {
            $set = New-PropertySet -Name 'EmptySet' -Properties @()
            $set | Should -Not -BeNullOrEmpty
            $set.Properties.Count | Should -Be 0
        }

        It 'should handle null name' {
            $set = New-PropertySet -Name $null
            $set | Should -Not -BeNullOrEmpty
            # PropertySet class should handle null name
        }

        It 'should handle empty string name' {
            $set = New-PropertySet -Name ''
            $set | Should -Not -BeNullOrEmpty
        }

        It 'should handle special characters in name' {
            $set = New-PropertySet -Name 'Test-Set_123'
            $set.Name | Should -Be 'Test-Set_123'
            $set.FilePath | Should -BeLike '*Test-Set_123.json'
        }

        It 'should handle large number of properties' {
            $properties = 1..100 | ForEach-Object {
                New-Property -Name "Property$_" -Type 'string'
            }
            $set = New-PropertySet -Name 'LargeSet' -Properties $properties
            $set.Properties.Count | Should -Be 100
        }
    }

    Context 'Property set structure' {
        It 'should have expected properties' {
            $set = New-PropertySet -Name 'TestSet'
            $set.Name | Should -Not -BeNullOrEmpty
            $set.Properties | Should -Not -BeNullOrEmpty
            $set.FilePath | Should -Not -BeNullOrEmpty
        }

        It 'should have Properties as hashtable or dictionary' {
            $set = New-PropertySet -Name 'TestSet'
            $set.Properties | Should -BeOfType [System.Collections.Hashtable] -Or
            $set.Properties.GetType().Name | Should -Match 'Dictionary'
        }
    }
}
