function Read-FeatureFlag {
    <#
    .SYNOPSIS
    Read a FeatureFlag from disk. Private I/O primitive — callers should use Get-FeatureFlag.
    #>
    [CmdletBinding()]
    [OutputType([FeatureFlag])]
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
