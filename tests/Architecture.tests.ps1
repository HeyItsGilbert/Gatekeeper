BeforeAll {
    $modulePath = Join-Path -Path $env:BHProjectPath -ChildPath $env:BHProjectName
}

Describe 'Architecture' {

    Context 'No circular dependencies' {
        It 'No file under Classes/ dot-sources anything under Public/' {
            $classFiles = Get-ChildItem (Join-Path $modulePath 'Classes') -Filter '*.ps1'
            foreach ($file in $classFiles) {
                $content = Get-Content $file.FullName -Raw
                $content | Should -Not -Match '(?m)^(\.\s+[^\r\n]*\\Public\\)' `
                    -Because "$($file.Name) must not depend on Public/"
            }
        }
    }

    Context 'Class pattern consistency' {
        It 'Primary types with a Hashtable constructor also define static FromJson([string]) and FromFile([string])' {
            # FeatureFlag/PropertySet moved from PowerShell `class` definitions to
            # C#-compiled types (Classes/CompiledTypes.ps1) so every runspace under
            # Pester 6 Run.Parallel shares one identical Type instead of each
            # importing runspace compiling its own. The INTENT this test guards -
            # every primary domain type exposes a discoverable static
            # FromJson([string])/FromFile([string]) pair - still applies; it's
            # just verified via reflection against the actual compiled surface now,
            # since that surface no longer exists as PowerShell `class` source text.
            foreach ($typeName in @('FeatureFlag', 'PropertySet')) {
                $type = $typeName -as [type]
                $type | Should -Not -BeNullOrEmpty -Because "$typeName must be a resolvable type"
                $fromJson = $type.GetMethod('FromJson', [Reflection.BindingFlags]'Public,Static', $null, [type[]]@([string]), $null)
                $fromFile = $type.GetMethod('FromFile', [Reflection.BindingFlags]'Public,Static', $null, [type[]]@([string]), $null)
                $fromJson | Should -Not -BeNullOrEmpty -Because "$typeName must have a static FromJson([string]) method"
                $fromFile | Should -Not -BeNullOrEmpty -Because "$typeName must have a static FromFile([string]) method"
            }
        }
    }

    Context 'Effect enum matches configuration' {
        It 'Effect enum values match Configuration.psd1 Logging keys exactly' {
            # Effect moved from a PowerShell `enum` (Enums/Effect.ps1) to a
            # C#-compiled enum (Classes/CompiledTypes.ps1); read its values via
            # reflection on the compiled type instead of grepping file text, which
            # no longer contains the definition.
            $enumValues = [System.Enum]::GetNames([Effect]) | Sort-Object

            $configFile  = Join-Path $modulePath 'Configuration.psd1'
            $configKeys  = (& ([scriptblock]::Create((Get-Content $configFile -Raw)))).Logging.Keys | Sort-Object

            $enumValues | Should -Be $configKeys
        }
    }

    Context 'Manifest pinned exports' {
        It 'FunctionsToExport is not a wildcard' {
            $manifest = Import-PowerShellDataFile (Join-Path $modulePath "$($env:BHProjectName).psd1")
            $manifest.FunctionsToExport | Should -Not -Be '*'
        }
    }
}
