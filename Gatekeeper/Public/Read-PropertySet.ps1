function Read-PropertySet {
    <#
    .SYNOPSIS
    Read the properties from disk.

    .DESCRIPTION
    Reads the properties json file from disk and convert it to a property set.

    .PARAMETER Name
    The name of the property set to read from the default property set folder
    path.

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
        [Parameter(Mandatory, Position = 0, ParameterSetName = 'ByName')]
        [ValidateNotNullOrEmpty()]
        [String]
        $Name,
        [Parameter(Mandatory, ValueFromPipeline, ParameterSetName = 'ByFilePath')]
        $FilePath
    )
    begin {
        $propertySets = [System.Collections.Generic.List[PropertySet]]::new()
    }
    process {
        if ($PSBoundParameters.ContainsKey('FilePath')) {
            Write-Verbose "Reading PropertySet from file: $FilePath"
        } else {
            Write-Verbose "No FilePath specified, using default property set folder."
            $folder = Get-PropertySetFolder
            $FilePath = Join-Path $folder "$Name.json"
        }
        foreach ($file in $FilePath) {
            $propertySets.Add(
                ([PropertySet]::FromFile($file))
            )
        }
    }

    end {
        return $propertySets
    }
}
