---
external help file: Gatekeeper-help.xml
Module Name: Gatekeeper
online version:
schema: 2.0.0
---

# Import-GatekeeperConfig

## SYNOPSIS
Loads the Gatekeeper module configuration with multi-level precedence.

## SYNTAX

```
Import-GatekeeperConfig [-ForceReload] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Imports the Gatekeeper configuration using the Configuration module's precedence
chain: module defaults, machine-wide settings, enterprise roaming settings, and
user local settings.
The result is cached in module scope so subsequent calls
return quickly without re-reading disk.

Logging scripts defined in the configuration are parsed and stored in
$script:GatekeeperLogging.
Scripts may be inline scriptblocks, inline PowerShell
strings, or paths to local .ps1 files.
UNC and remote paths are rejected.

## EXAMPLES

### EXAMPLE 1
```
Import-GatekeeperConfig
```

Returns the cached configuration, loading from disk on first call.

### EXAMPLE 2
```
Import-GatekeeperConfig -ForceReload
```

Discards the cached configuration and reloads from disk.

## PARAMETERS

### -ForceReload
Clears the module-scope cache and re-reads configuration from disk.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -ProgressAction
{{ Fill ProgressAction Description }}

```yaml
Type: ActionPreference
Parameter Sets: (All)
Aliases: proga

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

### System.Collections.Hashtable
## NOTES

## RELATED LINKS
