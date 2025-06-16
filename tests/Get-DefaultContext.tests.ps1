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
Describe 'Get-DefaultContext' {
    BeforeAll {
        $propertySet = Read-PropertySet -File "$PSScriptRoot\fixtures\Properties.json"
        $script:actual = Get-DefaultContext -Properties $propertySet
    }
    It 'Returns a hashtable' {
        $actual | Should -BeOfType 'Hashtable'
    }
    It 'Contains the Key: <_>' -ForEach @('Percentage', 'Environment', 'IsCompliant') {
        $actual.ContainsKey($_) | Should -BeTrue
    }
    It 'Does not contain the $schema item' {
        $actual.ContainsKey('$schema') | Should -BeFalse
    }
}
