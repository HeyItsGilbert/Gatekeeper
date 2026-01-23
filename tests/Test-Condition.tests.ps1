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
Describe 'Test-Condition' {
    BeforeAll {
        $script:propertySet = Read-PropertySet -File "$PSScriptRoot\fixtures\Properties.json"
        $script:context = @{
            Percentage = 30
            Environment = 'Production'
            IsCompliant = $true
        }
        # load feature flag
        $json = Get-Content -Path "$PSScriptRoot\fixtures\Updawg.json" -Raw | ConvertFrom-JsonToHashtable
        $script:rules = $json.Rules
        $script:testConditionSplat = @{
            Context = $script:context
            PropertySet = $script:propertySet
        }
    }

    #region Evaluate the different types
    It 'Can evaluate string' {
        $condition = @{
            Property = "Environment"
            Operator = "Equals"
            Value = "Production"
        }
        Test-Condition @script:testConditionSplat -Condition $condition | Should -BeTrue
    }
    It 'Can evaluate a string in condition array' {
        $condition = @{
            Property = "Environment"
            Operator = "In"
            Value = @(
                "Production",
                "Stage"
            )
        }
        Test-Condition @script:testConditionSplat -Condition $condition | Should -BeTrue
    }
    It 'Can evaluate int' {
        $condition = @{
            Property = "Percentage"
            Operator = "GreaterThan"
            Value = 10
        }
        Test-Condition @script:testConditionSplat -Condition $condition | Should -BeTrue
    }
    It 'Can evaluate a $true bool with equals' {
        $condition = @{
            Property = "IsCompliant"
            Operator = "Equals"
            Value = $True
        }
        Test-Condition @script:testConditionSplat -Condition $condition | Should -BeTrue
    }
    It 'Can evaluate a bool with not equals' {
        $condition = @{
            Property = "IsCompliant"
            Operator = "NotEquals"
            Value = $false
        }
        Test-Condition @script:testConditionSplat -Condition $condition | Should -BeTrue
    }

    #endregion Evaluate the different types

    It 'Can evaluate AnyOf group' {
        $condition = @{
            AnyOf = @(
                @{
                    Property = "Environment"
                    Operator = "Equals"
                    Value = "Production"
                },
                @{
                    Property = "Environment"
                    Operator = "Equals"
                    Value = "Staging"
                }
            )
        }
        Test-Condition @script:testConditionSplat -Condition $condition | Should -BeTrue
    }
    It 'Can evaluate AnyOf group (negative test)' {
        $condition = @{
            AnyOf = @(
                @{
                    Property = "Environment"
                    Operator = "Equals"
                    Value = "Dev"
                },
                @{
                    Property = "Environment"
                    Operator = "Equals"
                    Value = "Staging"
                }
            )
        }
        Test-Condition @script:testConditionSplat -Condition $condition | Should -BeFalse
    }
    It 'Can evaluate AllOf group' {
        $condition = @{
            AllOf = @(
                @{
                    Property = "Environment"
                    Operator = "Equals"
                    Value = "Production"
                },
                @{
                    Property = "IsCompliant"
                    Operator = "Equals"
                    Value = $true
                }
            )
        }
        Test-Condition @script:testConditionSplat -Condition $condition | Should -BeTrue
    }
    It 'Can evaluate AllOf group (negative test)' {
        $condition = @{
            AllOf = @(
                @{
                    Property = "Environment"
                    Operator = "Equals"
                    Value = "Production"
                },
                @{
                    Property = "Environment"
                    Operator = "Equals"
                    Value = "Staging"
                }
            )
        }
        Test-Condition @script:testConditionSplat -Condition $condition | Should -BeFalse
    }
    It 'Can evaluate Not group' {
        $condition = @{
            Not = @(
                @{
                    Property = "Environment"
                    Operator = "Equals"
                    Value = "Staging"
                }
            )
        }
        Test-Condition @script:testConditionSplat -Condition $condition | Should -BeTrue
    }
    It 'Can evaluate Not group (negative test)' {
        $condition = @{
            Not = @(
                @{
                    Property = "Environment"
                    Operator = "Equals"
                    Value = "Production"
                }
            )
        }
        Test-Condition @script:testConditionSplat -Condition $condition | Should -BeFalse
    }
    It 'Throws on context missing property' {
        $condition = @{
            Property = "Tier"
            # Not a real operator
            Operator = "GreaterThanOrEqual"
            Value = 1
        }
        {
            Test-Condition @script:testConditionSplat -Condition $condition
        } | Should -Throw -ExpectedMessage "Context is missing required property 'Tier'"
    }
    It 'Throws on PropertySet missing property in context' {
        $condition = @{
            Property = "Tier"
            # Not a real operator
            Operator = "Equals"
            Value = 'Top'
        }
        $context = @{
            Percentage = 30
            Environment = 'Production'
            IsCompliant = $true
            Tier = 'Top'
        }

        {
            Test-Condition -PropertySet $script:propertySet -Context $context -Condition $condition
        } | Should -Throw -ExpectedMessage "Property metadata for 'Tier' is missing"
    }
    It 'Throws on a bad operator' {
        $condition = @{
            Property = "Percentage"
            # Not a real operator (spelling mistake)
            Operator = "GreaterThanOrEquals"
            Value = 1
        }
        {
            Test-Condition @script:testConditionSplat -Condition $condition
        } | Should -Throw
    }
    It 'Throws if doing an in/notin comparison and condition is not a list' {
        $condition = @{
            Property = "Environment"
            Operator = "In"
            Value = 2
        }
        {
            Test-Condition @script:testConditionSplat -Condition $condition
        } | Should -Throw -ExpectedMessage 'Condition is using In/NotIn but not passing a list'
    }
}
