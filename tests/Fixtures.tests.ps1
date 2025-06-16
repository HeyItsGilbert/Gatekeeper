# This will make sure that if we change the schemas that all our fixtures are
# still ok.
BeforeDiscovery {
    $script:fixtures = Get-ChildItem $PSScriptRoot\fixtures -Filter '*.json'
}
Describe '<_.name>' -ForEach $script:fixtures {
    BeforeAll {
        $json = Get-Content -Path $_.FullName -Raw | ConvertFrom-Json
        $script:schema = $json.'$schema'

        $resolvePathSplat = @{
            RelativeBasePath = $_.Directory.FullName
            Path = $script:schema
        }
        $script:schemaFilePath = Resolve-Path @resolvePathSplat
    }
    It 'Has a schema' {
        $script:schema | Should -Not -BeNullOrEmpty
        $script:schemaFilePath | Should -Exist
    }
    It 'matches the schema' {
        Test-Json -Path $_.FullName -SchemaFile $script:schemaFilePath | Should -BeTrue
    }
}
