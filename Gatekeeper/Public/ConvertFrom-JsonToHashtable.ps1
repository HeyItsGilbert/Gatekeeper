function ConvertFrom-JsonToHashtable {
    <#
    .SYNOPSIS
    Converts JSON to a hashtable with PowerShell 5.1 compatibility.

    .DESCRIPTION
    Provides a compatibility layer for converting JSON to hashtables that works
    with both PowerShell 5.1 and PowerShell 7+. In PowerShell 7+, uses the native
    -AsHashtable parameter. In PowerShell 5.1, manually converts PSCustomObject
    to hashtable.

    .PARAMETER InputObject
    The JSON string to convert or pipeline input from Get-Content.

    .EXAMPLE
    $json = Get-Content -Path "file.json" -Raw | ConvertFrom-JsonToHashtable

    .EXAMPLE
    $data = ConvertFrom-JsonToHashtable -InputObject '{"key":"value"}'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$InputObject
    )

    process {
        # In PowerShell 7+, ConvertFrom-Json supports -AsHashtable
        if ($PSVersionTable.PSVersion.Major -ge 7) {
            return ($InputObject | ConvertFrom-Json -AsHashtable)
        }

        # For PowerShell 5.1, we need to manually convert PSCustomObject to Hashtable
        $jsonObject = $InputObject | ConvertFrom-Json
        return ConvertTo-Hashtable -InputObject $jsonObject
    }
}

function ConvertTo-Hashtable {
    <#
    .SYNOPSIS
    Recursively converts PSCustomObject to Hashtable.

    .DESCRIPTION
    Helper function that recursively converts PSCustomObject instances to hashtables.
    Used for PowerShell 5.1 compatibility where ConvertFrom-Json doesn't support -AsHashtable.

    .PARAMETER InputObject
    The object to convert to a hashtable.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
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

    # Return primitive types as-is
    return $InputObject
}
