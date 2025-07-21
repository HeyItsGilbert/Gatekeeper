function Read-FeatureFlag {
    <#
    .SYNOPSIS
    Read a feature flag from disk.

    .DESCRIPTION
    Reads the feature flag json file from disk and convert it to a feature flag
    object.

    .PARAMETER Name
    The name of the feature flag to read from the default feature flag folder
    path.

    .PARAMETER FilePath
    The file path to the json.

    .EXAMPLE
    Read-FeatureFlag -FilePath 'MyFeature.json

    Read the feature from disk.
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
    begin {}
    process {
        if ($PSBoundParameters.ContainsKey('FilePath')) {
            Write-Verbose "Reading FeatureFlag from file: $FilePath"
        } else {
            Write-Verbose "No FilePath specified, using default feature flag folder."
            $folder = Get-FeatureFlagFolder
            $FilePath = Join-Path $folder "$Name.json"
        }
        [FeatureFlag]::FromFile($FilePath)
    }

    end {}
}
