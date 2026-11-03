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
        $psDependVersion = (Import-PowerShellDataFile -Path ./requirements.psd1).PSDepend.Version
        $psDependBaseVersion, $psDependPrerelease = $psDependVersion -split '-', 2
        $psDependInstalled = Get-Module -Name PSDepend -ListAvailable | Where-Object {
            $candidateVersion = "$($_.Version)"
            if ($_.PrivateData.PSData.Prerelease) { $candidateVersion += "-$($_.PrivateData.PSData.Prerelease)" }
            $candidateVersion -eq $psDependVersion
        }
        if (-not $psDependInstalled) {
            $psDependInstallParams = @{ RequiredVersion = $psDependVersion }
            if ($psDependPrerelease) { $psDependInstallParams.AllowPrerelease = $true }
            Install-Module -Name PSDepend -Repository PSGallery -Scope CurrentUser -Force @psDependInstallParams
        }
        Import-Module -Name PSDepend -RequiredVersion $psDependBaseVersion -Verbose:$false

        # PowerShellBuild (installed below via requirements.psd1) declares `Pester >= 5.6.1` as
        # its own RequiredModules dependency, with no upper bound. Install-Module always
        # auto-resolves a target's RequiredModules, independently of whatever this repo's own
        # `Pester` entry pins - and if our pin isn't on disk yet when PowerShellBuild gets
        # installed, PowerShellGet fetches whatever's newest on PSGallery as a second, stray
        # copy. PowerShellBuild's bundled Test task later calls `Import-Module Pester
        # -MinimumVersion 5.0.0` (no exact pin), which always resolves to the HIGHEST matching
        # version found on $env:PSModulePath - not whatever's already loaded - so that stray
        # copy collides with the Pester.dll our own pinned import already loaded in-process.
        # Installing (and importing) our pin first means PowerShellGet already finds it
        # satisfying PowerShellBuild's constraint and never reaches for anything else.
        $pesterVersion = (Import-PowerShellDataFile -Path ./requirements.psd1).Pester.Version
        if (-not (Get-Module -Name Pester -ListAvailable | Where-Object Version -eq [version]$pesterVersion)) {
            Install-Module -Name Pester -RequiredVersion $pesterVersion -Scope CurrentUser -Force -SkipPublisherCheck
        }
        Import-Module -Name Pester -RequiredVersion $pesterVersion -Global -Force -Verbose:$false

        Invoke-PSDepend -Path './requirements.psd1' -Install -Import -Force -WarningAction SilentlyContinue

        # Defense in depth: prune any stray Pester version that still slipped onto disk (e.g. a
        # concurrent PSDepend install) and reassert our pin at global scope.
        Get-Module -Name Pester -ListAvailable | Where-Object { $_.Version -ne [version]$pesterVersion } |
            ForEach-Object { Remove-Item -LiteralPath $_.ModuleBase -Recurse -Force -ErrorAction SilentlyContinue }
        Import-Module -Name Pester -RequiredVersion $pesterVersion -Global -Force -Verbose:$false
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
