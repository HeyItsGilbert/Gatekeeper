function New-FeatureFlag {
    <#
    .SYNOPSIS
    Create a new feature flag.

    .DESCRIPTION
    Create a new feature flag to export.

    .PARAMETER Name
    The name of the feature flag.

    .PARAMETER Description
    A description of the feature flag.

    .PARAMETER Tags
    Tags associated with the feature flag, useful for categorization.

    .PARAMETER Version
    The version of the feature flag, defaults to "1.0.0".

    .PARAMETER Author
    The author of the feature flag, defaults to the current username.

    .PARAMETER DefaultEffect
    The default effect of the feature flag, which can be Warn, Allow, or Deny. Defaults to Warn.

    .PARAMETER Rules
    A list of rules that define the conditions under which the feature flag is applied.

    .PARAMETER FilePath
    The file path where the feature flag will be saved. If not specified, it
    will be saved in the default feature flag folder. This is usually preferred.

    .EXAMPLE
    $featureFlag = New-FeatureFlag -Name 'MyFeatureFlag'

    This would create a new feature flag object with the specified name.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([FeatureFlag])]
    param (
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [String]
        $Name,
        [Parameter(Position = 1)]
        [ValidateNotNullOrEmpty()]
        [String]
        $Description = "Feature flag for $Name",
        [string[]]
        $Tags,
        [version]
        $Version = [version]"1.0.0",
        [string]
        $Author = $env:USERNAME,
        [Effect]
        $DefaultEffect = [Effect]::Warn,
        [Parameter(Mandatory, ValueFromPipeline)]
        [Rule[]]
        $Rules = @(),
        [ValidateScript({
                if (-not (Test-Path $_)) {
                    New-Item -Path $_ -ItemType Directory -Force | Out-Null
                }
                return $true
            })]
        [String]
        $FilePath = $null
    )
    begin {
        $featureFlag = [FeatureFlag]::new()
        $featureFlag.Name = $Name
        $featureFlag.Description = $Description
        $featureFlag.Version = $Version
        $featureFlag.Author = $Author
        $featureFlag.DefaultEffect = $DefaultEffect
        $featureFlag.Tags = $Tags
        $folder = Get-FeatureFlagFolder
        if (-not $FilePath) {
            Write-Verbose "No file path specified, using default folder: $folder"
            $fullPath = Join-Path $folder "$($Name).json"
        } else {
            Write-Verbose "Using specified file path: $FilePath"
            $fullPath = Resolve-Path $FilePath
        }
        $featureFlag.FilePath = $fullPath
    }
    process {
        foreach ($rule in $Rules) {
            if ($PSCmdlet.ShouldProcess($rule.Name, "Add rule: $($rule.Description)")) {
                $featureFlag.Rules += $rule
            }
        }
    }
    end {
        return $featureFlag
    }
}
