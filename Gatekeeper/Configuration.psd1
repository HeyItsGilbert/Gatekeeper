# Configuration settings for the Gatekeeper module
@{
    # This is the version of the configuration, this will
    # allow safe upgrades in the future.
    # It is not the version of the module itself.
    Version = '0.1.0'
    FilePaths = @{
        Schemas = "$PSScriptRoot\Schemas"
    }
    # NOTE: A logging Script is executed as code with the caller's full
    # privileges. It is a string that is either inline PowerShell code or a
    # path to a local *.ps1 file (UNC/remote paths are rejected). Treat these
    # files as trusted code. See guides/logging.md for details.
    Logging = @{
        Allow = @{
            # We leave this disabled by default to avoid cluttering the console
            Enabled = $false
            Script = 'param($Rule); Write-Host "✅ Rule [$($Rule.Name)] matched and is allowed."'
        }
        Deny = @{
            # We leave this disabled by default to avoid cluttering the console
            Enabled = $false
            Script = 'param($Rule); Write-Host "⛔ Rule [$($Rule.Name)] matched and is denied."'
        }
        Warn = @{
            Enabled = $true
            Script = 'param($Rule); Write-Warning "⚠️ Rule [$($Rule.Name)] matched."'
        }
        Audit = @{
            Enabled = $true
            Script = 'param($Rule); Write-Host "Audit: $($Rule.Name)"'
        }
    }
}
