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

    It 'contains all expected property keys from the fixture' {
        $script:actual.Properties.ContainsKey('Percentage') | Should -BeTrue
        $script:actual.Properties.ContainsKey('Environment') | Should -BeTrue
        $script:actual.Properties.ContainsKey('IsCompliant') | Should -BeTrue
    }

    It 'loads property types correctly' {
        $script:actual.Properties['Percentage'].Type | Should -Be 'integer'
        $script:actual.Properties['Environment'].Type | Should -Be 'string'
        $script:actual.Properties['IsCompliant'].Type | Should -Be 'boolean'
    }

    It 'loads validation constraints for integer properties' {
        $validation = $script:actual.Properties['Percentage'].Validation
        $validation | Should -Not -BeNullOrEmpty
        $validation.Minimum | Should -Be 0
        $validation.Maximum | Should -Be 99
    }

    It 'loads enum values for string properties' {
        $enum = $script:actual.Properties['Environment'].Enum
        $enum | Should -Not -BeNullOrEmpty
        $enum | Should -Contain 'Production'
        $enum | Should -Contain 'Staging'
        $enum | Should -Contain 'Dev'
    }
}
