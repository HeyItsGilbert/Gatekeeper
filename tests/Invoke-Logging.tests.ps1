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

Describe 'Invoke-Logging' {
    BeforeAll {
        # Prevent actual config loading during tests
        Mock -CommandName 'Import-GatekeeperConfig' -ModuleName $env:BHProjectName {}

        $script:testRule = [Rule]::new(@{
            Name        = 'TestRule'
            Effect      = 'Allow'
            Condition   = @{ Property = 'IsCompliant'; Operator = 'Equals'; Value = $true }
        })
    }

    AfterEach {
        # Reset the logging cache between tests
        InModuleScope $env:BHProjectName {
            $script:GatekeeperLogging = $null
        }
    }

    Context 'Uses pre-parsed scriptblock cache' {
        It 'invokes the cached scriptblock for the matching effect' {
            $captureRule = $script:testRule

            InModuleScope $env:BHProjectName -Parameters @{ Rule = $captureRule } {
                param($Rule)
                $script:GatekeeperLogging = @{
                    Allow = { param($Rule) $script:lastLoggedRule = $Rule }
                }
                $script:lastLoggedRule = $null
            }

            InModuleScope $env:BHProjectName -Parameters @{ Rule = $captureRule } {
                param($Rule)
                Invoke-Logging -Effect 'Allow' -Rule $Rule
            }

            InModuleScope $env:BHProjectName {
                $script:lastLoggedRule | Should -Not -BeNull
                $script:lastLoggedRule.Name | Should -Be 'TestRule'
            }
        }

        It 'does not invoke a scriptblock for a different effect' {
            $captureRule = $script:testRule

            InModuleScope $env:BHProjectName -Parameters @{ Rule = $captureRule } {
                param($Rule)
                $script:GatekeeperLogging = @{
                    Deny = { param($Rule) $script:lastLoggedRule = $Rule }
                }
                $script:lastLoggedRule = $null
            }

            InModuleScope $env:BHProjectName -Parameters @{ Rule = $captureRule } {
                param($Rule)
                Invoke-Logging -Effect 'Allow' -Rule $Rule
            }

            InModuleScope $env:BHProjectName {
                $script:lastLoggedRule | Should -BeNull
            }
        }
    }

    Context 'Graceful no-ops' {
        It 'returns without error when GatekeeperLogging cache is null' {
            InModuleScope $env:BHProjectName {
                $script:GatekeeperLogging = $null
            }

            $captureRule = $script:testRule
            {
                InModuleScope $env:BHProjectName -Parameters @{ Rule = $captureRule } {
                    param($Rule)
                    Invoke-Logging -Effect 'Allow' -Rule $Rule
                }
            } | Should -Not -Throw
        }

        It 'returns without error when effect is not present in cache' {
            InModuleScope $env:BHProjectName {
                $script:GatekeeperLogging = @{}
            }

            $captureRule = $script:testRule
            {
                InModuleScope $env:BHProjectName -Parameters @{ Rule = $captureRule } {
                    param($Rule)
                    Invoke-Logging -Effect 'Allow' -Rule $Rule
                }
            } | Should -Not -Throw
        }
    }

    Context 'Config loading' {
        It 'calls Import-GatekeeperConfig to ensure cache is initialized' {
            $captureRule = $script:testRule
            InModuleScope $env:BHProjectName -Parameters @{ Rule = $captureRule } {
                param($Rule)
                Invoke-Logging -Effect 'Allow' -Rule $Rule
            }

            Should -Invoke 'Import-GatekeeperConfig' -ModuleName $env:BHProjectName -Times 1 -Exactly
        }
    }
}
