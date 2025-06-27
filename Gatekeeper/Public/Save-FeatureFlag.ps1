function Save-FeatureFlag {
    <#
    .SYNOPSIS
    Save a FeatureFlag to a file.

    .DESCRIPTION
    Save a FeatureFlag to a specified file path in JSON format. This cmdlet
    allows you to persist the FeatureFlag for later use or sharing.

    .PARAMETER FeatureFlag
    The FeatureFlag to save.

    .PARAMETER FilePath
    The file path to save the FeatureFlag to.

    .EXAMPLE
    Save-FeatureFlag -FeatureFlag $myFeatureFlag -FilePath "C:\path\to\file.json"

    Save the FeatureFlag to a JSON file at the specified path.
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
            Write-Verbose "Saving FeatureFlag to file: $FilePath"
            $FeatureFlag.FilePath = $FilePath
        } else {
            Write-Verbose "No FilePath specified, using FeatureFlag's existing FilePath."
        }
        $FeatureFlag.Save()
    }
}
