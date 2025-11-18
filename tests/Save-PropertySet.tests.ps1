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

Describe 'Save-PropertySet' {
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
        It 'should require PropertySet parameter' {
            { Save-PropertySet -ErrorAction Stop } | Should -Throw
        }

        It 'should accept PropertySet object' {
            $set = New-TestPropertySet
            $testFile = Get-TestFilePath
            { Save-PropertySet -PropertySet $set -FilePath $testFile } | Should -Not -Throw
        }
    }

    Context 'Saving with explicit FilePath' {
        It 'should save to specified file path' {
            $set = New-TestPropertySet
            $testFile = Get-TestFilePath

            Save-PropertySet -PropertySet $set -FilePath $testFile
            Test-Path $testFile | Should -BeTrue
        }

        It 'should create parent directory if it does not exist' {
            $set = New-TestPropertySet
            $tempPath = Join-Path ([System.IO.Path]::GetTempPath()) "GatekeeperTest_$(New-Guid)"
            $testFile = Join-Path $tempPath 'test.json'

            try {
                Save-PropertySet -PropertySet $set -FilePath $testFile
                Test-Path $testFile | Should -BeTrue
                Test-Path $tempPath | Should -BeTrue
            } finally {
                if (Test-Path $tempPath) {
                    Remove-Item $tempPath -Recurse -Force -ErrorAction SilentlyContinue
                }
            }
        }

        It 'should update PropertySet FilePath property' {
            $set = New-TestPropertySet
            $testFile = Get-TestFilePath

            Save-PropertySet -PropertySet $set -FilePath $testFile
            $set.FilePath | Should -Be $testFile
        }

        It 'should save valid JSON' {
            $set = New-TestPropertySet
            $testFile = Get-TestFilePath

            Save-PropertySet -PropertySet $set -FilePath $testFile
            { Get-Content $testFile -Raw | ConvertFrom-Json } | Should -Not -Throw
        }
    }

    Context 'Saving with default FilePath' {
        It 'should use PropertySet existing FilePath when not specified' {
            $set = New-TestPropertySet
            $testFile = Get-TestFilePath
            $set.FilePath = $testFile

            Save-PropertySet -PropertySet $set
            Test-Path $testFile | Should -BeTrue
        }

        It 'should throw when PropertySet has no FilePath' {
            $set = [PropertySet]::new('TestSet')
            $set.FilePath = $null

            { Save-PropertySet -PropertySet $set -ErrorAction Stop } | Should -Throw
        }
    }

    Context 'Pipeline support' {
        It 'should accept PropertySet via pipeline' {
            $set = New-TestPropertySet
            $testFile = Get-TestFilePath

            { $set | Save-PropertySet -FilePath $testFile } | Should -Not -Throw
            Test-Path $testFile | Should -BeTrue
        }

        It 'should save multiple PropertySets via pipeline' {
            $set1 = New-TestPropertySet
            $set2 = New-TestPropertySet

            $testFile1 = Get-TestFilePath
            $testFile2 = Get-TestFilePath

            $set1.FilePath = $testFile1
            $set2.FilePath = $testFile2

            $set1, $set2 | Save-PropertySet

            Test-Path $testFile1 | Should -BeTrue
            Test-Path $testFile2 | Should -BeTrue
        }
    }

    Context 'Content validation' {
        It 'should save properties correctly' {
            $property = New-Property -Name 'TestProp' -Type 'string'
            $set = New-PropertySet -Name 'TestSet' -Properties $property
            $testFile = Get-TestFilePath

            Save-PropertySet -PropertySet $set -FilePath $testFile
            $json = Get-Content $testFile -Raw | ConvertFrom-Json -AsHashtable
            $json.ContainsKey('TestProp') | Should -BeTrue
            $json['TestProp'].Type | Should -Be 'string'
        }

        It 'should save property with enum values' {
            $property = New-Property -Name 'Environment' -Type 'string' -EnumValues @('Dev', 'Prod')
            $set = New-PropertySet -Name 'TestSet' -Properties $property
            $testFile = Get-TestFilePath

            Save-PropertySet -PropertySet $set -FilePath $testFile
            $json = Get-Content $testFile -Raw | ConvertFrom-Json -AsHashtable
            $json['Environment'].Enum | Should -Contain 'Dev'
            $json['Environment'].Enum | Should -Contain 'Prod'
        }

        It 'should save property with validation rules' {
            $validation = @{
                Pattern = '^[a-z]+$'
            }
            $property = New-Property -Name 'Username' -Type 'string' -Validation $validation
            $set = New-PropertySet -Name 'TestSet' -Properties $property
            $testFile = Get-TestFilePath

            Save-PropertySet -PropertySet $set -FilePath $testFile
            $json = Get-Content $testFile -Raw | ConvertFrom-Json -AsHashtable
            $json['Username'].Validation.Pattern | Should -Be '^[a-z]+$'
        }

        It 'should include schema reference' {
            $set = New-TestPropertySet
            $testFile = Get-TestFilePath

            Save-PropertySet -PropertySet $set -FilePath $testFile
            $json = Get-Content $testFile -Raw | ConvertFrom-Json -AsHashtable
            $json.'$schema' | Should -Not -BeNullOrEmpty
        }

        It 'should save multiple properties' {
            $properties = @(
                (New-Property -Name 'Prop1' -Type 'string'),
                (New-Property -Name 'Prop2' -Type 'integer'),
                (New-Property -Name 'Prop3' -Type 'boolean')
            )
            $set = New-PropertySet -Name 'TestSet' -Properties $properties
            $testFile = Get-TestFilePath

            Save-PropertySet -PropertySet $set -FilePath $testFile
            $json = Get-Content $testFile -Raw | ConvertFrom-Json -AsHashtable
            $json.ContainsKey('Prop1') | Should -BeTrue
            $json.ContainsKey('Prop2') | Should -BeTrue
            $json.ContainsKey('Prop3') | Should -BeTrue
        }
    }

    Context 'Round-trip serialization' {
        It 'should allow reading back saved property set' {
            $originalSet = New-TestPropertySet
            $testFile = Get-TestFilePath

            Save-PropertySet -PropertySet $originalSet -FilePath $testFile
            $loadedSet = [PropertySet]::FromFile($testFile)

            $loadedSet.Properties.Count | Should -Be $originalSet.Properties.Count
            foreach ($key in $originalSet.Properties.Keys) {
                $loadedSet.Properties.ContainsKey($key) | Should -BeTrue
            }
        }

        It 'should preserve property types' {
            $properties = @(
                (New-Property -Name 'StringProp' -Type 'string'),
                (New-Property -Name 'IntProp' -Type 'integer'),
                (New-Property -Name 'BoolProp' -Type 'boolean')
            )
            $set = New-PropertySet -Name 'TestSet' -Properties $properties
            $testFile = Get-TestFilePath

            Save-PropertySet -PropertySet $set -FilePath $testFile
            $loadedSet = [PropertySet]::FromFile($testFile)

            $loadedSet.Properties['StringProp'].Type | Should -Be 'string'
            $loadedSet.Properties['IntProp'].Type | Should -Be 'integer'
            $loadedSet.Properties['BoolProp'].Type | Should -Be 'boolean'
        }

        It 'should preserve validation rules' {
            $validation = @{
                Minimum = 0
                Maximum = 100
            }
            $property = New-Property -Name 'Percentage' -Type 'integer' -Validation $validation
            $set = New-PropertySet -Name 'TestSet' -Properties $property
            $testFile = Get-TestFilePath

            Save-PropertySet -PropertySet $set -FilePath $testFile
            $loadedSet = [PropertySet]::FromFile($testFile)

            $loadedSet.Properties['Percentage'].Validation.Minimum | Should -Be 0
            $loadedSet.Properties['Percentage'].Validation.Maximum | Should -Be 100
        }
    }

    Context 'Overwriting existing files' {
        It 'should overwrite existing file' {
            $property1 = New-Property -Name 'OriginalProp' -Type 'string'
            $set1 = New-PropertySet -Name 'TestSet' -Properties $property1
            $testFile = Get-TestFilePath

            Save-PropertySet -PropertySet $set1 -FilePath $testFile
            $originalContent = Get-Content $testFile -Raw

            $property2 = New-Property -Name 'UpdatedProp' -Type 'string'
            $set2 = New-PropertySet -Name 'TestSet' -Properties $property2
            Save-PropertySet -PropertySet $set2 -FilePath $testFile
            $updatedContent = Get-Content $testFile -Raw

            $updatedContent | Should -Not -Be $originalContent
            $json = $updatedContent | ConvertFrom-Json -AsHashtable
            $json.ContainsKey('UpdatedProp') | Should -BeTrue
            $json.ContainsKey('OriginalProp') | Should -BeFalse
        }
    }

    Context 'Edge cases' {
        It 'should handle empty property set' {
            $set = [PropertySet]::new('EmptySet')
            $testFile = Get-TestFilePath
            $set.FilePath = $testFile

            Save-PropertySet -PropertySet $set
            $json = Get-Content $testFile -Raw | ConvertFrom-Json -AsHashtable
            $json.Keys.Count | Should -Be 1  # Only $schema key
        }

        It 'should handle large number of properties' {
            $properties = 1..100 | ForEach-Object {
                New-Property -Name "Property$_" -Type 'string'
            }
            $set = New-PropertySet -Name 'LargeSet' -Properties $properties
            $testFile = Get-TestFilePath

            Save-PropertySet -PropertySet $set -FilePath $testFile
            $json = Get-Content $testFile -Raw | ConvertFrom-Json -AsHashtable
            ($json.Keys | Where-Object { $_ -ne '$schema' }).Count | Should -Be 100
        }

        It 'should handle complex validation rules' {
            $validation = @{
                Pattern = '^\d{3}-\d{2}-\d{4}$'
                MinLength = 11
                MaxLength = 11
            }
            $property = New-Property -Name 'SSN' -Type 'string' -Validation $validation
            $set = New-PropertySet -Name 'TestSet' -Properties $property
            $testFile = Get-TestFilePath

            Save-PropertySet -PropertySet $set -FilePath $testFile
            $json = Get-Content $testFile -Raw | ConvertFrom-Json -AsHashtable
            $json['SSN'].Validation.Pattern | Should -Be '^\d{3}-\d{2}-\d{4}$'
            $json['SSN'].Validation.MinLength | Should -Be 11
            $json['SSN'].Validation.MaxLength | Should -Be 11
        }

        It 'should handle special characters in property names' {
            $property = New-Property -Name 'Test-Property_123' -Type 'string'
            $set = New-PropertySet -Name 'TestSet' -Properties $property
            $testFile = Get-TestFilePath

            Save-PropertySet -PropertySet $set -FilePath $testFile
            $json = Get-Content $testFile -Raw | ConvertFrom-Json -AsHashtable
            $json.ContainsKey('Test-Property_123') | Should -BeTrue
        }
    }
}
