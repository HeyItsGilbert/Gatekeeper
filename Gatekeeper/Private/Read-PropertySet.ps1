function Read-PropertySet {
    <#
    .SYNOPSIS
    Read a PropertySet from disk. Private I/O primitive — callers should use Get-PropertySet.
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
