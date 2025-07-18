﻿function Test-FeatureFlag {
    <#
    .SYNOPSIS
    Checks if the current machine's context will pass the feature flag rules.

    .DESCRIPTION
    Determines if a given context will pass the feature flag rules. Returns a
    `$True` or `$False` allowing you to gate keep your features.

    .PARAMETER FeatureFlag
    The name of the feature flag to test.

    .PARAMETER Properties
    A hashtable of properties that define the different values in the context.

    .PARAMETER Context
    The context to use to test against.

    .EXAMPLE
    $context = Get-DeviceContext
    Test-FeatureFlag -FeatureFlag '' -Context $context

    This will test if the current device will pass the feature flag rules.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [FeatureFlag]
        [FeatureFlagTransformAttribute()]
        $FeatureFlag,
        [PropertySet]
        [PropertySetTransformAttribute()]
        $Properties,
        [Parameter(Mandatory)]
        [hashtable]
        $Context
    )

    begin {
        $finalResult = $False
    }

    process {
        # Process each feature
        Write-Verbose "Processing Feature $($FeatureFlag.Name) with ($($FeatureFlag.Rules.Count)) rules"
        foreach ($rule in $Feature.Rules) {
            Write-Verbose "Processing Rule $($rule.Name)"
            $testConditionSplat = @{
                Context = $Context
                Properties = $Properties
                Condition = $rule.Conditions
            }
            if (Test-Condition @testConditionSplat) {
                Write-Verbose "✅ Rule [$($rule.Name)] matched. Effect: $($rule.Effect)" -ForegroundColor Green
                # Check effect
                switch ($rule.Effect) {
                    'Allow' {
                        $finalResult = $true
                        break
                    }
                    'Deny' {
                        $finalResult = $false
                        break
                    }
                    'Audit' {
                        # TODO: Implement auditing function
                    }
                    'Warn' {
                        Write-Warning "⚠️ Rule [$($rule.Name)] matched."
                    }
                    default {
                        throw 'Unknown effect'
                    }
                }
            } else {
                Write-Verbose "⛔ Rule [$($rule.Name)] did not match."
            }
        }
    }

    end {
        # Return a single bool
        return $finalResult
    }
}
