function Export-FeatureFlag {
    <#
    .SYNOPSIS
    Save a FeatureFlag to a JSON file.

    .DESCRIPTION
    Persists a FeatureFlag to disk at the specified path, or at the path already
    stored on the FeatureFlag object.

    .PARAMETER FeatureFlag
    The FeatureFlag to export.

    .PARAMETER FilePath
    The file path to write to. Overrides the FeatureFlag's existing FilePath.

    .EXAMPLE
    Export-FeatureFlag -FeatureFlag $myFeatureFlag -FilePath "C:\flags\MyFeature.json"

    Saves the feature flag to the specified path.

    .EXAMPLE
    $myFeatureFlag | Export-FeatureFlag

    Saves the feature flag to the path stored on the object.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [FeatureFlag]
        [FeatureFlagTransformAttribute()]
        $FeatureFlag,
        [String]
        $FilePath
    )

    process {
        if ($PSBoundParameters.ContainsKey('FilePath')) {
            Write-Verbose "Exporting FeatureFlag to file: $FilePath"
            $FeatureFlag.FilePath = $FilePath
        } else {
            Write-Verbose "No FilePath specified, using FeatureFlag's existing FilePath."
        }
        $FeatureFlag.Save()
    }
}
