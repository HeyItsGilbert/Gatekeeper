# This test is to check that all the new file creation cmdlets are working as expected.
BeforeDiscovery {
    $manifest = Import-PowerShellDataFile -Path $env:BHPSModuleManifest
    $outputDir = Join-Path -Path $env:BHProjectPath -ChildPath 'Output'
    $outputModDir = Join-Path -Path $outputDir -ChildPath $env:BHProjectName
    $outputModVerDir = Join-Path -Path $outputModDir -ChildPath $manifest.ModuleVersion
    $outputModVerManifest = Join-Path -Path $outputModVerDir -ChildPath "$($env:BHProjectName).psd1"

    # Get module commands
    # Remove all versions of the module from the session. Pester can't handle multiple versions.
    Get-Module $env:BHProjectName -All | Remove-Module -Force -ErrorAction Ignore
    Get-Module 'Configuration' -All | Remove-Module -Force -ErrorAction Ignore
    Import-Module -Name $outputModVerManifest -Verbose:$false -ErrorAction Stop
    function global:GetFullPath {
        param(
            [string] $Path
        )
        return $Path.Replace('TestDrive:', (Get-PSDrive TestDrive).Root)
    }
}
Describe 'File Creations' {
    BeforeAll {
        @(
            'PropertySet',
            'FeatureFlags',
            'Configuration'
        ) | ForEach-Object {
            $folder = Join-Path -Path (Get-PSDrive TestDrive).Root -ChildPath $_
            if (-not (Test-Path -Path $folder)) {
                New-Item -Path $folder -ItemType Directory | Out-Null
            }
        }
        Mock -CommandName 'Get-PropertySetFolder' -ModuleName $env:BHProjectName {
            return (Join-Path -Path (Get-PSDrive TestDrive).Root -ChildPath 'PropertySet')
        }
        Mock -CommandName 'Get-FeatureFlagFolder' -ModuleName $env:BHProjectName {
            return (Join-Path -Path (Get-PSDrive TestDrive).Root -ChildPath 'FeatureFlags')
        }
        Mock -CommandName 'Get-ConfigurationPath' -ModuleName Configuration {
            return (Join-Path -Path (Get-PSDrive TestDrive).Root -ChildPath 'Configuration')
        }
        # Override the default file path for testing
        $global:GatekeeperConfiguration = @{
            FilePaths = @{
                #Schemas          = Join-Path (Get-PSDrive TestDrive).Root 'Schemas'
                FeatureFlags = Join-Path (Get-PSDrive TestDrive).Root 'FeatureFlags'
                PropertySet  = Join-Path (Get-PSDrive TestDrive).Root 'PropertySet'
            }
        }
    }
    # I'm doing a no-no IMO, but this is probably fine.
    It 'can create a condition' {
        $condition = New-Condition -Property 'UserRole' -Operator 'Equals' -Value 'Admin'
        $condition | Should -BeOfType ConditionGroup
    }

    It 'can create a rule' {
        $condition = New-Condition -Property 'UserRole' -Operator 'Equals' -Value 'Admin'
        $rule = New-Rule -Name 'AdminAccessRule' -Description 'Rule for admin access' -Effect Allow -Conditions $condition
        $rule | Should -BeOfType Rule
    }

    Context 'Feature Flag Creation' {
        BeforeAll {
            # Mock the Get-FeatureFlagFolder to return a test path
            Mock Get-FeatureFlagFolder -ModuleName $env:BHProjectName {
                return (Get-PSDrive TestDrive).Root
            }
            $condition = New-Condition -Property 'UserRole' -Operator 'Equals' -Value 'Admin'
            $rule = New-Rule -Name 'AdminAccessRule' -Description 'Rule for admin access' -Effect Allow -Conditions $condition
            $script:featureFlag = New-FeatureFlag -Name 'AdminFeature' -Description 'Feature for admin users' -DefaultEffect Allow -Rules $rule
        }
        It 'can create a feature flag' {
            $script:featureFlag | Should -BeOfType FeatureFlag
            $script:featureFlag.Name | Should -Be 'AdminFeature'
        }

        It 'can save the feature flag to a file' {
            $script:featureFlag | Save-FeatureFlag
            $filePath = $script:featureFlag.FilePath
            Test-Path $filePath | Should -BeTrue
        }

        It 'round-trips: saved feature flag can be read back with correct values' {
            $filePath = $script:featureFlag.FilePath
            $loaded = Read-FeatureFlag -FilePath $filePath
            $loaded | Should -BeOfType FeatureFlag
            $loaded.Name | Should -Be $script:featureFlag.Name
            $loaded.DefaultEffect | Should -Be $script:featureFlag.DefaultEffect
        }
    }

    Context 'New-Property' {
        It 'returns a PropertyDefinition object' {
            $result = New-Property -Name 'TestProp' -Type 'string'
            $result | Should -BeOfType PropertyDefinition
        }

        It 'populates Name and Type fields' {
            $result = New-Property -Name 'Count' -Type 'integer'
            $result.Name | Should -Be 'Count'
            $result.Type | Should -Be 'integer'
        }

        It 'populates Validation when provided' {
            $result = New-Property -Name 'Score' -Type 'integer' -Validation @{ Minimum = 0; Maximum = 100 }
            $result.Validation | Should -Not -BeNullOrEmpty
            $result.Validation.Minimum | Should -Be 0
            $result.Validation.Maximum | Should -Be 100
        }

        It 'populates Enum values when provided' {
            $result = New-Property -Name 'Env' -Type 'string' -EnumValues @('Prod', 'Staging', 'Dev')
            $result.Enum | Should -HaveCount 3
            $result.Enum | Should -Contain 'Prod'
        }
    }

    Context 'New-PropertySet' {
        It 'returns a PropertySet object' {
            $result = New-PropertySet -Name 'TestSet'
            $result | Should -BeOfType PropertySet
        }

        It 'includes piped properties in the set' {
            $p1 = New-Property -Name 'Host' -Type 'string'
            $p2 = New-Property -Name 'Port' -Type 'integer'
            $result = $p1, $p2 | New-PropertySet -Name 'Network'
            $result.Properties.ContainsKey('Host') | Should -BeTrue
            $result.Properties.ContainsKey('Port') | Should -BeTrue
        }
    }

    Context 'Save-PropertySet' {
        BeforeAll {
            $p = New-Property -Name 'Region' -Type 'string'
            $script:savedSet = $p | New-PropertySet -Name 'SaveTest'
            $script:savedPath = Join-Path -Path (Join-Path -Path (Get-PSDrive TestDrive).Root -ChildPath 'PropertySet') -ChildPath 'SaveTest.json'
        }

        It 'creates the file at the expected path' {
            Save-PropertySet -PropertySet $script:savedSet -FilePath $script:savedPath
            Test-Path $script:savedPath | Should -BeTrue
        }

        It 'round-trips: saved PropertySet can be read back with correct properties' {
            $loaded = Read-PropertySet -FilePath $script:savedPath
            $loaded | Should -BeOfType PropertySet
            $loaded.Properties.ContainsKey('Region') | Should -BeTrue
            $loaded.Properties['Region'].Type | Should -Be 'string'
        }
    }
}
