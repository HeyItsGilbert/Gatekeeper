function ConvertFrom-JsonToHashtable {
    <#
    .SYNOPSIS
    Converts JSON to a hashtable with PowerShell 5.1 compatibility.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$InputObject
    )

    process {
        if ($PSVersionTable.PSVersion.Major -ge 7) {
            return ($InputObject | ConvertFrom-Json -AsHashtable)
        }
        $jsonObject = $InputObject | ConvertFrom-Json
        return ConvertTo-Hashtable -InputObject $jsonObject
    }
}
