function ConvertTo-Hashtable {
    <#
    .SYNOPSIS
    Recursively converts PSCustomObject to Hashtable for PowerShell 5.1 compatibility.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowNull()]
        [object]$InputObject
    )

    if ($null -eq $InputObject) {
        return $null
    }

    if ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string]) {
        $collection = @(
            foreach ($item in $InputObject) {
                ConvertTo-Hashtable -InputObject $item
            }
        )
        return $collection
    }

    if ($InputObject -is [PSCustomObject]) {
        $hashtable = @{}
        foreach ($property in $InputObject.PSObject.Properties) {
            $hashtable[$property.Name] = ConvertTo-Hashtable -InputObject $property.Value
        }
        return $hashtable
    }

    return $InputObject
}
