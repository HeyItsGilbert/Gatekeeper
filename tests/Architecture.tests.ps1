BeforeAll {
    $modulePath = Join-Path -Path $env:BHProjectPath -ChildPath $env:BHProjectName
    # The 'Class pattern consistency' and 'Effect enum matches configuration'
    # contexts below resolve [Effect]/'FeatureFlag' -as [type] via reflection
    # against the compiled module types, unlike the original text-grepping
    # version of this file, which never needed the module imported at all.
    # Import explicitly so this file is correct in isolation, matching every
    # other test file's own import, rather than relying on some other file
    # (or the build's own GenerateMarkdown/BuildHelp steps) having already
    # imported it earlier in this process.
    $manifest = Import-PowerShellDataFile -Path $env:BHPSModuleManifest
    $outputDir = Join-Path -Path $env:BHProjectPath -ChildPath 'Output'
    $outputModDir = Join-Path -Path $outputDir -ChildPath $env:BHProjectName
    $outputModVerDir = Join-Path -Path $outputModDir -ChildPath $manifest.ModuleVersion
    $outputModVerManifest = Join-Path -Path $outputModVerDir -ChildPath "$($env:BHProjectName).psd1"
    Get-Module $env:BHProjectName | Remove-Module -Force -ErrorAction Ignore
    Import-Module -Name $outputModVerManifest -Verbose:$false -ErrorAction Stop
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
