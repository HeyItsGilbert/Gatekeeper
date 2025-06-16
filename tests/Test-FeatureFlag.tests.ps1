BeforeDiscovery {
    $manifest = Import-PowerShellDataFile -Path $env:BHPSModuleManifest
    $outputDir = Join-Path -Path $env:BHProjectPath -ChildPath 'Output'
    $outputModDir = Join-Path -Path $outputDir -ChildPath $env:BHProjectName
    $outputModVerDir = Join-Path -Path $outputModDir -ChildPath $manifest.ModuleVersion
    $outputModVerManifest = Join-Path -Path $outputModVerDir -ChildPath "$($env:BHProjectName).psd1"

    # Get module commands
    # Remove all versions of the module from the session. Pester can't handle multiple versions.
    Get-Module $env:BHProjectName | Remove-Module -Force -ErrorAction Ignore
    Import-Module -Name $outputModVerManifest -Verbose:$false -ErrorAction Stop
}
Describe 'Test-FeatureFlag' {
    BeforeAll {
        $script:propertySet = Read-PropertySet -File "$PSScriptRoot\fixtures\Properties.json"
        $script:context = @{
            Percentage = 30
            Environment = 'Production'
            IsCompliant = $true
        }
        # load feature flag
        $json = Get-Content -Path "$PSScriptRoot\fixtures\Updawg.json" -Raw | ConvertFrom-Json -AsHashtable
    }
}
