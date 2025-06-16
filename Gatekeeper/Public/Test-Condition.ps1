function Test-Condition {
    <#
    .SYNOPSIS
    Evaluate whether a feature flag rule applies.

    .DESCRIPTION
    Takes the given context, properties, and rule/condition and evaluates
    whether the rule applies and what it's effect is.

    .PARAMETER Context
    The device context.

    .PARAMETER Properties
    The properties that matches given context.

    .PARAMETER Condition
    A condition to test which are part of rules.

    .EXAMPLE
    $context = Get-DeviceContext
    $properties = Read-PropertySet
    $rule = $rules[0]
    Test-Condition -Context $context -Properties $properties -Condition $rule

    This would return a true/false
    #>
    param (
        [Parameter(Mandatory)]
        [hashtable]
        $Context,
        [Parameter(Mandatory)]
        [PropertySet]
        [PropertySetTransformAttribute()]
        $Properties,
        [Parameter(Mandatory)]
        [Hashtable]
        $Condition
    )

    #region Recurse on groups
    if ($Condition.ContainsKey('AllOf')) {
        foreach ($child in $Condition.AllOf) {
            if (-not (Test-Condition -Context $Context -Properties $Properties -Condition $child)) {
                return $false
            }
        }
        return $true
    }

    if ($Condition.ContainsKey('AnyOf')) {
        foreach ($child in $Condition.AnyOf) {
            if (Test-Condition -Context $Context -Properties $Properties -Condition $child) {
                return $true
            }
        }
        return $false
    }

    if ($Condition.ContainsKey('Not')) {
        foreach ($child in $Condition.Not) {
            if (Test-Condition -Context $Context -Properties $Properties -Condition $child) {
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

    $meta = $Properties.GetProperty($propName)
    $propType = $meta.Type
    $validation = $meta.Validation

    $actual = Convert-ToTypedValue -Type $propType -Value $Context[$propName]
    $testTypedValueSplat = @{
        Type = $propType
        Name = $propName
        Value = $actual
        Validation = $validation
    }
    Test-TypedValue @testTypedValueSplat

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
        "LessThan" { return $actual -lt $expectedCoerced }
        "In" { return $expectedCoerced -contains $actual }
        "NotIn" { return -not ($expectedCoerced -contains $actual) }
        default { throw "Unsupported operator: $operator" }
    }
}
