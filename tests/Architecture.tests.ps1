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
        It 'Primary classes with new([hashtable]) also define static FromJson and FromFile' {
            $classFiles = Get-ChildItem (Join-Path $modulePath 'Classes') -Filter '*.ps1'
            foreach ($className in @('FeatureFlag', 'PropertySet')) {
                $file = $classFiles |
                    Where-Object { (Get-Content $_.FullName -Raw) -match "class $className\b" } |
                    Select-Object -First 1
                $content = Get-Content $file.FullName -Raw
                $content | Should -Match 'static\s+\[.+\]\s+FromJson\s*\(\s*\[string\]' `
                    -Because "$className must have a static FromJson([string]) method"
                $content | Should -Match 'static\s+\[.+\]\s+FromFile\s*\(\s*\[string\]' `
                    -Because "$className must have a static FromFile([string]) method"
            }
        }
    }

    Context 'Effect enum matches configuration' {
        It 'Effect enum values match Configuration.psd1 Logging keys exactly' {
            $enumFile    = Join-Path $modulePath 'Enums\Effect.ps1'
            $enumValues  = (Get-Content $enumFile -Raw) -split '\r?\n' |
                Where-Object { $_ -match '^\s+[A-Z]\w*\s*$' } |
                ForEach-Object { $_.Trim() } |
                Sort-Object

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
