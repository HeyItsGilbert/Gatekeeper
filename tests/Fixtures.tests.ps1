# This will make sure that if we change the schemas that all our fixtures are
# still ok.
BeforeDiscovery {
    $script:fixtures = Get-ChildItem $PSScriptRoot\fixtures -Filter '*.json'
}
Describe '<_.name>' -ForEach $script:fixtures {
    BeforeAll {
        $json = Get-Content -Path $_.FullName -Raw | ConvertFrom-Json
        $script:schema = $json.'$schema'

        # Resolve-Path -RelativeBasePath was added in PowerShell 7.4, so join the
        # fixture's directory with the (relative) $schema path before resolving.
        $script:schemaFilePath = Resolve-Path -Path (Join-Path -Path $_.Directory.FullName -ChildPath $script:schema)
    }
    It 'Has a schema' {
        $script:schema | Should -Not -BeNullOrEmpty
        $script:schemaFilePath | Should -Exist
    }
    It 'matches the schema' -Skip:($PSVersionTable.PSVersion.Major -lt 7) {
        Test-Json -Path $_.FullName -SchemaFile $script:schemaFilePath | Should -BeTrue
    }
}
