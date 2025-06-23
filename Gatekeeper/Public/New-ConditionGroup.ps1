function New-ConditionGroup {
    <#
    .SYNOPSIS
    Create a new condition group for feature flags.

    .DESCRIPTION
    Create a new condition group that can be used to define rules for feature flags.

    .PARAMETER JoinOperator
    The operator to use for joining conditions in the group (e.g., 'AllOf', 'AnyOf', 'Not').

    .PARAMETER Conditions
    The conditions that are part of the group. This can be a single condition or an array of conditions.

    .EXAMPLE
    $conditionGroup = New-ConditionGroup -JoinOperator 'AllOf' -Conditions @($condition1, $condition2)

    This would create a new condition group that requires all of the specified conditions to be met.
    .NOTES
    General notes
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([ConditionGroup])]
    [Alias('New-ConditionGroupDefinition')]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('AllOf', 'AnyOf', 'Not')]
        [String]
        $Operator,
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [ConditionGroup]
        $Conditions
    )

    Write-Verbose "Initializing new condition group with operator '$Operator'."
    # Test if Conditions are valid
    if (-not $Conditions) {
        Write-Warning "Conditions for the group are not defined."
    }

    if ($PSCmdlet.ShouldProcess("Condition", "Create new condition group with operator: $Operator")) {
        Write-Verbose "Creating condition group with operator '$Operator' and conditions '$Conditions'."
        return [ConditionGroup]::new($Operator, $Conditions)
    }
}
