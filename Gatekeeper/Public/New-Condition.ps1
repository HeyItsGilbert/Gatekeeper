function New-Condition {
    <#
    .SYNOPSIS
    Create a new condition for a property.

    .DESCRIPTION
    Create a new condition that can be used to define rules for feature flags.
    .PARAMETER Property
    The property to evaluate (e.g., 'Environment', 'Region').

    .PARAMETER Operator
    The operator to use for the evaluation (e.g., 'Equals', 'In').

    .PARAMETER Value
    The value to compare against (e.g., 'Production', @('US', 'EU')).

    .EXAMPLE
    $condition = New-Condition -Property 'Environment' -Operator 'Equals' -Value 'Production'

    This would create a new condition that checks if the 'Environment' property equals 'Production'.
    .NOTES
    General notes
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([ConditionGroup])]
    [Alias('New-ConditionDefinition')]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Property,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [Operator]
        $Operator,
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [object]
        $Value
    )

    Write-Verbose "Initializing new condition for property '$Property' with operator '$Operator' and value '$Value'."
    # Test if Property is a known property
    if ($property -notin (Get-PropertySet).Properties.Keys) {
        Write-Warning "Property '$Property' is not defined in any property set."
    }

    if ($PSCmdlet.ShouldProcess("Condition", "Create new condition for property: $Property with operator: $Operator")) {
        Write-Verbose "Creating condition for property '$Property' with operator '$Operator' and value '$Value'."

        return [ConditionGroup]::new(@{Property = $Property; Operator = $Operator; Value = $Value })
    }
}
