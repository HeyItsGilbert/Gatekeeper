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
                # Handle if the script is a file path or string scriptblock
                $scriptContent = $script:GatekeeperConfiguration.Logging[$level].Script
                if ($scriptContent -is [string]) {
                    # Check if it's a file path
                    if (Test-Path -Path $scriptContent -ErrorAction SilentlyContinue) {
                        Write-Verbose "Loading logging script from file: $scriptContent"
                        $script:GatekeeperLogging[$level] = [scriptblock]::Create((Get-Content -Path $scriptContent -Raw))
                    } else {
                        # Treat it as a script string and convert to scriptblock
                        Write-Verbose "Converting string to script block for logging level: $level"
                        $script:GatekeeperLogging[$level] = [scriptblock]::Create($scriptContent)
                    }
                } elseif ($scriptContent -is [scriptblock]) {
                    Write-Verbose "Using inline script block for logging level: $level"
                    $script:GatekeeperLogging[$level] = $scriptContent
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
