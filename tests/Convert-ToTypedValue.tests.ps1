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
Describe 'Convert-ToTypedValue' {
    Context 'Int' {
        It 'can cast an int from an int' {
            InModuleScope $env:BHProjectName {
                Convert-ToTypedValue -Type 'integer' -Value 1 | Should -BeOfType 'Int'
            }
        }
        It 'can cast an int from a string' {
            InModuleScope $env:BHProjectName {
                Convert-ToTypedValue -Type 'integer' -Value "5" | Should -BeOfType 'Int'
            }
        }
    }
    Context 'String' {
        It 'can cast a string' {
            InModuleScope $env:BHProjectName {
                Convert-ToTypedValue -Type 'String' -Value "five" | Should -BeOfType 'String'
            }
        }
        It 'can cast an int as string' {
            InModuleScope $env:BHProjectName {
                Convert-ToTypedValue -Type 'String' -Value 5 | Should -BeOfType 'String'
            }
        }
        It 'can cast a bool as string' {
            InModuleScope $env:BHProjectName {
                Convert-ToTypedValue -Type 'String' -Value $True | Should -BeOfType 'String'
            }
        }
    }
    Context 'Boolean' {
        It 'can cast a $true' {
            InModuleScope $env:BHProjectName {
                Convert-ToTypedValue -Type 'Boolean' -Value $True | Should -BeOfType 'Boolean'
            }
        }
        It 'can cast a "true"' {
            InModuleScope $env:BHProjectName {
                Convert-ToTypedValue -Type 'Boolean' -Value "true" | Should -BeOfType 'Boolean'
            }
        }
        It 'can cast a 0 as False' {
            InModuleScope $env:BHProjectName {
                Convert-ToTypedValue -Type 'Boolean' -Value 0 | Should -BeOfType 'Boolean'
            }
        }
    }
    Context 'Non Valid Types' {
        InModuleScope $env:BHProjectName {
            It 'Should throw on invalid type <_>' -ForEach @(
                'Hashtable', 'Array', 'Null'
            ) {
                { Convert-ToTypedValue -Type $_ -Value 0 } | Should -Throw -ExpectedMessage "Unsupported property type: $_"
            }
        }
    }
}
