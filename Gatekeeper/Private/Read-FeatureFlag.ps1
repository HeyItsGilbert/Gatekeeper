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
        # FeatureFlag.FromFile is now a C#-compiled method (not a PowerShell
        # `class` method), so PowerShell wraps any exception it throws in a
        # MethodInvocationException when called directly like this. Unwrap it
        # so callers (and existing error-message contracts/tests) keep seeing
        # the original, unwrapped message.
        try {
            [FeatureFlag]::FromFile($FilePath)
        } catch {
            if ($_.Exception.InnerException) {
                throw $_.Exception.InnerException.Message
            }
            throw
        }
    }
    end {}
}
