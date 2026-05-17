function Save-PropertySet {
    <#
    .SYNOPSIS
    Save a PropertySet to a file.

    .DESCRIPTION
    Save a PropertySet to a specified file path in JSON format. This cmdlet
    allows you to persist the PropertySet for later use or sharing.

    .PARAMETER PropertySet
    The PropertySet to save.

    .PARAMETER FilePath
    The file path to save the PropertySet to.

    .EXAMPLE
    Save-PropertySet -PropertySet $myPropertySet -FilePath "C:\path\to\file.json"

    Save the PropertySet to a JSON file at the specified path.
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
            Write-Verbose "Saving PropertySet to file: $FilePath"
            $PropertySet.FilePath = $FilePath
        } else {
            Write-Verbose "No FilePath specified, using PropertySet's existing FilePath."
        }
        $PropertySet.Save()
    }
}
