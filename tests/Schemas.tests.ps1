# Regression tests for the schema corrections made to Gatekeeper/Schemas/*.json
# (see issue #105). These assert the schema *files* directly via Test-Json, so a
# revert of either file - or of any single corrected rule inside it - fails here,
# independent of whatever any particular fixture under tests/fixtures/ happens to
# exercise.
BeforeAll {
    $script:featureFlagSchema = Join-Path $PSScriptRoot '..\Gatekeeper\Schemas\FeatureFlag.json'
    $script:propertiesSchema = Join-Path $PSScriptRoot '..\Gatekeeper\Schemas\Properties.json'

    function Test-AgainstSchema {
        param(
            [Parameter(Mandatory)][string]$Json,
            [Parameter(Mandatory)][string]$SchemaFile
        )
        try {
            Test-Json -Json $Json -SchemaFile $SchemaFile -ErrorAction Stop
        } catch {
            $false
        }
    }

    # Minimal otherwise-valid FeatureFlag document; $Condition is spliced into the
    # single rule's Condition so each case only has to describe the piece under test.
    function New-FeatureFlagJson {
        param([Parameter(Mandatory)][hashtable]$Condition)
        $rule = @{
            Name      = 'Rule'
            Effect    = 'Allow'
            Condition = $Condition
        } | ConvertTo-Json -Depth 10 -Compress
        @{
            Name          = 'Flag'
            Description   = 'Desc'
            Version       = '1.0.0'
            DefaultEffect = 'Deny'
            Rules         = @(ConvertFrom-Json $rule)
        } | ConvertTo-Json -Depth 10
    }
}

Describe 'FeatureFlag.json' {
    Context 'Rules cardinality' {
        It 'Validates an empty Rules array with only a DefaultEffect' {
            $json = @{
                Name          = 'Flag'
                Description   = 'Desc'
                Version       = '1.0.0'
                DefaultEffect = 'Allow'
                Rules         = @()
            } | ConvertTo-Json
            Test-AgainstSchema -Json $json -SchemaFile $script:featureFlagSchema | Should -BeTrue
        }
    }

    Context 'Operator enum' -ForEach @(
        @{ Operator = 'Equals' }
        @{ Operator = 'NotEquals' }
        @{ Operator = 'GreaterThan' }
        @{ Operator = 'GreaterThanOrEqual' }
        @{ Operator = 'LessThan' }
        @{ Operator = 'LessThanOrEqual' }
        @{ Operator = 'In' }
        @{ Operator = 'NotIn' }
    ) {
        It "Validates Operator '<Operator>'" {
            $json = New-FeatureFlagJson -Condition @{ Property = 'Tier'; Operator = $Operator; Value = 1 }
            Test-AgainstSchema -Json $json -SchemaFile $script:featureFlagSchema | Should -BeTrue
        }
    }

    It 'Rejects an Operator outside the enum' {
        $json = New-FeatureFlagJson -Condition @{ Property = 'Tier'; Operator = 'Contains'; Value = 1 }
        Test-AgainstSchema -Json $json -SchemaFile $script:featureFlagSchema | Should -BeFalse
    }

    Context 'Not shape' {
        It 'Validates a nonempty array-shaped Not (NOR semantics, ADR 0003)' {
            $json = New-FeatureFlagJson -Condition @{
                Not = @(@{ Property = 'Tier'; Operator = 'Equals'; Value = 1 })
            }
            Test-AgainstSchema -Json $json -SchemaFile $script:featureFlagSchema | Should -BeTrue
        }

        It 'Validates a multi-element array-shaped Not' {
            $json = New-FeatureFlagJson -Condition @{
                Not = @(
                    @{ Property = 'Tier'; Operator = 'Equals'; Value = 1 }
                    @{ Property = 'Tier'; Operator = 'Equals'; Value = 2 }
                )
            }
            Test-AgainstSchema -Json $json -SchemaFile $script:featureFlagSchema | Should -BeTrue
        }

        It 'Rejects the pre-correction single-object Not shape' {
            $json = New-FeatureFlagJson -Condition @{
                Not = @{ Property = 'Tier'; Operator = 'Equals'; Value = 1 }
            }
            Test-AgainstSchema -Json $json -SchemaFile $script:featureFlagSchema | Should -BeFalse
        }

        It 'Rejects an empty-array Not (minItems: 1)' {
            $json = New-FeatureFlagJson -Condition @{ Not = @() }
            Test-AgainstSchema -Json $json -SchemaFile $script:featureFlagSchema | Should -BeFalse
        }
    }

    Context 'Leaf Value' {
        It 'Rejects an explicit JSON null Value' {
            $json = New-FeatureFlagJson -Condition @{ Property = 'Tier'; Operator = 'Equals'; Value = $null }
            Test-AgainstSchema -Json $json -SchemaFile $script:featureFlagSchema | Should -BeFalse
        }

        It 'Validates a non-null Value' {
            $json = New-FeatureFlagJson -Condition @{ Property = 'Tier'; Operator = 'Equals'; Value = 'Staging' }
            Test-AgainstSchema -Json $json -SchemaFile $script:featureFlagSchema | Should -BeTrue
        }
    }
}

Describe 'Properties.json' {
    Context 'Validation keys applicable per Type' -ForEach @(
        @{ Type = 'integer'; Validation = @{ Minimum = 0; Maximum = 10 }; Expected = $true }
        @{ Type = 'integer'; Validation = @{ MinLength = 1 }; Expected = $false }
        @{ Type = 'integer'; Validation = @{ MaxLength = 1 }; Expected = $false }
        @{ Type = 'integer'; Validation = @{ Pattern = '^\d+$' }; Expected = $false }
        @{ Type = 'string'; Validation = @{ MinLength = 1; MaxLength = 5; Pattern = '^\d+$' }; Expected = $true }
        @{ Type = 'string'; Validation = @{ Minimum = 0 }; Expected = $false }
        @{ Type = 'string'; Validation = @{ Maximum = 10 }; Expected = $false }
        @{ Type = 'boolean'; Validation = @{ Minimum = 0 }; Expected = $false }
        @{ Type = 'boolean'; Validation = @{ MinLength = 1 }; Expected = $false }
    ) {
        It "Type '<Type>' with Validation key(s) '<Validation.Keys>' -> expected <Expected>" {
            $json = @{
                Prop = @{ Type = $Type; Validation = $Validation }
            } | ConvertTo-Json -Depth 10
            Test-AgainstSchema -Json $json -SchemaFile $script:propertiesSchema | Should -Be $Expected
        }
    }

    Context 'Minimum/Maximum bound type' {
        It 'Validates integer-typed Minimum/Maximum' {
            $json = @{ Prop = @{ Type = 'integer'; Validation = @{ Minimum = 0; Maximum = 10 } } } | ConvertTo-Json -Depth 10
            Test-AgainstSchema -Json $json -SchemaFile $script:propertiesSchema | Should -BeTrue
        }

        It 'Rejects a fractional Minimum' {
            $json = @{ Prop = @{ Type = 'integer'; Validation = @{ Minimum = 0.5 } } } | ConvertTo-Json -Depth 10
            Test-AgainstSchema -Json $json -SchemaFile $script:propertiesSchema | Should -BeFalse
        }

        It 'Rejects a fractional Maximum' {
            $json = @{ Prop = @{ Type = 'integer'; Validation = @{ Maximum = 10.5 } } } | ConvertTo-Json -Depth 10
            Test-AgainstSchema -Json $json -SchemaFile $script:propertiesSchema | Should -BeFalse
        }
    }

    Context 'Enum applies to every Type (unchanged by this correction)' -ForEach @(
        @{ Type = 'string' }
        @{ Type = 'integer' }
        @{ Type = 'boolean' }
    ) {
        It "Validates an Enum on a '<Type>' property" {
            $json = @{ Prop = @{ Type = $Type; Enum = @() } } | ConvertTo-Json -Depth 10
            Test-AgainstSchema -Json $json -SchemaFile $script:propertiesSchema | Should -BeTrue
        }
    }
}
