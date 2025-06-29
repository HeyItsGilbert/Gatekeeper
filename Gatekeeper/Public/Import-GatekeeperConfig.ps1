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
        if ($script:GatekeeperConfiguration) {
            Write-Verbose "Using cached Gatekeeper configuration."
        } else {
            Write-Verbose "Loading Gatekeeper configuration from disk."
            $script:GatekeeperConfiguration = Import-Configuration
        }
        # Check if the configuration was imported successfully
        if (-not $script:GatekeeperConfiguration) {
            throw "Failed to import Gatekeeper configuration."
        }

        #region Parse the logging configuration
        if ($script:GatekeeperConfiguration.Logging) {
            Write-Verbose "Parsing logging configuration."
            $script:GatekeeperLogging = @{}
            foreach ($level in $script:GatekeeperConfiguration.Logging.Keys) {
                if (-not $script:GatekeeperConfiguration.Logging[$level].Enabled) {
                    Write-Verbose "Logging level '$level' is disabled, skipping."
                    continue
                }
                # Handle if the script is file or script block
                if ($script:GatekeeperConfiguration.Logging[$level].Script -is [string]) {
                    $scriptPath = $script:GatekeeperConfiguration.Logging[$level].Script
                    if (-not (Test-Path -Path $scriptPath)) {
                        throw "Logging script file not found: $scriptPath"
                    }
                    Write-Verbose "Loading logging script from file: $scriptPath"
                    $script:GatekeeperLogging[$level] = [scriptblock]::Create((Get-Content -Path $scriptPath -Raw))
                } elseif ($script:GatekeeperConfiguration.Logging[$level].Script -is [scriptblock]) {
                    Write-Verbose "Using inline script block for logging level: $level"
                    $script:GatekeeperLogging[$level] = $script:GatekeeperConfiguration.Logging[$level].Script
                } else {
                    Write-Warning "No valid script found for logging level: $level"
                }
            }
        }
        #endregion Parse the logging configuration
    }
    end {
        Write-Verbose "Gatekeeper configuration imported successfully."
        return $script:GatekeeperConfiguration
    }
}
