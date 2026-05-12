BeforeDiscovery {
    $manifest = Import-PowerShellDataFile -Path $env:BHPSModuleManifest
    $outputDir = Join-Path -Path $env:BHProjectPath -ChildPath 'Output'
    $outputModDir = Join-Path -Path $outputDir -ChildPath $env:BHProjectName
    $outputModVerDir = Join-Path -Path $outputModDir -ChildPath $manifest.ModuleVersion
    $outputModVerManifest = Join-Path -Path $outputModVerDir -ChildPath "$($env:BHProjectName).psd1"

    Get-Module $env:BHProjectName -All | Remove-Module -Force -ErrorAction Ignore
    Get-Module 'Configuration' -All | Remove-Module -Force -ErrorAction Ignore
    Import-Module -Name $outputModVerManifest -Verbose:$false -ErrorAction Stop
}

Describe 'ConvertFrom-JsonToHashtable' {
    It 'converts a JSON object to a hashtable with correct keys' {
        $result = ConvertFrom-JsonToHashtable -InputObject '{"key":"value","count":42}'
        $result | Should -BeOfType [hashtable]
        $result['key'] | Should -Be 'value'
        $result['count'] | Should -Be 42
    }

    It 'converts nested JSON objects to nested hashtables' {
        $result = ConvertFrom-JsonToHashtable -InputObject '{"outer":{"inner":"data"}}'
        $result['outer'] | Should -BeOfType [hashtable]
        $result['outer']['inner'] | Should -Be 'data'
    }

    It 'converts a JSON array to an array' {
        $result = ConvertFrom-JsonToHashtable -InputObject '[1,2,3]'
        $result | Should -HaveCount 3
        $result[0] | Should -Be 1
        $result[2] | Should -Be 3
    }

    It 'throws on invalid JSON' {
        { ConvertFrom-JsonToHashtable -InputObject 'not valid json {{{' } | Should -Throw
    }
}
