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

Describe 'Import-GatekeeperConfig' {
    BeforeEach {
        # Clear the script-level configuration before each test
        if (Get-Variable -Name GatekeeperConfiguration -Scope Script -ErrorAction SilentlyContinue) {
            Remove-Variable -Name GatekeeperConfiguration -Scope Script -Force
        }
        if (Get-Variable -Name GatekeeperLogging -Scope Script -ErrorAction SilentlyContinue) {
            Remove-Variable -Name GatekeeperLogging -Scope Script -Force
        }
    }

    Context 'Basic configuration import' {
        It 'should import configuration successfully' {
            Mock -ModuleName Gatekeeper Import-Configuration {
                return @{
                    Version = '0.1.0'
                    FilePaths = @{
                        Schemas = 'test\schemas'
                    }
                }
            }

            $config = Import-GatekeeperConfig
            $config | Should -Not -BeNullOrEmpty
            $config.Version | Should -Be '0.1.0'
        }

        It 'should cache configuration on first load' {
            Mock -ModuleName Gatekeeper Import-Configuration {
                return @{
                    Version = '0.1.0'
                }
            }

            # First call
            $config1 = Import-GatekeeperConfig
            # Second call should use cache
            $config2 = Import-GatekeeperConfig

            Should -Invoke -ModuleName Gatekeeper -CommandName Import-Configuration -Times 1 -Exactly
        }

        It 'should return cached configuration on subsequent calls' {
            Mock -ModuleName Gatekeeper Import-Configuration {
                return @{
                    Version = '0.1.0'
                    Data = 'test'
                }
            }

            $config1 = Import-GatekeeperConfig
            $config2 = Import-GatekeeperConfig

            $config1.Data | Should -Be $config2.Data
        }
    }

    Context 'ForceReload parameter' {
        It 'should reload configuration when ForceReload is specified' {
            Mock -ModuleName Gatekeeper Import-Configuration {
                return @{
                    Version = '0.1.0'
                    Timestamp = Get-Date
                }
            }

            # First call
            $null = Import-GatekeeperConfig
            # Force reload
            $null = Import-GatekeeperConfig -ForceReload

            Should -Invoke -ModuleName Gatekeeper -CommandName Import-Configuration -Times 2 -Exactly
        }

        It 'should clear cache when ForceReload is specified' {
            Mock -ModuleName Gatekeeper Import-Configuration {
                return @{
                    Version = '0.1.0'
                }
            }

            $config1 = Import-GatekeeperConfig
            $config2 = Import-GatekeeperConfig -ForceReload

            Should -Invoke -ModuleName Gatekeeper -CommandName Import-Configuration -Times 2
        }
    }

    Context 'Logging configuration parsing' {
        It 'should parse logging configuration with scriptblocks' {
            Mock -ModuleName Gatekeeper Import-Configuration {
                return @{
                    Version = '0.1.0'
                    Logging = @{
                        Allow = @{
                            Enabled = $true
                            Script = { param($Rule) Write-Host "Allowed: $($Rule.Name)" }
                        }
                    }
                }
            }

            $config = Import-GatekeeperConfig
            $config.Logging.Allow.Script | Should -BeOfType [scriptblock]
        }

        It 'should skip disabled logging levels' {
            Mock -ModuleName Gatekeeper Import-Configuration {
                return @{
                    Version = '0.1.0'
                    Logging = @{
                        Allow = @{
                            Enabled = $false
                            Script = { param($Rule) Write-Host "Test" }
                        }
                        Deny = @{
                            Enabled = $true
                            Script = { param($Rule) Write-Host "Denied" }
                        }
                    }
                }
            }

            $config = Import-GatekeeperConfig
            # Should process Deny but skip Allow
            $config | Should -Not -BeNullOrEmpty
        }

        It 'should handle logging script as file path' {
            $tempScript = Join-Path ([System.IO.Path]::GetTempPath()) "GatekeeperTest_$(New-Guid).ps1"
            Set-Content -Path $tempScript -Value 'param($Rule); Write-Host "Test"'

            try {
                Mock -ModuleName Gatekeeper Import-Configuration {
                    return @{
                        Version = '0.1.0'
                        Logging = @{
                            Audit = @{
                                Enabled = $true
                                Script = $tempScript
                            }
                        }
                    }
                }

                $config = Import-GatekeeperConfig
                $config | Should -Not -BeNullOrEmpty
            } finally {
                if (Test-Path $tempScript) {
                    Remove-Item $tempScript -Force
                }
            }
        }

        It 'should throw when logging script file not found' {
            Mock -ModuleName Gatekeeper Import-Configuration {
                return @{
                    Version = '0.1.0'
                    Logging = @{
                        Audit = @{
                            Enabled = $true
                            Script = 'C:\NonExistent\Script.ps1'
                        }
                    }
                }
            }

            { Import-GatekeeperConfig -ErrorAction Stop } | Should -Throw
        }
    }

    Context 'Error handling' {
        It 'should throw when configuration import fails' {
            Mock -ModuleName Gatekeeper Import-Configuration {
                return $null
            }

            { Import-GatekeeperConfig -ErrorAction Stop } | Should -Throw
        }
    }
}

Describe 'Export-GatekeeperConfig' {
    BeforeEach {
        # Set up a mock configuration
        if (Get-Variable -Name GatekeeperConfiguration -Scope Script -ErrorAction SilentlyContinue) {
            Remove-Variable -Name GatekeeperConfiguration -Scope Script -Force
        }
    }

    Context 'Basic configuration export' {
        It 'should export configuration to Machine scope by default' {
            Mock -ModuleName Gatekeeper Import-GatekeeperConfig {
                $script:GatekeeperConfiguration = @{
                    Version = '0.1.0'
                }
            }
            Mock -ModuleName Gatekeeper Export-Configuration { }

            Export-GatekeeperConfig

            Should -Invoke -ModuleName Gatekeeper -CommandName Export-Configuration -Times 1 -ParameterFilter {
                $Scope -eq 'Machine'
            }
        }

        It 'should export to specified scope' {
            Mock -ModuleName Gatekeeper Import-GatekeeperConfig {
                $script:GatekeeperConfiguration = @{
                    Version = '0.1.0'
                }
            }
            Mock -ModuleName Gatekeeper Export-Configuration { }

            Export-GatekeeperConfig -ConfigurationScope 'User'

            Should -Invoke -ModuleName Gatekeeper -CommandName Export-Configuration -Times 1 -ParameterFilter {
                $Scope -eq 'User'
            }
        }

        It 'should accept Enterprise scope' {
            Mock -ModuleName Gatekeeper Import-GatekeeperConfig {
                $script:GatekeeperConfiguration = @{
                    Version = '0.1.0'
                }
            }
            Mock -ModuleName Gatekeeper Export-Configuration { }

            Export-GatekeeperConfig -ConfigurationScope 'Enterprise'

            Should -Invoke -ModuleName Gatekeeper -CommandName Export-Configuration -Times 1 -ParameterFilter {
                $Scope -eq 'Enterprise'
            }
        }
    }

    Context 'Custom configuration parameter' {
        It 'should use custom configuration when provided' {
            Mock -ModuleName Gatekeeper Export-Configuration { }

            $customConfig = @{
                Version = '2.0.0'
                CustomSetting = 'test'
            }

            Export-GatekeeperConfig -Configuration $customConfig

            Should -Invoke -ModuleName Gatekeeper -CommandName Export-Configuration -Times 1
        }

        It 'should import config if not already loaded' {
            Mock -ModuleName Gatekeeper Import-GatekeeperConfig {
                $script:GatekeeperConfiguration = @{
                    Version = '0.1.0'
                }
            }
            Mock -ModuleName Gatekeeper Export-Configuration { }

            Export-GatekeeperConfig

            Should -Invoke -ModuleName Gatekeeper -CommandName Import-GatekeeperConfig -Times 1
        }
    }

    Context 'LastUpdated timestamp' {
        It 'should set LastUpdated timestamp before export' {
            Mock -ModuleName Gatekeeper Import-GatekeeperConfig {
                $script:GatekeeperConfiguration = @{
                    Version = '0.1.0'
                }
            }
            Mock -ModuleName Gatekeeper Export-Configuration {
                param($InputObject)
                $InputObject.LastUpdated | Should -Not -BeNullOrEmpty
                $InputObject.LastUpdated | Should -BeOfType [datetime]
            }

            Export-GatekeeperConfig
        }
    }

    Context 'Error handling' {
        It 'should throw when configuration is not loaded' {
            Mock -ModuleName Gatekeeper Import-GatekeeperConfig { }

            { Export-GatekeeperConfig -ErrorAction Stop } | Should -Throw
        }
    }
}

Describe 'Get-FeatureFlagFolder' {
    BeforeEach {
        if (Get-Variable -Name GatekeeperConfiguration -Scope Script -ErrorAction SilentlyContinue) {
            Remove-Variable -Name GatekeeperConfiguration -Scope Script -Force
        }
    }

    Context 'Folder path retrieval' {
        It 'should return feature flag folder path' {
            $testPath = Join-Path ([System.IO.Path]::GetTempPath()) "GatekeeperTest_FF_$(New-Guid)"
            New-Item -Path $testPath -ItemType Directory -Force | Out-Null

            try {
                Mock -ModuleName Gatekeeper Import-GatekeeperConfig {
                    $script:GatekeeperConfiguration = @{
                        FilePaths = @{
                            FeatureFlags = $testPath
                        }
                    }
                }

                $folder = Get-FeatureFlagFolder
                $folder | Should -Be $testPath
            } finally {
                if (Test-Path $testPath) {
                    Remove-Item $testPath -Force
                }
            }
        }

        It 'should create default path if not configured' {
            $defaultPath = Join-Path ([System.IO.Path]::GetTempPath()) "GatekeeperTest_Default_$(New-Guid)"

            Mock -ModuleName Gatekeeper Import-GatekeeperConfig {
                $script:GatekeeperConfiguration = @{
                    FilePaths = @{}
                }
            }
            Mock -ModuleName Gatekeeper Get-ConfigurationPath { return [System.IO.Path]::GetTempPath() }
            Mock -ModuleName Gatekeeper Export-GatekeeperConfig { }

            try {
                $folder = Get-FeatureFlagFolder
                $folder | Should -Not -BeNullOrEmpty
            } finally {
                # Cleanup might be needed
            }
        }

        It 'should throw when folder does not exist' {
            Mock -ModuleName Gatekeeper Import-GatekeeperConfig {
                $script:GatekeeperConfiguration = @{
                    FilePaths = @{
                        FeatureFlags = 'C:\NonExistent\Path'
                    }
                }
            }

            { Get-FeatureFlagFolder -ErrorAction Stop } | Should -Throw
        }
    }

    Context 'Configuration initialization' {
        It 'should import configuration if not loaded' {
            $testPath = Join-Path ([System.IO.Path]::GetTempPath()) "GatekeeperTest_FF_$(New-Guid)"
            New-Item -Path $testPath -ItemType Directory -Force | Out-Null

            try {
                Mock -ModuleName Gatekeeper Import-GatekeeperConfig {
                    $script:GatekeeperConfiguration = @{
                        FilePaths = @{
                            FeatureFlags = $testPath
                        }
                    }
                }

                $null = Get-FeatureFlagFolder

                Should -Invoke -ModuleName Gatekeeper -CommandName Import-GatekeeperConfig -Times 1
            } finally {
                if (Test-Path $testPath) {
                    Remove-Item $testPath -Force
                }
            }
        }
    }
}

Describe 'Get-PropertySetFolder' {
    BeforeEach {
        if (Get-Variable -Name GatekeeperConfiguration -Scope Script -ErrorAction SilentlyContinue) {
            Remove-Variable -Name GatekeeperConfiguration -Scope Script -Force
        }
    }

    Context 'Folder path retrieval' {
        It 'should return property set folder path' {
            $testPath = Join-Path ([System.IO.Path]::GetTempPath()) "GatekeeperTest_PS_$(New-Guid)"
            New-Item -Path $testPath -ItemType Directory -Force | Out-Null

            try {
                Mock -ModuleName Gatekeeper Import-GatekeeperConfig {
                    $script:GatekeeperConfiguration = @{
                        FilePaths = @{
                            PropertySet = $testPath
                        }
                    }
                }

                $folder = Get-PropertySetFolder
                $folder | Should -Be $testPath
            } finally {
                if (Test-Path $testPath) {
                    Remove-Item $testPath -Force
                }
            }
        }

        It 'should create default path if not configured' {
            Mock -ModuleName Gatekeeper Import-GatekeeperConfig {
                $script:GatekeeperConfiguration = @{
                    FilePaths = @{}
                }
            }
            Mock -ModuleName Gatekeeper Get-ConfigurationPath { return [System.IO.Path]::GetTempPath() }
            Mock -ModuleName Gatekeeper Export-GatekeeperConfig { }

            $folder = Get-PropertySetFolder
            $folder | Should -Not -BeNullOrEmpty
        }

        It 'should throw when folder does not exist' {
            Mock -ModuleName Gatekeeper Import-GatekeeperConfig {
                $script:GatekeeperConfiguration = @{
                    FilePaths = @{
                        PropertySet = 'C:\NonExistent\Path'
                    }
                }
            }

            { Get-PropertySetFolder -ErrorAction Stop } | Should -Throw
        }
    }

    Context 'Configuration initialization' {
        It 'should import configuration if not loaded' {
            $testPath = Join-Path ([System.IO.Path]::GetTempPath()) "GatekeeperTest_PS_$(New-Guid)"
            New-Item -Path $testPath -ItemType Directory -Force | Out-Null

            try {
                Mock -ModuleName Gatekeeper Import-GatekeeperConfig {
                    $script:GatekeeperConfiguration = @{
                        FilePaths = @{
                            PropertySet = $testPath
                        }
                    }
                }

                $null = Get-PropertySetFolder

                Should -Invoke -ModuleName Gatekeeper -CommandName Import-GatekeeperConfig -Times 1
            } finally {
                if (Test-Path $testPath) {
                    Remove-Item $testPath -Force
                }
            }
        }
    }
}
