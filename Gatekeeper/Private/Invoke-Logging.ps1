function Invoke-Logging {
    param (
        [Parameter(Mandatory)]
        [Effect]
        $Effect,
        [Parameter(Mandatory)]
        [Rule]
        $Rule
    )
    begin {
        # Ensure the configuration (and the pre-parsed logging scriptblocks) are loaded.
        $null = Import-GatekeeperConfig
    }
    process {
        if (-not $script:GatekeeperLogging) {
            return
        }
        # Use the scriptblock already parsed and validated by Import-GatekeeperConfig.
        # Re-creating it here from the raw config would re-introduce the double-parse
        # and bypass that validation.
        $logScript = $script:GatekeeperLogging[[string]$Effect]
        if (-not $logScript) {
            return
        }
        & $logScript -Rule $Rule
    }

}
