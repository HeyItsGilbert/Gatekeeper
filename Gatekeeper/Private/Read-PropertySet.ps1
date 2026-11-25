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
            # PropertySet.FromFile is now a C#-compiled method (not a
            # PowerShell `class` method), so PowerShell wraps any exception it
            # throws in a MethodInvocationException when called directly like
            # this. Unwrap it so callers (and existing error-message
            # contracts/tests) keep seeing the original, unwrapped message.
            try {
                $propertySets.Add(([PropertySet]::FromFile($file)))
            } catch {
                if ($_.Exception.InnerException) {
                    throw $_.Exception.InnerException.Message
                }
                throw
            }
        }
    }
    end {
        return $propertySets
    }
}
