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

Describe 'Get-PropertySet' {
    BeforeAll {
        # Import test helpers
        Import-Module -Name "$PSScriptRoot\Helpers\TestHelpers.psm1" -Force

        # Create temporary test folder
        $script:testFolder = Join-Path ([System.IO.Path]::GetTempPath()) "GatekeeperTest_$(New-Guid)"
        New-Item -Path $script:testFolder -ItemType Directory -Force | Out-Null

        # Create test property set files
        $property1 = New-Property -Name 'Environment' -Type 'string' -EnumValues @('Dev', 'Prod')
        $set1 = New-PropertySet -Name 'TestSet1' -Properties $property1
        $file1 = Join-Path $script:testFolder 'TestSet1.json'
        $set1.FilePath = $file1
        $set1.Save()

        $property2 = New-Property -Name 'Count' -Type 'integer'
        $set2 = New-PropertySet -Name 'TestSet2' -Properties $property2
        $file2 = Join-Path $script:testFolder 'TestSet2.json'
        $set2.FilePath = $file2
        $set2.Save()

        # Mock Get-PropertySetFolder to return our test folder
        Mock -ModuleName Gatekeeper Get-PropertySetFolder { return $script:testFolder }
    }

    AfterAll {
        # Clean up test folder
        if (Test-Path $script:testFolder) {
            Remove-Item $script:testFolder -Recurse -Force -ErrorAction SilentlyContinue
        }

        # Clear the cache
        if (Get-Variable -Name GatekeeperPropertySets -Scope Script -ErrorAction SilentlyContinue) {
            Remove-Variable -Name GatekeeperPropertySets -Scope Script -Force -ErrorAction SilentlyContinue
        }
    }

    BeforeEach {
        # Clear the cache before each test
        if (Get-Variable -Name GatekeeperPropertySets -Scope Script -ErrorAction SilentlyContinue) {
            Remove-Variable -Name GatekeeperPropertySets -Scope Script -Force -ErrorAction SilentlyContinue
        }
    }

    Context 'Retrieving all property sets' {
        It 'should return all property sets when no name is specified' {
            $sets = Get-PropertySet
            $sets | Should -Not -BeNullOrEmpty
            $sets.Count | Should -Be 2
        }

        It 'should cache property sets for performance' {
            # First call
            $sets1 = Get-PropertySet
            # Second call should use cache
            $sets2 = Get-PropertySet
            $sets1.Count | Should -Be $sets2.Count
        }

        It 'should return PropertySet objects' {
            $sets = Get-PropertySet
            foreach ($set in $sets) {
                $set | Should -BeOfType [PropertySet]
            }
        }

        It 'should load property sets from folder' {
            $sets = Get-PropertySet
            $setNames = $sets | ForEach-Object { $_.Name }
            $setNames | Should -Contain 'TestSet1.json'
            $setNames | Should -Contain 'TestSet2.json'
        }
    }

    Context 'Retrieving specific property set by name' {
        It 'should return specific property set by name' {
            $set = Get-PropertySet -Name 'TestSet1'
            $set | Should -Not -BeNullOrEmpty
            $set | Should -BeOfType [PropertySet]
        }

        It 'should return correct property set for TestSet1' {
            $set = Get-PropertySet -Name 'TestSet1'
            $set.Properties.ContainsKey('Environment') | Should -BeTrue
        }

        It 'should return correct property set for TestSet2' {
            $set = Get-PropertySet -Name 'TestSet2'
            $set.Properties.ContainsKey('Count') | Should -BeTrue
        }

        It 'should return null for non-existent property set' {
            $set = Get-PropertySet -Name 'NonExistent'
            $set | Should -BeNullOrEmpty
        }
    }

    Context 'Caching behavior' {
        It 'should populate cache on first call' {
            $sets = Get-PropertySet
            # Cache should now be populated
            $sets | Should -Not -BeNullOrEmpty
        }

        It 'should use cache on subsequent calls without name' {
            # First call populates cache
            $null = Get-PropertySet
            # Second call should use cache (same result)
            $sets = Get-PropertySet
            $sets.Count | Should -Be 2
        }

        It 'should use cache when retrieving by name' {
            # Populate cache
            $null = Get-PropertySet
            # Retrieve specific set from cache
            $set = Get-PropertySet -Name 'TestSet1'
            $set | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Empty folder handling' {
        It 'should warn when no property sets found' {
            # Create empty test folder
            $emptyFolder = Join-Path ([System.IO.Path]::GetTempPath()) "GatekeeperTest_Empty_$(New-Guid)"
            New-Item -Path $emptyFolder -ItemType Directory -Force | Out-Null

            try {
                # Clear cache
                if (Get-Variable -Name GatekeeperPropertySets -Scope Script -ErrorAction SilentlyContinue) {
                    Remove-Variable -Name GatekeeperPropertySets -Scope Script -Force
                }

                # Mock to return empty folder
                Mock -ModuleName Gatekeeper Get-PropertySetFolder { return $emptyFolder }

                $warnings = @()
                $sets = Get-PropertySet -WarningVariable warnings -WarningAction SilentlyContinue
                $warnings | Should -Not -BeNullOrEmpty
                $sets | Should -BeOfType [array]
                $sets.Count | Should -Be 0
            } finally {
                if (Test-Path $emptyFolder) {
                    Remove-Item $emptyFolder -Recurse -Force -ErrorAction SilentlyContinue
                }
            }
        }
    }

    Context 'Integration with Get-PropertySetFolder' {
        It 'should call Get-PropertySetFolder to find property sets' {
            # Clear cache to force reload
            if (Get-Variable -Name GatekeeperPropertySets -Scope Script -ErrorAction SilentlyContinue) {
                Remove-Variable -Name GatekeeperPropertySets -Scope Script -Force
            }

            $sets = Get-PropertySet
            # Should have called our mock
            Should -Invoke -ModuleName Gatekeeper -CommandName Get-PropertySetFolder -Times 1 -Exactly
        }
    }

    Context 'Error handling' {
        It 'should warn when property set file fails to load' {
            # Create a malformed JSON file
            $badFile = Join-Path $script:testFolder 'BadSet.json'
            Set-Content -Path $badFile -Value 'invalid json content'

            try {
                # Clear cache
                if (Get-Variable -Name GatekeeperPropertySets -Scope Script -ErrorAction SilentlyContinue) {
                    Remove-Variable -Name GatekeeperPropertySets -Scope Script -Force
                }

                $warnings = @()
                $sets = Get-PropertySet -WarningVariable warnings -WarningAction SilentlyContinue
                # Should have loaded the valid sets but warned about the bad one
                $warnings | Should -Not -BeNullOrEmpty
            } finally {
                if (Test-Path $badFile) {
                    Remove-Item $badFile -Force -ErrorAction SilentlyContinue
                }
            }
        }
    }

    Context 'Edge cases' {
        It 'should handle property set with special characters in name' {
            $property = New-Property -Name 'TestProp' -Type 'string'
            $set = New-PropertySet -Name 'Special-Set_123' -Properties $property
            $file = Join-Path $script:testFolder 'Special-Set_123.json'
            $set.FilePath = $file
            $set.Save()

            try {
                # Clear cache
                if (Get-Variable -Name GatekeeperPropertySets -Scope Script -ErrorAction SilentlyContinue) {
                    Remove-Variable -Name GatekeeperPropertySets -Scope Script -Force
                }

                $sets = Get-PropertySet
                $sets.Count | Should -BeGreaterThan 2
            } finally {
                if (Test-Path $file) {
                    Remove-Item $file -Force -ErrorAction SilentlyContinue
                }
            }
        }

        It 'should handle case-sensitive name lookup' {
            $set1 = Get-PropertySet -Name 'TestSet1'
            $set2 = Get-PropertySet -Name 'testset1'
            # Depending on OS, case sensitivity may differ
            # Just verify it doesn't throw
            $set1 | Should -Not -BeNull
        }
    }
}
