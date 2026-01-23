function Test-Condition {
    <#
    .SYNOPSIS
    Evaluate whether a feature flag rule applies.

    .DESCRIPTION
    Takes the given context, properties, and rule/condition and evaluates
    whether the rule applies and what it's effect is.

    .PARAMETER Context
    The device context.

    .PARAMETER PropertySet
    The PropertySet that matches given context.

    .PARAMETER Condition
    A condition to test which are part of rules.

    .EXAMPLE
    $context = Get-DeviceContext
    $propertySet = Read-PropertySet
    $rule = $rules[0]
    Test-Condition -Context $context -PropertySet $propertySet -Condition $rule

    This would return a true/false
    #>
    param (
        [Parameter(Mandatory)]
        [hashtable]
        $Context,
        [Parameter(Mandatory)]
        [PropertySet]
        [PropertySetTransformAttribute()]
        $PropertySet,
        [Parameter(Mandatory)]
        [ConditionGroup]
        [ConditionGroupTransformAttribute()]
        $Condition
    )

    $Properties = $PropertySet.Properties

    #region Recurse on groups
    if ($null -ne $Condition.AllOf) {
        foreach ($child in $Condition.AllOf) {
            if (-not (Test-Condition -Context $Context -PropertySet $PropertySet -Condition $child)) {
                return $false
            }
        }
        return $true
    }

    if ($null -ne $Condition.AnyOf) {
        foreach ($child in $Condition.AnyOf) {
            if (Test-Condition -Context $Context -PropertySet $PropertySet -Condition $child) {
                return $true
            }
        }
        return $false
    }

    if ($null -ne $Condition.Not) {
        foreach ($child in $Condition.Not) {
            if (Test-Condition -Context $Context -PropertySet $PropertySet -Condition $child) {
                return $false
            }
        }
        return $true
    }
    #endregion Recurse on groups

    # Flat condition
    $propName = $Condition.Property
    $operator = $Condition.Operator
    $expected = $Condition.Value

    if (-not $Context.ContainsKey($propName)) {
        throw "Context is missing required property '$propName'"
    }
    if (-not $Properties.ContainsKey($propName)) {
        throw "Property metadata for '$propName' is missing"
    }

    $meta = $PropertySet.GetProperty($propName)
    $propType = $meta.Type
    $validation = $meta.Validation

    $actual = Convert-ToTypedValue -Type $propType -Value $Context[$propName]
    $testTypedValueSplat = @{
        PropertyDefinition = $meta
        Value = $actual
    }
    Test-TypedValue @testTypedValueSplat | Out-Null

    if (
        $operator -in @("In", "NotIn") -and
        $expected -isnot [System.Collections.IEnumerable]
    ) {
        throw 'Condition is using In/NotIn but not passing a list'
    }

    if (
        $operator -in @("In", "NotIn") -and
        $expected -is [System.Collections.IEnumerable] -and
        -not ($expected -is [string])
    ) {
        $expectedCoerced = @()
        foreach ($val in $expected) {
            $expectedCoerced += Convert-ToTypedValue -Type $propType -Value $val
        }
    } else {
        $expectedCoerced = Convert-ToTypedValue -Type $propType -Value $expected
    }

    switch ($operator) {
        "Equals" { return $actual -eq $expectedCoerced }
        "NotEquals" { return $actual -ne $expectedCoerced }
        "GreaterThan" { return $actual -gt $expectedCoerced }
        "GreaterThanOrEqual" { return $actual -ge $expectedCoerced }
        "LessThan" { return $actual -lt $expectedCoerced }
        "LessThanOrEqual" { return $actual -le $expectedCoerced }
        "In" { return $expectedCoerced -contains $actual }
        "NotIn" { return -not ($expectedCoerced -contains $actual) }
        default { throw "Unsupported operator: $operator" }
    }
}
