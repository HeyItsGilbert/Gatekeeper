function Test-TypedValue {
    param (
        [Parameter(Mandatory)]
        [string]
        $Type,
        [Parameter(Mandatory)]
        $Name,
        [Parameter(Mandatory)]
        $Value,
        [Parameter()]
        $Validation
    )

    if (-not $Validation) { return }

    switch ($Type.ToLower()) {
        "integer" {
            if ($null -ne $Validation.Minimum -and $Value -lt $Validation.Minimum) {
                throw "Value for '$Name' ($Value) is less than minimum allowed ($($Validation.Minimum))"
            }
            if ($null -ne $Validation.Maximum -and $Value -gt $Validation.Maximum) {
                throw "Value for '$Name' ($Value) is greater than maximum allowed ($($Validation.Maximum))"
            }
        }
        "string" {
            if ($null -ne $Validation.MinLength -and $Value.Length -lt $Validation.MinLength) {
                throw "Value for '$Name' is shorter than MinLength ($($Validation.MinLength))"
            }
            if ($null -ne $Validation.MaxLength -and $Value.Length -gt $Validation.MaxLength) {
                throw "Value for '$Name' is longer than MaxLength ($($Validation.MaxLength))"
            }
            if ($Validation.Pattern -and ($Value -notmatch $Validation.Pattern)) {
                throw "Value for '$Name' does not match pattern '$($Validation.Pattern)'"
            }
        }
    }
}
