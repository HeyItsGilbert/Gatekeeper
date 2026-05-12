function Convert-ToTypedValue {
    param (
        [Parameter(Mandatory)]
        [string]
        $Type,
        [Parameter(Mandatory)]
        $Value
    )

    switch ($Type.ToLower()) {
        "integer" {
            return [int]$Value
        }
        "boolean" {
            if ($Value -is [bool]) { return $Value }
            if ($Value -is [int])  { return [bool]$Value }
            switch ($Value.ToString().ToLower()) {
                'true'  { return $true }
                'false' { return $false }
                '1'     { return $true }
                '0'     { return $false }
                default { throw "Cannot convert '$Value' to boolean" }
            }
        }
        "string" {
            return [string]$Value
        }
        default {
            throw "Unsupported property type: $Type"
        }
    }
}
