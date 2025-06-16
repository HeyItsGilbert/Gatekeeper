function Read-FeatureFlag {
    <#
    .SYNOPSIS
    Read a feature flag from disk.

    .DESCRIPTION
    Reads the feature flag json file from disk and convert it to a feature flag
    object.

    .PARAMETER FilePath
    The file path to the json.

    .EXAMPLE
    Read-FeatureFlag -FilePath 'MyFeature.json

    Read the feature from disk.
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Generic.List[PropertySet]])]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        $FilePath
    )
    begin {
        $featureFlags = [System.Collections.Generic.List[PropertySet]]::new()
    }
    process {
        $featureFlags.Add(
            ([FeatureFlag]::new($FilePath))
        )
    }

    end {
        return $featureFlags
    }
}
