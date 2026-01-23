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
        $config = Import-GatekeeperConfig
    }
    process {
        $logSettings = $config.Logging.$Effect

        if ($logSettings.Enabled) {
            $sb = [scriptblock]::Create($logSettings.Script)
            & $sb -Rule $Rule
        }
    }

}
