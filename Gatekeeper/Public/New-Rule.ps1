function New-Rule {
    <#
    .SYNOPSIS
    Create a new rule for a feature flag.

    .DESCRIPTION
    Create a new rule that can be used to define conditions under which a feature flag is applied.

    .PARAMETER Name
    The name of the rule.

    .PARAMETER Description
    A brief description of the rule.
    This is optional and can be used to provide additional context about the rule.

    .PARAMETER Effect
    The effect of the rule (e.g., allow, deny).

    .PARAMETER Conditions
    The conditions under which the rule applies.

    .EXAMPLE
    $condition1 = New-Condition -Property 'Environment' -Operator 'Equals' -Value 'Production'
    $condition2 = New-Condition -Property 'Region' -Operator 'In' -Value @('US', 'EU')
    $rule = New-Rule -Name 'ProductionRule' -Effect 'Allow' -Conditions $condition1, $condition2

    This would create a new rule named 'ProductionRule' that allows the feature flag in production environments and specific regions.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([Rule])]
    param (
        [Parameter(Mandatory)]
        [String]
        $Name,
        [Parameter()]
        $Description,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [Effect]
        $Effect,
        [Parameter(Mandatory, ValueFromPipeline)]
        [ConditionGroup]
        $Conditions
    )
    begin {
        $rule = [Rule]::new($Name)
        $rule.Description = $Description
        $rule.Effect = $Effect
        $conditionList = @()
    }
    process {
        foreach ($condition in $Conditions) {
            if ($PSCmdlet.ShouldProcess($condition.Property, "Add condition: $($condition.Property) with operator: $($condition.Operator)")) {
                $conditionList += $condition
            }
        }
    }
    end {
        # Join all the conditions into a single ConditionGroup
        if ($conditionList.Count -eq 0) {
            Write-Warning "No conditions were provided for the rule '$($rule.Name)'. The rule will apply the default effect to all cases!"
        } else {
            $rule.Conditions = [ConditionGroup]::new('AllOf', $conditionList)
        }
        if ($PSCmdlet.ShouldProcess($rule.Name, "Create new rule with effect: $($rule.Effect)")) {
            return $rule
        }
    }
}
