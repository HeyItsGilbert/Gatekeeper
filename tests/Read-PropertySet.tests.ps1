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
Describe 'Read-PropertySet' {
    BeforeAll {
        $script:actual = Read-PropertySet -FilePath "$PSScriptRoot\fixtures\Properties.json"
    }
    It 'Throws file path error' {
        { Read-PropertySet -FilePath 'fakepath.json' } | Should -Throw -ExpectedMessage 'File path given did not exist*'
    }
    It 'Returns a PropertySet object' {
        $script:actual | Should -BeOfType 'PropertySet'
    }
}
