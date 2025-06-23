#requires -Module Configuration
function Get-FeatureFlagFolder {
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
