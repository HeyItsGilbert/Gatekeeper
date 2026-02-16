# Logging

Gatekeeper can run a script whenever a rule matches during evaluation. This is configured per effect type.

## Defaults

| Effect | Enabled | Default action |
|--------|:-------:|----------------|
| Allow | No | `Write-Host` confirmation |
| Deny | No | `Write-Host` denial |
| Warn | Yes | `Write-Warning` with rule name |
| Audit | Yes | `Write-Host` with rule name |

Allow and Deny logging are disabled by default to avoid cluttering output during normal evaluation. Warn and Audit are enabled because they're designed for observability.

## Configuring logging

Logging is defined in your `Configuration.psd1`. Each effect has an `Enabled` flag and a `Script` that accepts a `$Rule` parameter.

### Using a script block

```powershell
@{
    Logging = @{
        Audit = @{
            Enabled = $true
            Script  = {
                param($Rule)
                "$([DateTime]::Now) - Audit: $($Rule.Name)" |
                    Out-File 'C:\Logs\Gatekeeper.log' -Append
            }
        }
    }
}
```

### Using a script file

If you prefer to keep logging logic in a separate file, point `Script` to a `.ps1` path.

**`C:\Scripts\GatekeeperAudit.ps1`:**

```powershell
param($Rule)
"$([DateTime]::Now) - Audit: $($Rule.Name)" |
    Out-File 'C:\Logs\Gatekeeper.log' -Append
```

**Configuration:**

```powershell
@{
    Logging = @{
        Audit = @{
            Enabled = $true
            Script  = 'C:\Scripts\GatekeeperAudit.ps1'
        }
    }
}
```

!!! warning
    When `Script` is a string, it must be a valid file path to a `.ps1` script that accepts a `$Rule` parameter. Gatekeeper will invoke the file directly.

## When logging runs

Logging only fires when a rule's conditions **match**:

- **Allow/Deny** -- the logging script runs, then evaluation stops
- **Audit/Warn** -- the logging script runs, then evaluation continues to the next rule

If a rule's conditions don't match, its logging script is never called.

## Example: enable all logging

```powershell
$config = Import-GatekeeperConfig
$config.Logging.Allow.Enabled  = $true
$config.Logging.Deny.Enabled   = $true
$config.Logging.Warning.Enabled = $true
$config.Logging.Audit.Enabled  = $true
Export-GatekeeperConfig -Configuration $config
```
