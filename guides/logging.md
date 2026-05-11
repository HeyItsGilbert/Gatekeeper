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

Logging is defined in your `Configuration.psd1`. Each effect has an `Enabled` flag and a `Script` that receives a `$Rule` parameter. Because the configuration is loaded through the [Configuration](https://www.powershellgallery.com/packages/Configuration) module's data-only parser, `Script` is always a **string** -- either inline PowerShell code, or a path to a local `.ps1` file (any string ending in `.ps1` is treated as a path).

!!! danger "A `Script` runs as code"
    A logging `Script` is executed with the **full privileges of whatever process loaded Gatekeeper** -- an inline string is compiled and run, and a `.ps1` path is loaded and run. Treat your `Configuration.psd1` files (and any `.ps1` they reference) as trusted code: keep them writable only by trusted users, and never point `Script` at a path you don't control. UNC / network paths (for example `\\server\share\evil.ps1`) are refused outright.

### Using inline code

```powershell
@{
    Logging = @{
        Audit = @{
            Enabled = $true
            Script  = 'param($Rule); "$([DateTime]::Now) - Audit: $($Rule.Name)" | Out-File ''C:\Logs\Gatekeeper.log'' -Append'
        }
    }
}
```

### Using a script file

To keep logging logic in a separate file, point `Script` to a local `.ps1` path.

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
    A `Script` string ending in `.ps1` is loaded as a script file: it must already exist on a **local** path, and UNC / network paths are rejected. Any other string is compiled and executed as inline PowerShell. Either way the value runs with the caller's full privileges, so only put trusted code there.

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
