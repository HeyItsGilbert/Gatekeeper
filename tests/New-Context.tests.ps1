BeforeDiscovery {
    $manifest = Import-PowerShellDataFile -Path $env:BHPSModuleManifest
    $outputDir = Join-Path -Path $env:BHProjectPath -ChildPath 'Output'
    $outputModDir = Join-Path -Path $outputDir -ChildPath $env:BHProjectName
    $outputModVerDir = Join-Path -Path $outputModDir -ChildPath $manifest.ModuleVersion
    $outputModVerManifest = Join-Path -Path $outputModVerDir -ChildPath "$($env:BHProjectName).psd1"

    Get-Module $env:BHProjectName | Remove-Module -Force -ErrorAction Ignore
    Import-Module -Name $outputModVerManifest -Verbose:$false -ErrorAction Stop
}
Describe 'New-Context' {
    BeforeAll {
        $fixturePath = "$PSScriptRoot\fixtures\Properties.json"
        $propertySet = InModuleScope $env:BHProjectName -Parameters @{ Path = $fixturePath } {
            param($Path)
            Read-PropertySet -FilePath $Path
        }
        $script:actual = New-Context -PropertySet $propertySet
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
    It 'All values are $null' {
        $actual.Values | ForEach-Object { $_ | Should -BeNullOrEmpty }
    }
}
