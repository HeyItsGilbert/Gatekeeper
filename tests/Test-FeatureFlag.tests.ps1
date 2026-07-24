BeforeDiscovery {
    if ($env:BHPSModuleManifest -eq $null -or $env:BHProjectPath -eq $null -or $env:BHProjectName -eq $null) {
        . $PSscriptRoot\..\build.ps1 -Task Build
    }
    $manifest = Import-PowerShellDataFile -Path $env:BHPSModuleManifest
    $outputDir = Join-Path -Path $env:BHProjectPath -ChildPath 'Output'
    $outputModDir = Join-Path -Path $outputDir -ChildPath $env:BHProjectName
    $outputModVerDir = Join-Path -Path $outputModDir -ChildPath $manifest.ModuleVersion
    $outputModVerManifest = Join-Path -Path $outputModVerDir -ChildPath "$($env:BHProjectName).psd1"
    Import-Module -Name $outputModVerManifest -Verbose:$false -ErrorAction Stop
}

Describe 'Test-FeatureFlag' {
    BeforeAll {
        $fixturePath = "$PSScriptRoot\fixtures\Properties.json"
        $script:propertySet = InModuleScope $env:BHProjectName -Parameters @{ Path = $fixturePath } {
            param($Path)
            Read-PropertySet -FilePath $Path
        }
        $script:context = @{
            Percentage  = 30
            Environment = 'Staging'
            IsCompliant = $true
        }
        # Conditions that always match / never match given $script:context
        $script:matchCond   = @{ Property = 'IsCompliant'; Operator = 'Equals'; Value = $true }
        $script:noMatchCond = @{ Property = 'IsCompliant'; Operator = 'Equals'; Value = $false }

        Mock -CommandName Invoke-Logging -ModuleName $env:BHProjectName
    }

    Context 'Effect paths' {
        It 'Allow rule that matches returns $true' {
            $flag = [FeatureFlag]::new(@{
                Name = 'AllowFlag'; DefaultEffect = 'Deny'; Version = '1.0.0'; Author = 'Test'
                Rules = @(@{ Name = 'AllowRule'; Effect = 'Allow'; Condition = $script:matchCond })
            })
            $result = Test-FeatureFlag -FeatureFlag $flag -PropertySet $script:propertySet -Context $script:context
            $result | Should -BeTrue
            Should -Invoke -CommandName Invoke-Logging -ModuleName $env:BHProjectName `
                -ParameterFilter { $Effect -eq 'Allow' } -Times 1 -Exactly
        }

        It 'Deny rule that matches returns $false' {
            $flag = [FeatureFlag]::new(@{
                Name = 'DenyFlag'; DefaultEffect = 'Allow'; Version = '1.0.0'; Author = 'Test'
                Rules = @(@{ Name = 'DenyRule'; Effect = 'Deny'; Condition = $script:matchCond })
            })
            $result = Test-FeatureFlag -FeatureFlag $flag -PropertySet $script:propertySet -Context $script:context
            $result | Should -BeFalse
            Should -Invoke -CommandName Invoke-Logging -ModuleName $env:BHProjectName `
                -ParameterFilter { $Effect -eq 'Deny' } -Times 1 -Exactly
        }

        It 'Audit rule matches, logs, continues; subsequent Allow still wins' {
            $flag = [FeatureFlag]::new(@{
                Name = 'AuditFlag'; DefaultEffect = 'Deny'; Version = '1.0.0'; Author = 'Test'
                Rules = @(
                    @{ Name = 'AuditRule'; Effect = 'Audit'; Condition = $script:matchCond }
                    @{ Name = 'AllowRule'; Effect = 'Allow'; Condition = $script:matchCond }
                )
            })
            $result = Test-FeatureFlag -FeatureFlag $flag -PropertySet $script:propertySet -Context $script:context
            $result | Should -BeTrue
            Should -Invoke -CommandName Invoke-Logging -ModuleName $env:BHProjectName `
                -ParameterFilter { $Effect -eq 'Audit' } -Times 1 -Exactly
            Should -Invoke -CommandName Invoke-Logging -ModuleName $env:BHProjectName `
                -ParameterFilter { $Effect -eq 'Allow' } -Times 1 -Exactly
        }

        It 'Warn rule matches, logs, continues; subsequent Allow still wins' {
            $flag = [FeatureFlag]::new(@{
                Name = 'WarnFlag'; DefaultEffect = 'Deny'; Version = '1.0.0'; Author = 'Test'
                Rules = @(
                    @{ Name = 'WarnRule'; Effect = 'Warn'; Condition = $script:matchCond }
                    @{ Name = 'AllowRule'; Effect = 'Allow'; Condition = $script:matchCond }
                )
            })
            $result = Test-FeatureFlag -FeatureFlag $flag -PropertySet $script:propertySet -Context $script:context
            $result | Should -BeTrue
            Should -Invoke -CommandName Invoke-Logging -ModuleName $env:BHProjectName `
                -ParameterFilter { $Effect -eq 'Warn' } -Times 1 -Exactly
            Should -Invoke -CommandName Invoke-Logging -ModuleName $env:BHProjectName `
                -ParameterFilter { $Effect -eq 'Allow' } -Times 1 -Exactly
        }
    }

    Context 'Ordering — first-match-wins' {
        It 'Deny before matching Allow returns $false (Deny wins)' {
            $flag = [FeatureFlag]::new(@{
                Name = 'DenyFirstFlag'; DefaultEffect = 'Deny'; Version = '1.0.0'; Author = 'Test'
                Rules = @(
                    @{ Name = 'DenyFirst';   Effect = 'Deny';  Condition = $script:matchCond }
                    @{ Name = 'AllowSecond'; Effect = 'Allow'; Condition = $script:matchCond }
                )
            })
            $result = Test-FeatureFlag -FeatureFlag $flag -PropertySet $script:propertySet -Context $script:context
            $result | Should -BeFalse
            Should -Invoke -CommandName Invoke-Logging -ModuleName $env:BHProjectName `
                -ParameterFilter { $Effect -eq 'Deny' } -Times 1 -Exactly
            Should -Invoke -CommandName Invoke-Logging -ModuleName $env:BHProjectName `
                -ParameterFilter { $Effect -eq 'Allow' } -Times 0 -Exactly
        }

        It 'Allow before matching Deny returns $true (Allow wins)' {
            $flag = [FeatureFlag]::new(@{
                Name = 'AllowFirstFlag'; DefaultEffect = 'Deny'; Version = '1.0.0'; Author = 'Test'
                Rules = @(
                    @{ Name = 'AllowFirst'; Effect = 'Allow'; Condition = $script:matchCond }
                    @{ Name = 'DenySecond'; Effect = 'Deny';  Condition = $script:matchCond }
                )
            })
            $result = Test-FeatureFlag -FeatureFlag $flag -PropertySet $script:propertySet -Context $script:context
            $result | Should -BeTrue
            Should -Invoke -CommandName Invoke-Logging -ModuleName $env:BHProjectName `
                -ParameterFilter { $Effect -eq 'Allow' } -Times 1 -Exactly
            Should -Invoke -CommandName Invoke-Logging -ModuleName $env:BHProjectName `
                -ParameterFilter { $Effect -eq 'Deny' } -Times 0 -Exactly
        }
    }

    Context 'DefaultEffect fallback — no rule matches' {
        It 'DefaultEffect Allow returns $true when no rule matches' {
            $flag = [FeatureFlag]::new(@{
                Name = 'AllowDefaultFlag'; DefaultEffect = 'Allow'; Version = '1.0.0'; Author = 'Test'
                Rules = @(@{ Name = 'DenyNoMatch'; Effect = 'Deny'; Condition = $script:noMatchCond })
            })
            $result = Test-FeatureFlag -FeatureFlag $flag -PropertySet $script:propertySet -Context $script:context
            $result | Should -BeTrue
        }

        It 'DefaultEffect Deny returns $false when no rule matches' {
            $flag = [FeatureFlag]::new(@{
                Name = 'DenyDefaultFlag'; DefaultEffect = 'Deny'; Version = '1.0.0'; Author = 'Test'
                Rules = @(@{ Name = 'AllowNoMatch'; Effect = 'Allow'; Condition = $script:noMatchCond })
            })
            $result = Test-FeatureFlag -FeatureFlag $flag -PropertySet $script:propertySet -Context $script:context
            $result | Should -BeFalse
        }

        It 'Empty rules with DefaultEffect Allow returns $true' {
            $flag = [FeatureFlag]::new(@{
                Name = 'EmptyAllowFlag'; DefaultEffect = 'Allow'; Version = '1.0.0'; Author = 'Test'
                Rules = @()
            })
            $result = Test-FeatureFlag -FeatureFlag $flag -PropertySet $script:propertySet -Context $script:context
            $result | Should -BeTrue
        }

        It 'Empty rules with DefaultEffect Deny returns $false' {
            $flag = [FeatureFlag]::new(@{
                Name = 'EmptyDenyFlag'; DefaultEffect = 'Deny'; Version = '1.0.0'; Author = 'Test'
                Rules = @()
            })
            $result = Test-FeatureFlag -FeatureFlag $flag -PropertySet $script:propertySet -Context $script:context
            $result | Should -BeFalse
        }
    }

    Context 'Pipeline and input types' {
        It 'Single flag via pipeline evaluates correctly' {
            $flag = [FeatureFlag]::new(@{
                Name = 'PipelineFlag'; DefaultEffect = 'Deny'; Version = '1.0.0'; Author = 'Test'
                Rules = @(@{ Name = 'AllowRule'; Effect = 'Allow'; Condition = $script:matchCond })
            })
            $result = $flag | Test-FeatureFlag -PropertySet $script:propertySet -Context $script:context
            $result | Should -BeTrue
        }

        It 'Multiple flags each evaluate independently' {
            $allowFlag = [FeatureFlag]::new(@{
                Name = 'AllowFlag'; DefaultEffect = 'Allow'; Version = '1.0.0'; Author = 'Test'
                Rules = @()
            })
            $denyFlag = [FeatureFlag]::new(@{
                Name = 'DenyFlag'; DefaultEffect = 'Deny'; Version = '1.0.0'; Author = 'Test'
                Rules = @()
            })
            $allowResult = Test-FeatureFlag -FeatureFlag $allowFlag -PropertySet $script:propertySet -Context $script:context
            $denyResult  = Test-FeatureFlag -FeatureFlag $denyFlag  -PropertySet $script:propertySet -Context $script:context
            $allowResult | Should -BeTrue
            $denyResult  | Should -BeFalse
        }

        It 'Hashtable input via FeatureFlagTransformAttribute evaluates correctly' {
            $ht = @{
                Name = 'HtFlag'; DefaultEffect = 'Allow'; Version = '1.0.0'; Author = 'Test'
                Rules = @()
            }
            $result = Test-FeatureFlag -FeatureFlag $ht -PropertySet $script:propertySet -Context $script:context
            $result | Should -BeTrue
        }

        It 'File path string input via FeatureFlagTransformAttribute evaluates correctly' {
            $result = Test-FeatureFlag -FeatureFlag "$PSScriptRoot\fixtures\FeatureFlag.json" `
                -PropertySet $script:propertySet -Context $script:context
            $result | Should -BeTrue
        }
    }

    Context 'Path validation' {
        It 'Rejects a wildcard feature flag path' {
            {
                Test-FeatureFlag -FeatureFlag (Join-Path $TestDrive '*.json') -PropertySet $script:propertySet -Context $script:context
            } | Should -Throw -ExpectedMessage '*wildcard*'
        }

        It 'Rejects a non-JSON feature flag path' {
            $notJson = Join-Path $TestDrive 'flag.txt'
            'not json' | Set-Content -LiteralPath $notJson
            {
                Test-FeatureFlag -FeatureFlag $notJson -PropertySet $script:propertySet -Context $script:context
            } | Should -Throw -ExpectedMessage '*must point to a .json file*'
        }
    }
}
