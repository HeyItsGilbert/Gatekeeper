function New-Rule {
    <#
    .SYNOPSIS
    Create a new rule for a feature flag.

    .DESCRIPTION
    Create a new rule that pairs a Condition with an Effect. When the Condition
    matches a Context, the Effect is applied. The Condition must be fully
    constructed before being passed — use New-Condition or New-ConditionGroup to
    build it.

    .PARAMETER Name
    The name of the rule.

    .PARAMETER Description
    A brief description of the rule.

    .PARAMETER Effect
    The effect to apply when the Condition matches (Allow, Deny, Audit, Warn).

    .PARAMETER Condition
    The Condition to evaluate. Must be a single pre-built Condition object.

    .EXAMPLE
    $condition = New-Condition -Property 'Environment' -Operator 'Equals' -Value 'Production'
    $rule = New-Rule -Name 'ProductionRule' -Effect 'Allow' -Condition $condition

    Creates a rule that allows access when the Environment equals Production.

    .EXAMPLE
    $condition = New-ConditionGroup -AllOf @(
        (New-Condition -Property 'Environment' -Operator 'Equals' -Value 'Production'),
        (New-Condition -Property 'Region' -Operator 'In' -Value @('US', 'EU'))
    )
    $rule = New-Rule -Name 'ProductionUS-EU' -Effect 'Allow' -Condition $condition
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
        [Parameter(Mandatory)]
        [Condition]
        [ConditionTransformAttribute()]
        $Condition
    )

    if ($PSCmdlet.ShouldProcess($Name, "Create new rule with effect: $Effect")) {
        $rule = [Rule]::new($Name)
        $rule.Description = $Description
        $rule.Effect = $Effect
        $rule.Condition = $Condition
        return $rule
    }
}
