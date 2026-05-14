#requires -Module Configuration
function Get-FeatureFlagFolder {
    <#
    .SYNOPSIS
    Returns the configured directory where feature flag JSON files are stored.

    .DESCRIPTION
    Retrieves the feature flag folder path from the active Gatekeeper configuration.
    If no path has been configured, a default location is created under the machine-wide
    configuration path and saved automatically via Export-GatekeeperConfig.

    Use Export-GatekeeperConfig to set the path explicitly and avoid the auto-create
    behavior on first run.

    .OUTPUTS
    System.String

    .EXAMPLE
    $folder = Get-FeatureFlagFolder
    Get-ChildItem -Path $folder -Filter '*.json'

    Returns the feature flag folder path and lists all JSON files in it.

    .NOTES
    On first run, if no path is configured, this function creates the default directory
    and persists the path to configuration automatically.
    #>
    [CmdletBinding()]
    param ()

    begin {
        if ($null -eq $script:GatekeeperConfiguration) {
            Import-GatekeeperConfig
        }
        if (-not $script:GatekeeperConfiguration.FilePaths.ContainsKey('FeatureFlags')) {
            Write-Verbose "Feature flag folder not set, creating default path..."
            # Set the default flag
            # Uses the Configuration module command to create the path
            $folder = Get-ConfigurationPath -Scope 'Machine'
            $featureFlagFolder = Join-Path $folder 'FeatureFlag'
            if (-not (Test-Path -Path $featureFlagFolder)) {
                New-Item -Path $featureFlagFolder -ItemType Directory | Out-Null
            }
            $script:GatekeeperConfiguration.FilePaths['FeatureFlags'] = $featureFlagFolder
            # Export the configuration to ensure the new path is saved
            Export-GatekeeperConfig
        }
    }
    process {
        $featureFlagFolder = $script:GatekeeperConfiguration.FilePaths.FeatureFlags
        if (-not (Test-Path -Path $featureFlagFolder)) {
            throw "Feature flag folder '$featureFlagFolder' does not exist."
        }
    }
    end {
        return $featureFlagFolder
    }
}
