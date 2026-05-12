BeforeDiscovery {
    if ($env:BHPSModuleManifest -eq $null -or $env:BHProjectPath -eq $null -or $env:BHProjectName -eq $null) {
        . $PSScriptRoot\..\build.ps1 -Task Build
    }
    $manifest = Import-PowerShellDataFile -Path $env:BHPSModuleManifest
    $outputDir = Join-Path -Path $env:BHProjectPath -ChildPath 'Output'
    $outputModDir = Join-Path -Path $outputDir -ChildPath $env:BHProjectName
    $outputModVerDir = Join-Path -Path $outputModDir -ChildPath $manifest.ModuleVersion
    $outputModVerManifest = Join-Path -Path $outputModVerDir -ChildPath "$($env:BHProjectName).psd1"
    Get-Module $env:BHProjectName | Remove-Module -Force -ErrorAction Ignore
    Import-Module -Name $outputModVerManifest -Verbose:$false -ErrorAction Stop
}

Describe 'ConditionGroup' {
    Describe 'constructor - mutual exclusion' {
        It 'Throws when AllOf and AnyOf are both specified' {
            {
                [ConditionGroup]::new(@{
                    AllOf = @(@{ Property = 'A'; Operator = 'Equals'; Value = 'B' })
                    AnyOf = @(@{ Property = 'A'; Operator = 'Equals'; Value = 'B' })
                })
            } | Should -Throw -ExpectedMessage '*AllOf, AnyOf, Not*'
        }

        It 'Throws when AllOf and Not are both specified' {
            {
                [ConditionGroup]::new(@{
                    AllOf = @(@{ Property = 'A'; Operator = 'Equals'; Value = 'B' })
                    Not   = @(@{ Property = 'A'; Operator = 'Equals'; Value = 'B' })
                })
            } | Should -Throw -ExpectedMessage '*AllOf, AnyOf, Not*'
        }

        It 'Throws when AnyOf and Not are both specified' {
            {
                [ConditionGroup]::new(@{
                    AnyOf = @(@{ Property = 'A'; Operator = 'Equals'; Value = 'B' })
                    Not   = @(@{ Property = 'A'; Operator = 'Equals'; Value = 'B' })
                })
            } | Should -Throw -ExpectedMessage '*AllOf, AnyOf, Not*'
        }

        It 'Throws when Property is present without Operator and Value' {
            {
                [ConditionGroup]::new(@{ Property = 'Environment' })
            } | Should -Throw -ExpectedMessage '*Operator and Value*'
        }

        It 'Throws when Property is present without Value' {
            {
                [ConditionGroup]::new(@{ Property = 'Environment'; Operator = 'Equals' })
            } | Should -Throw -ExpectedMessage '*Operator and Value*'
        }

        It 'Throws when AllOf is combined with flat Property/Operator/Value fields' {
            {
                [ConditionGroup]::new(@{
                    AllOf    = @(@{ Property = 'A'; Operator = 'Equals'; Value = 'B' })
                    Property = 'Environment'
                    Operator = 'Equals'
                    Value    = 'Staging'
                })
            } | Should -Throw -ExpectedMessage '*Property, Operator, and Value*'
        }
    }

    Describe 'IsValid' {
        It 'Returns $true for a flat leaf condition' {
            $cg = [ConditionGroup]::new(@{
                Property = 'Environment'
                Operator = 'Equals'
                Value    = 'Production'
            })
            $cg.IsValid() | Should -BeTrue
        }

        It 'Returns $false when Value is cleared after construction' {
            $cg = [ConditionGroup]::new(@{
                Property = 'Environment'
                Operator = 'Equals'
                Value    = 'Production'
            })
            $cg.Value = $null
            $cg.IsValid() | Should -BeFalse
        }
    }

    Describe 'ToString' {
        It 'Returns flat condition string' {
            $cg = [ConditionGroup]::new(@{
                Property = 'Environment'
                Operator = 'Equals'
                Value    = 'Staging'
            })
            $cg.ToString() | Should -Be 'Environment Equals Staging'
        }

        It 'Returns AllOf string' {
            $cg = [ConditionGroup]::new(@{
                AllOf = @(
                    @{ Property = 'Environment'; Operator = 'Equals'; Value = 'Staging' },
                    @{ Property = 'IsCompliant'; Operator = 'Equals'; Value = 'true' }
                )
            })
            $cg.ToString() | Should -Be 'AllOf(Environment Equals Staging, IsCompliant Equals true)'
        }

        It 'Returns AnyOf string' {
            $cg = [ConditionGroup]::new(@{
                AnyOf = @(
                    @{ Property = 'Environment'; Operator = 'Equals'; Value = 'Staging' },
                    @{ Property = 'Environment'; Operator = 'Equals'; Value = 'Production' }
                )
            })
            $cg.ToString() | Should -Be 'AnyOf(Environment Equals Staging, Environment Equals Production)'
        }

        It 'Returns Not string' {
            $cg = [ConditionGroup]::new(@{
                Not = @(
                    @{ Property = 'Environment'; Operator = 'Equals'; Value = 'Production' }
                )
            })
            $cg.ToString() | Should -Be 'Not(Environment Equals Production)'
        }

        It 'Returns nested AllOf+AnyOf string' {
            $cg = [ConditionGroup]::new(@{
                AllOf = @(
                    @{
                        AnyOf = @(
                            @{ Property = 'IsCompliant'; Operator = 'Equals'; Value = 'true' },
                            @{ Property = 'Percentage'; Operator = 'LessThan'; Value = '11' }
                        )
                    },
                    @{ Property = 'Environment'; Operator = 'Equals'; Value = 'Staging' }
                )
            })
            $cg.ToString() | Should -Be 'AllOf(AnyOf(IsCompliant Equals true, Percentage LessThan 11), Environment Equals Staging)'
        }
    }
}

Describe 'ConditionGroupTransformAttribute' {
    BeforeAll {
        $script:propertySet = Read-PropertySet -File "$PSScriptRoot\fixtures\Properties.json"
        $script:context = @{
            Percentage  = 30
            Environment = 'Production'
            IsCompliant = $true
        }
    }

    It 'Converts a hashtable to ConditionGroup via Test-Condition' {
        $ht = @{ Property = 'Environment'; Operator = 'Equals'; Value = 'Production' }
        { Test-Condition -Condition $ht -PropertySet $script:propertySet -Context $script:context } |
            Should -Not -Throw
        Test-Condition -Condition $ht -PropertySet $script:propertySet -Context $script:context |
            Should -BeTrue
    }

    It 'Passes through an existing ConditionGroup via Test-Condition' {
        $cg = [ConditionGroup]::new(@{ Property = 'Environment'; Operator = 'Equals'; Value = 'Production' })
        Test-Condition -Condition $cg -PropertySet $script:propertySet -Context $script:context |
            Should -BeTrue
    }

    It 'Converts a JSON file path string to ConditionGroup via Test-Condition' {
        $conditionPath = Join-Path $TestDrive 'Condition.json'
        @{ Property = 'Environment'; Operator = 'Equals'; Value = 'Production' } |
            ConvertTo-Json | Set-Content -Path $conditionPath
        Test-Condition -Condition $conditionPath -PropertySet $script:propertySet -Context $script:context |
            Should -BeTrue
    }

    It 'Throws a useful message for unsupported input type' {
        {
            Test-Condition -Condition 42 -PropertySet $script:propertySet -Context $script:context
        } | Should -Throw -ExpectedMessage '*Cannot convert type*'
    }
}

Describe 'PropertyDefinition.Validate' {
    It 'Returns $true when no validation is configured' {
        $pd = [PropertyDefinition]::new('Env', @{ Type = 'string' })
        $pd.Validate('anything') | Should -BeTrue
    }

    It 'Returns $true for a valid integer within range' {
        $pd = [PropertyDefinition]::new('Count', @{
            Type       = 'integer'
            Validation = @{ Minimum = 0; Maximum = 100 }
        })
        $pd.Validate(50) | Should -BeTrue
    }

    It 'Returns $false and emits warning when integer is below minimum' {
        $pd = [PropertyDefinition]::new('Count', @{
            Type       = 'integer'
            Validation = @{ Minimum = 10; Maximum = 100 }
        })
        $warnings = & { $pd.Validate(5) } 3>&1 | Where-Object { $_ -is [System.Management.Automation.WarningRecord] }
        $warnings | Should -Not -BeNullOrEmpty
        $pd.Validate(5) | Should -BeFalse
    }

    It 'Returns $false when integer exceeds maximum' {
        $pd = [PropertyDefinition]::new('Count', @{
            Type       = 'integer'
            Validation = @{ Minimum = 0; Maximum = 10 }
        })
        $pd.Validate(50) | Should -BeFalse
    }

    It 'Returns $false when string is below MinLength' {
        $pd = [PropertyDefinition]::new('Code', @{
            Type       = 'string'
            Validation = @{ MinLength = 5; MaxLength = 20 }
        })
        $pd.Validate('abc') | Should -BeFalse
    }

    It 'Returns $false when string exceeds MaxLength' {
        $pd = [PropertyDefinition]::new('Code', @{
            Type       = 'string'
            Validation = @{ MinLength = 1; MaxLength = 5 }
        })
        $pd.Validate('toolongstring') | Should -BeFalse
    }

    It 'Returns $false when string does not match pattern' {
        $pd = [PropertyDefinition]::new('ZipCode', @{
            Type       = 'string'
            Validation = @{ Pattern = '^\d{5}$' }
        })
        $pd.Validate('abc') | Should -BeFalse
    }

    It 'Returns $true when string matches pattern' {
        $pd = [PropertyDefinition]::new('ZipCode', @{
            Type       = 'string'
            Validation = @{ Pattern = '^\d{5}$' }
        })
        $pd.Validate('12345') | Should -BeTrue
    }
}

Describe 'PropertySet' {
    Describe 'AddProperty' {
        It 'Adds entry keyed by property Name' {
            $ps = [PropertySet]::new('TestSet')
            $pd = [PropertyDefinition]::new('Environment', @{ Type = 'string' })
            $ps.AddProperty($pd)
            $ps.Properties.ContainsKey('Environment') | Should -BeTrue
        }

        It 'Returns $this for method chaining' {
            $ps = [PropertySet]::new('TestSet')
            $pd = [PropertyDefinition]::new('Environment', @{ Type = 'string' })
            $result = $ps.AddProperty($pd)
            $result | Should -Be $ps
        }

        It 'Supports chaining multiple AddProperty calls' {
            $ps = [PropertySet]::new('TestSet')
            $ps.AddProperty([PropertyDefinition]::new('Env', @{ Type = 'string' })).AddProperty(
                [PropertyDefinition]::new('Score', @{ Type = 'integer' })
            ) | Out-Null
            $ps.Properties.Keys.Count | Should -Be 2
        }
    }

    Describe 'GetProperty' {
        It 'Returns the correct PropertyDefinition by name' {
            $ps = [PropertySet]::new('TestSet')
            $pd = [PropertyDefinition]::new('Environment', @{ Type = 'string' })
            $ps.AddProperty($pd)
            $result = $ps.GetProperty('Environment')
            $result | Should -Be $pd
            $result.Name | Should -Be 'Environment'
        }
    }

    Describe 'ContainsKey' {
        BeforeAll {
            $script:ps = [PropertySet]::new('TestSet')
            $script:ps.AddProperty([PropertyDefinition]::new('Environment', @{ Type = 'string' }))
        }

        It 'Returns $true for an existing property' {
            $script:ps.ContainsKey('Environment') | Should -BeTrue
        }

        It 'Returns $false for a missing property' {
            $script:ps.ContainsKey('Missing') | Should -BeFalse
        }
    }

    Describe 'FromFile' {
        It 'Sets Name from filename without extension' {
            $ps = [PropertySet]::FromFile("$PSScriptRoot\fixtures\Properties.json")
            $ps.Name | Should -Be 'Properties'
        }

        It 'Loads all top-level properties' {
            $ps = [PropertySet]::FromFile("$PSScriptRoot\fixtures\Properties.json")
            $ps.ContainsKey('Percentage') | Should -BeTrue
            $ps.ContainsKey('Environment') | Should -BeTrue
            $ps.ContainsKey('IsCompliant') | Should -BeTrue
        }
    }

    Describe 'Save and FromFile round-trip' {
        It 'Preserves properties and validation constraints' {
            $original = [PropertySet]::new('RoundTrip')
            $original.AddProperty([PropertyDefinition]::new('Score', @{
                Type       = 'integer'
                Validation = @{ Minimum = 5; Maximum = 100 }
            }))
            $original.AddProperty([PropertyDefinition]::new('Label', @{
                Type = 'string'
            }))

            $savePath = Join-Path $TestDrive 'RoundTrip.json'
            $original.FilePath = $savePath
            $original.Save()

            $loaded = [PropertySet]::FromFile($savePath)
            $loaded.Name | Should -Be 'RoundTrip'
            $loaded.ContainsKey('Score') | Should -BeTrue
            $loaded.ContainsKey('Label') | Should -BeTrue
            $loaded.GetProperty('Score').Type | Should -Be 'integer'
            $loaded.GetProperty('Score').Validation.Minimum | Should -Be 5
            $loaded.GetProperty('Score').Validation.Maximum | Should -Be 100
            $loaded.GetProperty('Label').Type | Should -Be 'string'
        }
    }
}

Describe 'FeatureFlag' {
    Describe 'FromJson' {
        It 'Round-trips Name, DefaultEffect, and Rules count' {
            $json = Get-Content -Raw -Path "$PSScriptRoot\fixtures\FeatureFlag.json"
            $ff = [FeatureFlag]::FromJson($json)
            $ff.Name | Should -Be 'New Startup Sound'
            $ff.DefaultEffect | Should -Be 'Deny'
            $ff.Rules | Should -HaveCount 3
        }
    }

    Describe 'FromFile' {
        It 'Loads Name, FilePath, and Rules from fixture' {
            $ff = [FeatureFlag]::FromFile("$PSScriptRoot\fixtures\FeatureFlag.json")
            $ff.Name | Should -Be 'New Startup Sound'
            $ff.FilePath | Should -Not -BeNullOrEmpty
            $ff.Rules | Should -HaveCount 3
        }
    }

    Describe 'Save' {
        It 'Writes JSON that re-parses to an equivalent object' {
            $original = [FeatureFlag]::FromFile("$PSScriptRoot\fixtures\FeatureFlag.json")
            $savePath = Join-Path $TestDrive 'SavedFlag.json'
            $original.FilePath = $savePath
            $original.Save()

            $loaded = [FeatureFlag]::FromFile($savePath)
            $loaded.Name | Should -Be $original.Name
            $loaded.DefaultEffect | Should -Be $original.DefaultEffect
            $loaded.Rules | Should -HaveCount $original.Rules.Count
            $loaded.Author | Should -Be $original.Author
            $loaded.Description | Should -Be $original.Description
        }
    }
}
