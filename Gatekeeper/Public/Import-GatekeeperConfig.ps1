function Import-GatekeeperConfig {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [switch]
        $ForceReload
    )

    begin {
        if (-not $script:GatekeeperConfiguration) {
            Write-Verbose "Gatekeeper configuration not loaded, importing..."
        }
        if ($ForceReload -and $script:GatekeeperConfiguration) {
            Write-Verbose "Forcing reload of Gatekeeper configuration."
            $script:GatekeeperConfiguration = $null
        }
    }
    process {
        $script:GatekeeperConfiguration = Import-Configuration
        if (-not $script:GatekeeperConfiguration) {
            throw "Failed to import Gatekeeper configuration."
        }
    }
    end {
        Write-Verbose "Gatekeeper configuration imported successfully."
        return $script:GatekeeperConfiguration
    }
}
