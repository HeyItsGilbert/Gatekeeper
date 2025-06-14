function Test-FeatureFlag {
    <#
    .SYNOPSIS
    Checks if the current machine's context will pass the feature flag rules.

    .DESCRIPTION
    Determines if a given context will pass the feature flag rules. Returns a
    `$True` or `$False` allowing you to gate keep your features.

    .PARAMETER Feature
    The name of the feature flag to test.

    .PARAMETER Properties
    A hashtable of properties that define the different values in the context.

    .PARAMETER Context
    The context to use to test against.

    .EXAMPLE
    $context = Get-DeviceContext
    Test-FeatureFlag -Feature '' -Context $context

    This will test if the current device will pass the feature flag rules.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [string]
        $Feature,
        [PropertySet]
        [PropertySetTransformAttribute()]
        $Properties,
        [hashtable]
        $Context
    )

    begin {
        # Load the context once if it wasn't given
        if (-not $PSBoundParameters.ContainsKey('Context')) {
            #This means we're determining the context of the current device.
            $currentContext = Get-DeviceContext
        } else {
            $currentContext = $Context
        }
        if (-not $PSBoundParameters.ContainsKey('Properties')) {
            #This means we're determining the context of the current device.
            $currentProperties = Read-PropertySet
        } else {
            # PropertySet has a Properties item
            $currentProperties = $Properties.Properties
        }
        $finalResult = $False
    }

    process {
        # Process each feature
        foreach ($rule in $Feature.Rules) {
            $testConditionSplat = @{
                Context = $currentContext
                Properties = $currentProperties
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
