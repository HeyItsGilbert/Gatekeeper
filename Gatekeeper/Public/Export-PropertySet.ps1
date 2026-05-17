function Export-PropertySet {
    <#
    .SYNOPSIS
    Save a PropertySet to a JSON file.

    .DESCRIPTION
    Persists a PropertySet to disk at the specified path, or at the path already
    stored on the PropertySet object.

    .PARAMETER PropertySet
    The PropertySet to export.

    .PARAMETER FilePath
    The file path to write to. Overrides the PropertySet's existing FilePath.

    .EXAMPLE
    Export-PropertySet -PropertySet $myPropertySet -FilePath "C:\props\MySet.json"

    .EXAMPLE
    $myPropertySet | Export-PropertySet
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [PropertySet]
        [PropertySetTransformAttribute()]
        $PropertySet,
        [String]
        $FilePath
    )

    process {
        if ($PSBoundParameters.ContainsKey('FilePath')) {
            Write-Verbose "Exporting PropertySet to file: $FilePath"
            $PropertySet.FilePath = $FilePath
        } else {
            Write-Verbose "No FilePath specified, using PropertySet's existing FilePath."
        }
        $PropertySet.Save()
    }
}
