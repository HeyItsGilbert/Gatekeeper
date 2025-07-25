# This test is to check that all the new file creation cmdlets are working as expected.
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
    }
}
