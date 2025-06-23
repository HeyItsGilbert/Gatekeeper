#requires -Module Configuration
function Export-GatekeeperConfig {
    <#
    .SYNOPSIS
    Exports the Gatekeeper configuration to disk.

    .DESCRIPTION
    This cmdlet exports the current Gatekeeper configuration to a specified
    scope (Enterprise, User, or Machine).


    .PARAMETER ConfigurationScope
    The scope to which the configuration should be exported.
    Valid values are 'Enterprise', 'User', or 'Machine'. Default is 'Machine'.

    .PARAMETER Configuration
    Use this override the default configuration with a custom hashtable. It is
    recommended to get the configuration using the Import-GatekeeperConfig
    cmdlet before using this parameter to ensure you don't lose any existing
    settings.

    .EXAMPLE
    Export-GatekeeperConfig -ConfigurationScope 'Machine'

    Exports the Gatekeeper configuration to the Machine scope.

    .EXAMPLE
    Export-GatekeeperConfig -ConfigurationScope 'User' -Configuration $customConfig

    Exports the Gatekeeper configuration to the User scope using a custom configuration
    hashtable.
    #>
    [CmdletBinding()]
    param (
        [ValidateSet('Enterprise', 'User', 'Machine')]
        $ConfigurationScope = 'Machine',
        [hashtable]
        $Configuration
    )

    begin {
        if (-not $script:GatekeeperConfiguration) {
            Import-GatekeeperConfig
        }
    }

    process {
        # Export the config using the Configuration module's Export-Config cmdlet
        if (-not $script:GatekeeperConfiguration) {
            throw "Gatekeeper configuration is not loaded. Please import it first."
        }
        $script:GatekeeperConfiguration.LastUpdated = Get-Date
        $script:GatekeeperConfiguration | Export-Configuration -Scope $ConfigurationScope -CompanyName 'Gilbert Sanchez' -Name 'Gatekeeper'
    }

    end {
        Write-Verbose "Gatekeeper configuration exported successfully."
    }
}
