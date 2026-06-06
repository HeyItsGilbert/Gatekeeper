BeforeDiscovery {
    $manifest = Import-PowerShellDataFile -Path $env:BHPSModuleManifest
    $outputDir = Join-Path -Path $env:BHProjectPath -ChildPath 'Output'
    $outputModDir = Join-Path -Path $outputDir -ChildPath $env:BHProjectName
    $outputModVerDir = Join-Path -Path $outputModDir -ChildPath $manifest.ModuleVersion
    $outputModVerManifest = Join-Path -Path $outputModVerDir -ChildPath "$($env:BHProjectName).psd1"

    Get-Module $env:BHProjectName | Remove-Module -Force -ErrorAction Ignore
    Import-Module -Name $outputModVerManifest -Verbose:$false -ErrorAction Stop
}
Describe 'Read-FeatureFlag' {
    BeforeAll {
        $fixturePath = "$PSScriptRoot\fixtures\FeatureFlag.json"
        $script:actual = InModuleScope $env:BHProjectName -Parameters @{ Path = $fixturePath } {
            param($Path)
            Read-FeatureFlag -FilePath $Path
        }
    }
    It 'Throws file path error' {
        { InModuleScope $env:BHProjectName { Read-FeatureFlag -FilePath 'fakePath.json' } } |
            Should -Throw -ExpectedMessage 'File not found: fakePath.json'
    }
    It 'Returns a FeatureFlag object' {
        $script:actual | Should -BeOfType 'FeatureFlag'
    }
    It 'Has the correct property: <_.Name>' -ForEach @(
        @{ Name = 'Name'; Type = 'String'; Value = 'New Startup Sound' },
        @{ Name = 'Description'; Type = 'String'; Value = 'Roll out new screaming goat start up sound.' },
        @{ Name = 'Tags'; Type = 'String'; Value = @('Goat', 'Managed') },
        @{ Name = 'DefaultEffect'; Type = 'Effect'; Value = "Deny" }
    ) {
        $script:actual.$($_.Name) | Should -BeOfType $_.Type
        $script:actual.$($_.Name) | Should -Be $_.Value
    }
}
