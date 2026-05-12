BeforeDiscovery {
    $manifest = Import-PowerShellDataFile -Path $env:BHPSModuleManifest
    $outputDir = Join-Path -Path $env:BHProjectPath -ChildPath 'Output'
    $outputModDir = Join-Path -Path $outputDir -ChildPath $env:BHProjectName
    $outputModVerDir = Join-Path -Path $outputModDir -ChildPath $manifest.ModuleVersion
    $outputModVerManifest = Join-Path -Path $outputModVerDir -ChildPath "$($env:BHProjectName).psd1"

    # Remove all versions of the module from the session. Pester can't handle multiple versions.
    Get-Module $env:BHProjectName | Remove-Module -Force -ErrorAction Ignore
    Import-Module -Name $outputModVerManifest -Verbose:$false -ErrorAction Stop
}
Describe 'Test-TypedValue' {
    Context 'WithPropertyDefinition parameter set' {
        It 'delegates to PropertyDefinition.Validate for a valid value' {
            InModuleScope $env:BHProjectName {
                $prop = [PropertyDefinition]::new('Score', @{ Type = 'integer'; Validation = @{ Minimum = 1; Maximum = 10 } })
                { Test-TypedValue -PropertyDefinition $prop -Value 5 } | Should -Not -Throw
            }
        }
        It 'delegates to PropertyDefinition.Validate and does not throw for an invalid value' {
            InModuleScope $env:BHProjectName {
                $prop = [PropertyDefinition]::new('Score', @{ Type = 'integer'; Validation = @{ Minimum = 1; Maximum = 10 } })
                { Test-TypedValue -PropertyDefinition $prop -Value 0 } | Should -Not -Throw
            }
        }
    }
    Context 'WithOutPropertyDefinition parameter set - integer constraints' {
        It 'throws when value is below Minimum' {
            InModuleScope $env:BHProjectName {
                $validation = @{ Minimum = 1; Maximum = 10 }
                { Test-TypedValue -Type 'integer' -Name 'Score' -Validation $validation -Value 0 } | Should -Throw
            }
        }
        It 'throws when value is above Maximum' {
            InModuleScope $env:BHProjectName {
                $validation = @{ Minimum = 1; Maximum = 10 }
                { Test-TypedValue -Type 'integer' -Name 'Score' -Validation $validation -Value 11 } | Should -Throw
            }
        }
        It 'passes when value is within range' {
            InModuleScope $env:BHProjectName {
                $validation = @{ Minimum = 1; Maximum = 10 }
                { Test-TypedValue -Type 'integer' -Name 'Score' -Validation $validation -Value 5 } | Should -Not -Throw
            }
        }
    }
    Context 'WithOutPropertyDefinition parameter set - string constraints' {
        It 'throws when value is shorter than MinLength' {
            InModuleScope $env:BHProjectName {
                $validation = @{ MinLength = 5 }
                { Test-TypedValue -Type 'string' -Name 'Tag' -Validation $validation -Value 'abc' } | Should -Throw
            }
        }
        It 'throws when value is longer than MaxLength' {
            InModuleScope $env:BHProjectName {
                $validation = @{ MaxLength = 5 }
                { Test-TypedValue -Type 'string' -Name 'Tag' -Validation $validation -Value 'toolongstring' } | Should -Throw
            }
        }
        It 'throws when value does not match Pattern' {
            InModuleScope $env:BHProjectName {
                $validation = @{ Pattern = '^[a-z]+$' }
                { Test-TypedValue -Type 'string' -Name 'Tag' -Validation $validation -Value 'ABC123' } | Should -Throw
            }
        }
        It 'passes when value matches Pattern' {
            InModuleScope $env:BHProjectName {
                $validation = @{ Pattern = '^[a-z]+$' }
                { Test-TypedValue -Type 'string' -Name 'Tag' -Validation $validation -Value 'abc' } | Should -Not -Throw
            }
        }
    }
    Context 'WithPropertyDefinition parameter set - no validation configured' {
        It 'returns cleanly when PropertyDefinition has no Validation set' {
            InModuleScope $env:BHProjectName {
                $prop = [PropertyDefinition]::new('Score', @{ Type = 'integer' })
                { Test-TypedValue -PropertyDefinition $prop -Value 999 } | Should -Not -Throw
            }
        }
    }
}
