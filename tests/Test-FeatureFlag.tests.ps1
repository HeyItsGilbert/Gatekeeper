BeforeDiscovery {
    if ($env:BHPSModuleManifest -eq $null -or $env:BHProjectPath -eq $null -or $env:BHProjectName -eq $null) {
        . $PSscriptRoot\..\build.ps1 -Task Build
    }
    $manifest = Import-PowerShellDataFile -Path $env:BHPSModuleManifest
    $outputDir = Join-Path -Path $env:BHProjectPath -ChildPath 'Output'
    $outputModDir = Join-Path -Path $outputDir -ChildPath $env:BHProjectName
    $outputModVerDir = Join-Path -Path $outputModDir -ChildPath $manifest.ModuleVersion
    $outputModVerManifest = Join-Path -Path $outputModVerDir -ChildPath "$($env:BHProjectName).psd1"
    Import-Module -Name $outputModVerManifest -Verbose:$false -ErrorAction Stop
}
Describe 'Test-FeatureFlag' {
    BeforeAll {
        $script:propertySet = Read-PropertySet -File "$PSScriptRoot\fixtures\Properties.json"
        $script:context = @{
            Percentage = 30
            Environment = 'Staging'
            IsCompliant = $true
        }
        # load feature flag
        $script:featureFlag = Read-FeatureFlag -FilePath "$PSScriptRoot\fixtures\FeatureFlag.json"

        Mock -CommandName Invoke-Logging -ModuleName $env:BHProjectName -Verifiable
    }

    It 'Allows when rule matches with Allow effect' {
        $result = Test-FeatureFlag -FeatureFlag $script:featureFlag -PropertySet $script:propertySet -Context $script:context
        $result | Should -BeTrue

        Assert-MockCalled -CommandName Invoke-Logging -ModuleName $env:BHProjectName -ParameterFilter {
            $Effect -eq 'Allow'
        } -Times 1
    }
}
