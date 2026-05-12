BeforeDiscovery {
    $manifest = Import-PowerShellDataFile -Path $env:BHPSModuleManifest
    $outputDir = Join-Path -Path $env:BHProjectPath -ChildPath 'Output'
    $outputModDir = Join-Path -Path $outputDir -ChildPath $env:BHProjectName
    $outputModVerDir = Join-Path -Path $outputModDir -ChildPath $manifest.ModuleVersion
    $outputModVerManifest = Join-Path -Path $outputModVerDir -ChildPath "$($env:BHProjectName).psd1"

    Get-Module $env:BHProjectName -All | Remove-Module -Force -ErrorAction Ignore
    Get-Module 'Configuration' -All | Remove-Module -Force -ErrorAction Ignore
    Import-Module -Name $outputModVerManifest -Verbose:$false -ErrorAction Stop
}

Describe 'Import-GatekeeperConfig' {
    BeforeAll {
        $script:minConfig = @{
            Version   = '0.1.0'
            FilePaths = @{ Schemas = '' }
            Security  = @{ AllowUncPaths = $false }
            Logging   = @{}
        }
    }

    AfterAll {
        # Restore real configuration so later test files see clean state
        Import-GatekeeperConfig -ForceReload
    }

    It 'returns a hashtable on cold load' {
        $result = Import-GatekeeperConfig -ForceReload
        $result | Should -Not -BeNullOrEmpty
        $result | Should -BeOfType [hashtable]
    }

    It 'uses cached config on second call without -ForceReload' {
        Mock -CommandName 'Import-Configuration' -ModuleName $env:BHProjectName { $script:minConfig }
        Import-GatekeeperConfig
        Should -Invoke 'Import-Configuration' -ModuleName $env:BHProjectName -Times 0
    }

    It '-ForceReload bypasses cache and calls Import-Configuration' {
        Mock -CommandName 'Import-Configuration' -ModuleName $env:BHProjectName { $script:minConfig }
        Import-GatekeeperConfig -ForceReload
        Should -Invoke 'Import-Configuration' -ModuleName $env:BHProjectName -Times 1
    }

    Context 'Logging configuration parsing' {
        BeforeAll {
            $testConfig = @{
                Version   = '0.1.0'
                FilePaths = @{ Schemas = '' }
                Security  = @{ AllowUncPaths = $false }
                Logging   = @{
                    Allow = @{ Enabled = $true; Script = { param($Rule) Write-Host 'allow' } }
                    Deny  = @{ Enabled = $true; Script = 'param($Rule); Write-Host "deny"' }
                    Audit = @{ Enabled = $false; Script = 'param($Rule); Write-Host "audit"' }
                }
            }
            Mock -CommandName 'Import-Configuration' -ModuleName $env:BHProjectName { $testConfig }
            Import-GatekeeperConfig -ForceReload
        }

        It 'parses an inline scriptblock for enabled logging level' {
            InModuleScope $env:BHProjectName {
                $script:GatekeeperLogging['Allow'] | Should -Not -BeNullOrEmpty
                $script:GatekeeperLogging['Allow'] | Should -BeOfType [scriptblock]
            }
        }

        It 'compiles a string script into a scriptblock for enabled logging level' {
            InModuleScope $env:BHProjectName {
                $script:GatekeeperLogging['Deny'] | Should -Not -BeNullOrEmpty
                $script:GatekeeperLogging['Deny'] | Should -BeOfType [scriptblock]
            }
        }

        It 'does not store disabled logging levels in GatekeeperLogging' {
            InModuleScope $env:BHProjectName {
                $script:GatekeeperLogging.ContainsKey('Audit') | Should -BeFalse
            }
        }
    }
}

Describe 'Get-FeatureFlagFolder' {
    BeforeAll {
        $script:ffFolder = Join-Path (Get-PSDrive TestDrive).Root 'FeatureFlags'
        New-Item -Path $script:ffFolder -ItemType Directory -Force | Out-Null
    }

    AfterEach {
        # Reset module config so each test starts clean
        InModuleScope $env:BHProjectName -Parameters @{ Folder = $script:ffFolder } {
            param($Folder)
            $script:GatekeeperConfiguration = @{
                FilePaths = @{ FeatureFlags = $Folder }
            }
        }
    }

    It 'returns the configured folder path' {
        InModuleScope $env:BHProjectName -Parameters @{ Folder = $script:ffFolder } {
            param($Folder)
            $script:GatekeeperConfiguration = @{
                FilePaths = @{ FeatureFlags = $Folder }
            }
        }
        $result = Get-FeatureFlagFolder
        $result | Should -Not -BeNullOrEmpty
        $result | Should -Be $script:ffFolder
    }

    It 'creates the folder and persists path on first run' {
        $script:firstRunRoot = Join-Path (Get-PSDrive TestDrive).Root 'FFFirstRunRoot'
        InModuleScope $env:BHProjectName {
            $script:GatekeeperConfiguration = @{ FilePaths = @{} }
        }
        Mock -CommandName 'Get-ConfigurationPath' -ModuleName $env:BHProjectName {
            $script:firstRunRoot
        }
        Mock -CommandName 'Export-GatekeeperConfig' -ModuleName $env:BHProjectName {}

        $result = Get-FeatureFlagFolder
        $result | Should -Not -BeNullOrEmpty
        Test-Path $result | Should -BeTrue
        Should -Invoke 'Export-GatekeeperConfig' -ModuleName $env:BHProjectName -Times 1
    }
}

Describe 'Get-PropertySetFolder' {
    BeforeAll {
        $script:psFolder = Join-Path (Get-PSDrive TestDrive).Root 'PropertySet'
        New-Item -Path $script:psFolder -ItemType Directory -Force | Out-Null
    }

    AfterEach {
        InModuleScope $env:BHProjectName -Parameters @{ Folder = $script:psFolder } {
            param($Folder)
            $script:GatekeeperConfiguration = @{
                FilePaths = @{ PropertySet = $Folder }
            }
        }
    }

    It 'returns the configured folder path' {
        InModuleScope $env:BHProjectName -Parameters @{ Folder = $script:psFolder } {
            param($Folder)
            $script:GatekeeperConfiguration = @{
                FilePaths = @{ PropertySet = $Folder }
            }
        }
        $result = Get-PropertySetFolder
        $result | Should -Not -BeNullOrEmpty
        $result | Should -Be $script:psFolder
    }

    It 'creates the folder and persists path on first run' {
        $script:psFirstRunRoot = Join-Path (Get-PSDrive TestDrive).Root 'PSFirstRunRoot'
        InModuleScope $env:BHProjectName {
            $script:GatekeeperConfiguration = @{ FilePaths = @{} }
        }
        Mock -CommandName 'Get-ConfigurationPath' -ModuleName $env:BHProjectName {
            $script:psFirstRunRoot
        }
        Mock -CommandName 'Export-GatekeeperConfig' -ModuleName $env:BHProjectName {}

        $result = Get-PropertySetFolder
        $result | Should -Not -BeNullOrEmpty
        Test-Path $result | Should -BeTrue
        Should -Invoke 'Export-GatekeeperConfig' -ModuleName $env:BHProjectName -Times 1
    }
}
