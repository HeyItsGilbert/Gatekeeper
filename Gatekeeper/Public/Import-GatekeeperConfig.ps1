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
                # A logging Script is executed as code with the caller's full
                # privileges. It can be a literal scriptblock (set in-memory) or a
                # string. A string ending in '.ps1' is treated as a path to a local
                # script file; any other string is treated as inline PowerShell code.
                # UNC / remote paths are rejected so the user-writable configuration
                # file cannot pull a payload off the network.
                $scriptContent = $script:GatekeeperConfiguration.Logging[$level].Script
                if ($scriptContent -is [scriptblock]) {
                    Write-Verbose "Using inline script block for logging level: $level"
                    $script:GatekeeperLogging[$level] = $scriptContent
                } elseif ($scriptContent -is [string]) {
                    if ([string]::IsNullOrWhiteSpace($scriptContent)) {
                        Write-Warning "Logging level '$level' has an empty Script value; skipping."
                        continue
                    }
                    if ($scriptContent -match '\.ps1\s*$') {
                        $scriptPath = $scriptContent
                        $parsedUri = $null
                        $isRemotePath = $scriptPath -match '^(\\\\|//)' -or (
                            [System.Uri]::TryCreate($scriptPath, [System.UriKind]::Absolute, [ref]$parsedUri) -and
                            ($parsedUri.IsUnc -or $parsedUri.Scheme -ne 'file')
                        )
                        if ($isRemotePath) {
                            Write-Warning "Logging level '$level' Script path '$scriptPath' is a UNC or remote path; refusing to load it."
                            continue
                        }
                        if (-not (Test-Path -Path $scriptPath -PathType Leaf -ErrorAction SilentlyContinue)) {
                            Write-Warning "Logging level '$level' Script path '$scriptPath' was not found; skipping."
                            continue
                        }
                        Write-Verbose "Loading logging script from file: $scriptPath"
                        $script:GatekeeperLogging[$level] = [scriptblock]::Create((Get-Content -Path $scriptPath -Raw))
                    } else {
                        Write-Verbose "Compiling inline logging script for level: $level"
                        $script:GatekeeperLogging[$level] = [scriptblock]::Create($scriptContent)
                    }
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
