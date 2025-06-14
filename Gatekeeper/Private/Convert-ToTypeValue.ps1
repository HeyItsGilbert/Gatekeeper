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
            return [bool]::Parse($Value.ToString())
        }
        "string" {
            return [string]$Value
        }
        default {
            throw "Unsupported property type: $Type"
        }
    }
}
