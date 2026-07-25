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

Describe 'Condition' {
    Describe 'constructor - mutual exclusion' {
        It 'Throws when AllOf and AnyOf are both specified' {
            {
                [Condition]::new(@{
                    AllOf = @(@{ Property = 'A'; Operator = 'Equals'; Value = 'B' })
                    AnyOf = @(@{ Property = 'A'; Operator = 'Equals'; Value = 'B' })
                })
            } | Should -Throw -ExpectedMessage '*AllOf, AnyOf, Not*'
        }

        It 'Throws when AllOf and Not are both specified' {
            {
                [Condition]::new(@{
                    AllOf = @(@{ Property = 'A'; Operator = 'Equals'; Value = 'B' })
                    Not   = @(@{ Property = 'A'; Operator = 'Equals'; Value = 'B' })
                })
            } | Should -Throw -ExpectedMessage '*AllOf, AnyOf, Not*'
        }

        It 'Throws when AnyOf and Not are both specified' {
            {
                [Condition]::new(@{
                    AnyOf = @(@{ Property = 'A'; Operator = 'Equals'; Value = 'B' })
                    Not   = @(@{ Property = 'A'; Operator = 'Equals'; Value = 'B' })
                })
            } | Should -Throw -ExpectedMessage '*AllOf, AnyOf, Not*'
        }

        It 'Throws when Property is present without Operator and Value' {
            {
                [Condition]::new(@{ Property = 'Environment' })
            } | Should -Throw -ExpectedMessage '*Operator and Value*'
        }

        It 'Throws when Property is present without Value' {
            {
                [Condition]::new(@{ Property = 'Environment'; Operator = 'Equals' })
            } | Should -Throw -ExpectedMessage '*Operator and Value*'
        }

        It 'Throws when AllOf is combined with flat Property/Operator/Value fields' {
            {
                [Condition]::new(@{
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
            $cg = [Condition]::new(@{
                Property = 'Environment'
                Operator = 'Equals'
                Value    = 'Production'
            })
            $cg.IsValid() | Should -BeTrue
        }

        It 'Returns $false when Value is cleared after construction' {
            $cg = [Condition]::new(@{
                Property = 'Environment'
                Operator = 'Equals'
                Value    = 'Production'
            })
            $cg.Value = $null
            $cg.IsValid() | Should -BeFalse
        }

        It 'Returns $true for an AllOf group condition' {
            $cg = [Condition]::new(@{
                AllOf = @(
                    @{ Property = 'Environment'; Operator = 'Equals'; Value = 'Production' }
                )
            })
            $cg.IsValid() | Should -BeTrue
        }

        It 'Returns $true for an AnyOf group condition' {
            $cg = [Condition]::new(@{
                AnyOf = @(
                    @{ Property = 'Environment'; Operator = 'Equals'; Value = 'Staging' },
                    @{ Property = 'Environment'; Operator = 'Equals'; Value = 'Production' }
                )
            })
            $cg.IsValid() | Should -BeTrue
        }

        It 'Returns $true for a Not group condition' {
            $cg = [Condition]::new(@{
                Not = @(
                    @{ Property = 'Environment'; Operator = 'Equals'; Value = 'Production' }
                )
            })
            $cg.IsValid() | Should -BeTrue
        }
    }

    Describe 'ToString' {
        It 'Returns flat condition string' {
            $cg = [Condition]::new(@{
                Property = 'Environment'
                Operator = 'Equals'
                Value    = 'Staging'
            })
            $cg.ToString() | Should -Be 'Environment Equals Staging'
        }

        It 'Returns AllOf string' {
            $cg = [Condition]::new(@{
                AllOf = @(
                    @{ Property = 'Environment'; Operator = 'Equals'; Value = 'Staging' },
                    @{ Property = 'IsCompliant'; Operator = 'Equals'; Value = 'true' }
                )
            })
            $cg.ToString() | Should -Be 'AllOf(Environment Equals Staging, IsCompliant Equals true)'
        }

        It 'Returns AnyOf string' {
            $cg = [Condition]::new(@{
                AnyOf = @(
                    @{ Property = 'Environment'; Operator = 'Equals'; Value = 'Staging' },
                    @{ Property = 'Environment'; Operator = 'Equals'; Value = 'Production' }
                )
            })
            $cg.ToString() | Should -Be 'AnyOf(Environment Equals Staging, Environment Equals Production)'
        }

        It 'Returns Not string' {
            $cg = [Condition]::new(@{
                Not = @(
                    @{ Property = 'Environment'; Operator = 'Equals'; Value = 'Production' }
                )
            })
            $cg.ToString() | Should -Be 'Not(Environment Equals Production)'
        }

        It 'Returns nested AllOf+AnyOf string' {
            $cg = [Condition]::new(@{
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

Describe 'ConditionTransformAttribute' {
    BeforeAll {
        $script:propertySet = InModuleScope $env:BHProjectName {
            Read-PropertySet -FilePath "$PSScriptRoot\fixtures\Properties.json"
        }
        $script:context = @{
            Percentage  = 30
            Environment = 'Production'
            IsCompliant = $true
        }
    }

    It 'Converts a hashtable to Condition via Test-Condition' {
        $ht = @{ Property = 'Environment'; Operator = 'Equals'; Value = 'Production' }
        { Test-Condition -Condition $ht -PropertySet $script:propertySet -Context $script:context } |
            Should -Not -Throw
        Test-Condition -Condition $ht -PropertySet $script:propertySet -Context $script:context |
            Should -BeTrue
    }

    It 'Passes through an existing Condition via Test-Condition' {
        $cg = [Condition]::new(@{ Property = 'Environment'; Operator = 'Equals'; Value = 'Production' })
        Test-Condition -Condition $cg -PropertySet $script:propertySet -Context $script:context |
            Should -BeTrue
    }

    It 'Converts a JSON file path string to Condition via Test-Condition' {
        $conditionPath = Join-Path $TestDrive 'Condition.json'
        @{ Property = 'Environment'; Operator = 'Equals'; Value = 'Production' } |
            ConvertTo-Json | Set-Content -Path $conditionPath
        Test-Condition -Condition $conditionPath -PropertySet $script:propertySet -Context $script:context |
            Should -BeTrue
    }

    It 'Converts an ordered dictionary (ConvertFrom-Json -AsHashtable) to Condition via Test-Condition' -Skip:($PSVersionTable.PSVersion.Major -lt 6) {
        $ordered = '{ "Property": "Environment", "Operator": "Equals", "Value": "Production" }' |
            ConvertFrom-Json -AsHashtable
        $ordered.GetType().FullName | Should -Not -Be 'System.Collections.Hashtable'
        Test-Condition -Condition $ordered -PropertySet $script:propertySet -Context $script:context |
            Should -BeTrue
    }

    It 'Throws a useful message for unsupported input type' {
        {
            Test-Condition -Condition 42 -PropertySet $script:propertySet -Context $script:context
        } | Should -Throw -ExpectedMessage '*Cannot convert type*'
    }
}

Describe 'PropertySetTransformAttribute' {
    BeforeAll {
        $script:ctx  = @{ Environment = 'Production' }
        $script:cond = @{ Property = 'Environment'; Operator = 'Equals'; Value = 'Production' }
    }

    It 'Converts an ordered dictionary PropertySet (ConvertFrom-Json -AsHashtable)' -Skip:($PSVersionTable.PSVersion.Major -lt 6) {
        $ordered = '{ "Environment": { "Type": "string" } }' | ConvertFrom-Json -AsHashtable
        $ordered.GetType().FullName | Should -Not -Be 'System.Collections.Hashtable'
        Test-Condition -Condition $script:cond -PropertySet $ordered -Context $script:ctx |
            Should -BeTrue
    }

    It 'Converts a non-Hashtable IDictionary PropertySet' {
        $od = [System.Collections.Specialized.OrderedDictionary]::new()
        $od['Environment'] = @{ Type = 'string' }
        Test-Condition -Condition $script:cond -PropertySet $od -Context $script:ctx |
            Should -BeTrue
    }

    It 'Passes through an existing PropertySet' {
        $ps = [PropertySet]::new(@{ Environment = @{ Type = 'string' } })
        Test-Condition -Condition $script:cond -PropertySet $ps -Context $script:ctx |
            Should -BeTrue
    }

    It 'Throws a useful message for unsupported input type' {
        {
            Test-Condition -Condition $script:cond -PropertySet 42 -Context $script:ctx
        } | Should -Throw -ExpectedMessage '*Cannot convert type*'
    }
}

Describe 'FeatureFlagTransformAttribute' {
    BeforeAll {
        Mock -CommandName Invoke-Logging -ModuleName $env:BHProjectName
    }

    It 'Converts an ordered dictionary FeatureFlag and PropertySet (issue #85 repro)' -Skip:($PSVersionTable.PSVersion.Major -lt 6) {
        $propertySet = '{ "Region": { "Type": "string" } }' | ConvertFrom-Json -AsHashtable
        $flag = @{
            Name = 'MyFeature'; DefaultEffect = 'Deny'
            Rules = @(
                @{ Name = 'Allow group'; Effect = 'Allow'; Condition = @{ Property = 'Region'; Operator = 'Equals'; Value = 'west' } }
            )
        } | ConvertTo-Json -Depth 10 | ConvertFrom-Json -AsHashtable
        $flag.GetType().FullName | Should -Not -Be 'System.Collections.Hashtable'

        Test-FeatureFlag -FeatureFlag $flag -PropertySet $propertySet -Context @{ Region = 'west' } |
            Should -BeTrue
    }

    It 'Throws a useful message for unsupported input type' {
        $ps = [PropertySet]::new(@{ Region = @{ Type = 'string' } })
        {
            Test-FeatureFlag -FeatureFlag 42 -PropertySet $ps -Context @{ Region = 'west' }
        } | Should -Throw -ExpectedMessage '*Cannot convert type*'
    }
}

Describe 'Property.Validate' {
    It 'Returns $true when no validation is configured' {
        $pd = [Property]::new('Env', @{ Type = 'string' })
        $pd.Validate('anything') | Should -BeTrue
    }

    It 'Returns $true for a valid integer within range' {
        $pd = [Property]::new('Count', @{
            Type       = 'integer'
            Validation = @{ Minimum = 0; Maximum = 100 }
        })
        $pd.Validate(50) | Should -BeTrue
    }

    It 'Returns $false and emits warning when integer is below minimum' {
        $pd = [Property]::new('Count', @{
            Type       = 'integer'
            Validation = @{ Minimum = 10; Maximum = 100 }
        })
        $warnings = & { $pd.Validate(5) } 3>&1 | Where-Object { $_ -is [System.Management.Automation.WarningRecord] }
        $warnings | Should -Not -BeNullOrEmpty
        $pd.Validate(5) | Should -BeFalse
    }

    It 'Returns $false when integer exceeds maximum' {
        $pd = [Property]::new('Count', @{
            Type       = 'integer'
            Validation = @{ Minimum = 0; Maximum = 10 }
        })
        $pd.Validate(50) | Should -BeFalse
    }

    It 'Returns $false when string is below MinLength' {
        $pd = [Property]::new('Code', @{
            Type       = 'string'
            Validation = @{ MinLength = 5; MaxLength = 20 }
        })
        $pd.Validate('abc') | Should -BeFalse
    }

    It 'Returns $false when string exceeds MaxLength' {
        $pd = [Property]::new('Code', @{
            Type       = 'string'
            Validation = @{ MinLength = 1; MaxLength = 5 }
        })
        $pd.Validate('toolongstring') | Should -BeFalse
    }

    It 'Returns $false when string does not match pattern' {
        $pd = [Property]::new('ZipCode', @{
            Type       = 'string'
            Validation = @{ Pattern = '^\d{5}$' }
        })
        $pd.Validate('abc') | Should -BeFalse
    }

    It 'Returns $true when string matches pattern' {
        $pd = [Property]::new('ZipCode', @{
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
            $pd = [Property]::new('Environment', @{ Type = 'string' })
            $ps.AddProperty($pd)
            $ps.Properties.ContainsKey('Environment') | Should -BeTrue
        }

        It 'Returns $this for method chaining' {
            $ps = [PropertySet]::new('TestSet')
            $pd = [Property]::new('Environment', @{ Type = 'string' })
            $result = $ps.AddProperty($pd)
            $result | Should -Be $ps
        }

        It 'Supports chaining multiple AddProperty calls' {
            $ps = [PropertySet]::new('TestSet')
            $ps.AddProperty([Property]::new('Env', @{ Type = 'string' })).AddProperty(
                [Property]::new('Score', @{ Type = 'integer' })
            ) | Out-Null
            $ps.Properties.Keys.Count | Should -Be 2
        }
    }

    Describe 'GetProperty' {
        It 'Returns the correct Property by name' {
            $ps = [PropertySet]::new('TestSet')
            $pd = [Property]::new('Environment', @{ Type = 'string' })
            $ps.AddProperty($pd)
            $result = $ps.GetProperty('Environment')
            $result | Should -Be $pd
            $result.Name | Should -Be 'Environment'
        }
    }

    Describe 'ContainsKey' {
        BeforeAll {
            $script:ps = [PropertySet]::new('TestSet')
            $script:ps.AddProperty([Property]::new('Environment', @{ Type = 'string' }))
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
            $original.AddProperty([Property]::new('Score', @{
                Type       = 'integer'
                Validation = @{ Minimum = 5; Maximum = 100 }
            }))
            $original.AddProperty([Property]::new('Label', @{
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
