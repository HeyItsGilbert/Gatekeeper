#requires -Module Configuration
function Get-PropertySetFolder {
    <#
    .SYNOPSIS
    Returns the configured directory where property set JSON files are stored.

    .DESCRIPTION
    Retrieves the property set folder path from the active Gatekeeper configuration.
    If no path has been configured, a default location is created under the machine-wide
    configuration path and saved automatically via Export-GatekeeperConfig.

    Use Export-GatekeeperConfig to set the path explicitly and avoid the auto-create
    behavior on first run.

    .OUTPUTS
    System.String

    .EXAMPLE
    $folder = Get-PropertySetFolder
    Get-ChildItem -Path $folder -Filter '*.json'

    Returns the property set folder path and lists all JSON files in it.

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
        if (-not $script:GatekeeperConfiguration.FilePaths.ContainsKey('PropertySet')) {
            Write-Verbose "Property Set folder not set, creating default path..."
            # Set the default flag
            # Uses the Configuration module command to create the path
            $folder = Get-ConfigurationPath -Scope 'Machine'
            $propertySetFolder = Join-Path $folder 'PropertySet'
            if (-not (Test-Path -Path $propertySetFolder)) {
                New-Item -Path $propertySetFolder -ItemType Directory | Out-Null
            }
            $script:GatekeeperConfiguration.FilePaths['PropertySet'] = $propertySetFolder
            # Export the configuration to ensure the new path is saved
            Export-GatekeeperConfig
        }
    }
    process {
        $propertySetFolder = $script:GatekeeperConfiguration.FilePaths.PropertySet
        if (-not (Test-Path -Path $propertySetFolder)) {
            throw "Feature flag folder '$propertySetFolder' does not exist."
        }
    }
    end {
        return $propertySetFolder
    }
}
