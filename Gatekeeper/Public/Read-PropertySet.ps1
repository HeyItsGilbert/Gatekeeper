function Read-PropertySet {
    <#
    .SYNOPSIS
    Read the properties from disk.

    .DESCRIPTION
    Reads the properties json file from disk and convert it to a property set.

    .PARAMETER FilePath
    The file path to the json.

    .EXAMPLE
    Read-PropertySet -FilePath 'C:\foo\properties.json'

    This would return a PropertySet object that contains all of the properties
    to evaluate.
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Generic.List[PropertySet]])]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        $FilePath
    )
    begin {
        $propertySets = [System.Collections.Generic.List[PropertySet]]::new()
    }
    process {
        $propertySets.Add(
            ([PropertySet]::new($FilePath))
        )
    }

    end {
        return $propertySets
    }
}
