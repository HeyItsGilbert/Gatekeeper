# Configuration

Gatekeeper uses the [Configuration](https://www.powershellgallery.com/packages/Configuration) module for multi-level settings that merge from least to most specific.

## Precedence

```mermaid
graph LR
    A["Module default"] --> B["Machine-wide"]
    B --> C["Enterprise roaming"]
    C --> D["User local"]
    style D stroke-width:3px
```

Each level overrides the previous:

| Level | Location (Windows) | Location (Linux/macOS) |
|-------|-------------------|----------------------|
| Module default | `<module>/Configuration.psd1` | Same |
| Machine-wide | `$Env:ProgramData` | `/etc/xdg/` |
| Enterprise roaming | `$Env:AppData` | `~/.local/share/` |
| User local | `$Env:LocalAppData` | `~/.config/` |

## Settings reference

| Key | Description | Default |
|-----|-------------|---------|
| `Version` | Config file version | `0.1.0` |
| `FilePaths.Schemas` | Path to JSON schema files | `<module>/Schemas` |
| `FilePaths.FeatureFlags` | Where flag JSON files are stored | Machine-wide config folder |
| `FilePaths.PropertySet` | Where property set JSON files are stored | Machine-wide config folder |
| `Logging.*` | Logging behavior per effect type | See [Logging](logging.md) |

## Managing configuration

### Import current config

```powershell
$config = Import-GatekeeperConfig
```

Force a reload from disk (bypasses the in-memory cache):

```powershell
$config = Import-GatekeeperConfig -ForceReload
```

### Export / save config

```powershell
# Save to machine-wide location (default)
Export-GatekeeperConfig

# Save to user-local location
Export-GatekeeperConfig -ConfigurationScope User
```

### Override file paths

To store flags and property sets in a custom location, update your configuration:

```powershell
$config = Import-GatekeeperConfig
$config.FilePaths.FeatureFlags = 'C:\Contoso\FeatureFlags'
$config.FilePaths.PropertySet  = 'C:\Contoso\PropertySets'
Export-GatekeeperConfig -Configuration $config -ConfigurationScope Machine
```

### Querying configured paths

```powershell
Get-FeatureFlagFolder   # Returns the active feature flag directory
Get-PropertySetFolder   # Returns the active property set directory
```

These commands will create the directory if it doesn't exist and export the configuration with the resolved path.
