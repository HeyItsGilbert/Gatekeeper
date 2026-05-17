function New-ConditionGroup {
    <#
    .SYNOPSIS
    Create a composite Condition by connecting child Conditions with a logical connective.

    .DESCRIPTION
    Composes multiple Conditions using AllOf (all must match), AnyOf (at least one
    must match), or Not (none must match). Use parameter sets to select the connective.

    .PARAMETER AllOf
    Child Conditions that must ALL match for this Condition to match.

    .PARAMETER AnyOf
    Child Conditions where AT LEAST ONE must match for this Condition to match.

    .PARAMETER Not
    Child Conditions that must NONE match for this Condition to match.

    .EXAMPLE
    $condition = New-ConditionGroup -AllOf @(
        (New-Condition -Property 'Environment' -Operator 'Equals' -Value 'Production'),
        (New-Condition -Property 'IsCompliant' -Operator 'Equals' -Value $true)
    )

    .EXAMPLE
    $condition = New-ConditionGroup -AnyOf @(
        (New-Condition -Property 'Region' -Operator 'Equals' -Value 'US'),
        (New-Condition -Property 'Region' -Operator 'Equals' -Value 'EU')
    )

    .EXAMPLE
    $condition = New-ConditionGroup -Not @(
        (New-Condition -Property 'Environment' -Operator 'Equals' -Value 'Production')
    )
    #>
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'AllOf')]
    [OutputType([Condition])]
    [Alias('New-ConditionGroupDefinition')]
    param (
        [Parameter(Mandatory, ParameterSetName = 'AllOf')]
        [Condition[]]
        $AllOf,
        [Parameter(Mandatory, ParameterSetName = 'AnyOf')]
        [Condition[]]
        $AnyOf,
        [Parameter(Mandatory, ParameterSetName = 'Not')]
        [Condition[]]
        $Not
    )

    $connective = $PSCmdlet.ParameterSetName
    $conditions = switch ($connective) {
        'AllOf' { $AllOf }
        'AnyOf' { $AnyOf }
        'Not'   { $Not }
    }

    if ($PSCmdlet.ShouldProcess("Condition", "Create new $connective condition group")) {
        Write-Verbose "Creating $connective condition group with $($conditions.Count) child condition(s)."
        return [Condition]::new($connective, $conditions)
    }
}
