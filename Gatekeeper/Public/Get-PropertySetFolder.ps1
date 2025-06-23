#requires -Module Configuration
function Get-PropertySetFolder {
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
