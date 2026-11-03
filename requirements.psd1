@{
    PSDepend = @{
        Version = '0.7.0-beta1'
        Parameters = @{
            AllowPrerelease = $true
        }
    }
    PSDependOptions = @{
        Target = 'CurrentUser'
    }
    'Pester' = @{
        Version = '6.1.0'
        Parameters = @{
            SkipPublisherCheck = $true
        }
    }
    'psake' = @{
        Version = '5.0.4'
    }
    'BuildHelpers' = @{
        Version = '2.0.16'
    }
    'PowerShellBuild' = @{
        Version = '0.7.2'
    }
    'PSScriptAnalyzer' = @{
        Version = '1.19.1'
    }
    'Configuration' = @{
        Version = '1.6.0'
    }
}
