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
        $requirements = Import-PowerShellDataFile -Path ./requirements.psd1

        $psDependVersion = $requirements.PSDepend.Version
        $psDependPrerelease = ($psDependVersion -split '-', 2)[1]
        $matchPSDepend = {
            Get-Module -Name PSDepend -ListAvailable | Where-Object {
                $candidateVersion = "$($_.Version)"
                if ($_.PrivateData.PSData.Prerelease) { $candidateVersion += "-$($_.PrivateData.PSData.Prerelease)" }
                $candidateVersion -eq $psDependVersion
            } | Select-Object -First 1
        }
        $psDependModule = & $matchPSDepend
        if (-not $psDependModule) {
            $psDependInstallParams = @{ RequiredVersion = $psDependVersion }
            if ($psDependPrerelease) { $psDependInstallParams.AllowPrerelease = $true }
            Install-Module -Name PSDepend -Repository PSGallery -Scope CurrentUser -Force @psDependInstallParams
            $psDependModule = & $matchPSDepend
        }
        # Import by the matched module's own manifest path, not just its numeric base version:
        # -RequiredVersion drops the prerelease label, so if a differently-labeled (or stable)
        # module sharing that same numeric version ever appears earlier on $env:PSModulePath,
        # Import-Module could resolve to that one instead of the prerelease actually pinned.
        Import-Module -Name $psDependModule.Path -Verbose:$false

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
        $pesterVersion = $requirements.Pester.Version
        if (-not (Get-Module -Name Pester -ListAvailable | Where-Object Version -eq [version]$pesterVersion)) {
            Install-Module -Name Pester -RequiredVersion $pesterVersion -Scope CurrentUser -Force -SkipPublisherCheck
        }
        Import-Module -Name Pester -RequiredVersion $pesterVersion -Global -Force -Verbose:$false

        # Invoke-PSDepend's own PSGalleryModule handler compares an installed module's
        # $_.Version.ToString() (which drops any prerelease label) against the full
        # 'X.Y.Z-prerelease' requirement string above, so it never recognizes our pin as already
        # satisfied and would redundantly re-query/reinstall PSDepend from the gallery on every
        # single bootstrap run. We've already installed and imported the exact pinned version
        # above, so hand Invoke-PSDepend every *other* declared dependency instead of
        # reprocessing this self-referential entry.
        $otherDependencies = $requirements.Clone()
        $otherDependencies.Remove('PSDepend')
        Invoke-PSDepend -InputObject $otherDependencies -Install -Import -Force -WarningAction SilentlyContinue

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
