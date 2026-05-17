function Get-FeatureFlag {
    <#
    .SYNOPSIS
    Retrieve feature flags from the Gatekeeper configuration.

    .DESCRIPTION
    Retrieves feature flags from the configured feature flag folder. Results are
    cached in module scope to avoid repeated disk reads. Returns all flags or a
    specific one by name.

    .PARAMETER Name
    The name of the feature flag to retrieve. If not specified, all flags are returned.

    .EXAMPLE
    $flag = Get-FeatureFlag -Name 'MyFeature'

    .EXAMPLE
    $allFlags = Get-FeatureFlag
    #>
    [CmdletBinding()]
    [OutputType([FeatureFlag])]
    param (
        [Parameter()]
        [string]
        $Name
    )
    begin {
        if ($null -eq $script:GatekeeperFeatureFlags) {
            $script:GatekeeperFeatureFlags = @{}
            $folder = Get-FeatureFlagFolder
            Write-Verbose "Loading feature flags from folder: $folder"
            $flagFiles = Get-ChildItem -Path $folder -Filter '*.json' -File -ErrorAction SilentlyContinue
            foreach ($file in $flagFiles) {
                Write-Verbose "Reading feature flag from file: $($file.FullName)"
                $flag = Read-FeatureFlag -FilePath $file.FullName
                if ($null -ne $flag) {
                    $script:GatekeeperFeatureFlags[$file.BaseName] = $flag
                    Write-Verbose "Loaded feature flag: $($flag.Name)"
                } else {
                    Write-Warning "Failed to load feature flag from file: $($file.FullName)"
                }
            }
        }
        $flags = $script:GatekeeperFeatureFlags
    }

    process {
        if ($Name) {
            return $flags[$Name]
        }
        if ($flags.Count -eq 0) {
            Write-Warning "No feature flags found in the folder."
            return @()
        }
        Write-Verbose "Returning all feature flags."
        return $flags.Values
    }

    end {
        Write-Verbose "Completed retrieval of feature flags."
    }
}
