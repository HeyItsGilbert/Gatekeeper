function Test-FeatureFlag {
    <#
    .SYNOPSIS
    Checks if the current machine's context will pass the feature flag rules.

    .DESCRIPTION
    Determines if a given context will pass the feature flag rules. Returns a
    `$True` or `$False` allowing you to gate keep your features.

    .PARAMETER FeatureFlag
    The name of the feature flag to test.

    .PARAMETER PropertySet
    A PropertySet that defines the different values in the context.

    .PARAMETER Context
    The context to use to test against.

    .EXAMPLE
    $propertySet = Get-PropertySet -Name props
    $flag = New-FeatureFlag -Name 'MyFeature'
    $context = New-Context -PropertySet $propertySet
    $context.Hostname = $env:COMPUTERNAME
    Test-FeatureFlag -FeatureFlag $flag -PropertySet $propertySet -Context $context

    This will test if the current device will pass the feature flag rules.

    .OUTPUTS
    System.Boolean
    Returns $true if an Allow rule matches, $false otherwise.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [FeatureFlag]
        [FeatureFlagTransformAttribute()]
        $FeatureFlag,
        [Parameter(Mandatory)]
        [PropertySet]
        [PropertySetTransformAttribute()]
        $PropertySet,
        [Parameter(Mandatory)]
        [hashtable]
        $Context
    )

    begin {
        $finalResult = $false
        $terminalHit = $false
    }

    process {
        # Process each feature
        Write-Verbose "Processing Feature $($FeatureFlag.Name) with ($($FeatureFlag.Rules.Count)) rules"
        :ruleLoop foreach ($rule in $FeatureFlag.Rules) {
            Write-Verbose "Processing Rule $($rule.Name)"
            $testConditionSplat = @{
                Context = $Context
                PropertySet = $PropertySet
                Condition = $rule.Condition
            }
            if (Test-Condition @testConditionSplat) {
                Write-Verbose "✅ Rule [$($rule.Name)] matched. Effect: $($rule.Effect)"
                # Check effect
                switch ($rule.Effect) {
                    'Allow' {
                        Invoke-Logging -Effect 'Allow' -Rule $rule
                        $finalResult = $true
                        $terminalHit = $true
                        break ruleLoop
                    }
                    'Deny' {
                        Invoke-Logging -Effect 'Deny' -Rule $rule
                        $finalResult = $false
                        $terminalHit = $true
                        break ruleLoop
                    }
                    'Audit' {
                        Invoke-Logging -Effect 'Audit' -Rule $rule
                    }
                    'Warn' {
                        Invoke-Logging -Effect 'Warn' -Rule $rule
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
        if (-not $terminalHit) {
            $finalResult = $FeatureFlag.DefaultEffect -eq [Effect]::Allow
        }
        return $finalResult
    }
}
