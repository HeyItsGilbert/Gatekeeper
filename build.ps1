[cmdletbinding(DefaultParameterSetName = 'Task')]
param(
    # Build task(s) to execute
    [parameter(ParameterSetName = 'task', position = 0)]
    [ArgumentCompleter( {
        param($Command, $Parameter, $WordToComplete, $CommandAst, $FakeBoundParams)
        $psakeFile = './psakeFile.ps1'
        switch ($Parameter) {
            'Task' {
                $plan = Get-PsakeBuildPlan -BuildFile $psakeFile
                $names = $plan.TaskMap.Keys
                if ([string]::IsNullOrEmpty($WordToComplete)) {
                    $names
                }
                else {
                    $names | Where-Object { $_ -match $WordToComplete }
                }
            }
            Default {
            }
        }
    })]
    [string[]]$Task = 'Default',

    # Bootstrap dependencies
    [switch]$Bootstrap,

    # List available build tasks
    [parameter(ParameterSetName = 'Help')]
    [switch]$Help,

    # Optional properties to pass to psake
    [hashtable]$Properties,

    # Optional parameters to pass to psake
    [hashtable]$Parameters,

    # Output format for psake. Valid values: Default, Quiet, JSON, GitHubActions.
    # LLMs and automated callers should prefer 'Quiet' — it suppresses console noise
    # and returns a structured PsakeBuildResult object instead of printing to the host.
    [ValidateSet('Default', 'Quiet', 'JSON', 'GitHubActions')]
    [string]$OutputFormat = 'Default'
)

$ErrorActionPreference = 'Stop'

# Bootstrap dependencies
if ($Bootstrap.IsPresent) {
    Get-PackageProvider -Name Nuget -ForceBootstrap | Out-Null
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
    if ((Test-Path -Path ./requirements.psd1)) {
        if (-not (Get-Module -Name PSDepend -ListAvailable)) {
            Install-Module -Name PSDepend -Repository PSGallery -Scope CurrentUser -Force
        }
        Import-Module -Name PSDepend -Verbose:$false
        Invoke-PSDepend -Path './requirements.psd1' -Install -Import -Force -WarningAction SilentlyContinue
    } else {
        Write-Warning 'No [requirements.psd1] found. Skipping build dependency installation.'
    }
}

# Execute psake task(s)
$psakeFile = './psakeFile.ps1'
if ($PSCmdlet.ParameterSetName -eq 'Help') {
    $plan = Get-PsakeBuildPlan -BuildFile $psakeFile
    $plan.TaskMap.Values | Select-Object Name, Description, DependsOn |
        Format-Table -AutoSize
} else {
    Set-BuildEnvironment -Force
    $psakeParams = @{
        buildFile   = $psakeFile
        taskList    = $Task
        nologo      = $true
        properties  = $Properties
        parameters  = $Parameters
    }
    if ($OutputFormat -eq 'Quiet') {
        $psakeParams['Quiet'] = $true
    } elseif ($OutputFormat -ne 'Default') {
        $psakeParams['OutputFormat'] = $OutputFormat
    }
    $result = Invoke-psake @psakeParams
    $result
    exit ([int](-not $result.Success))
}
