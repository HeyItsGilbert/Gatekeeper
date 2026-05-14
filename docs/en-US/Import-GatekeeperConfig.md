---
external help file: Gatekeeper-help.xml
Module Name: Gatekeeper
online version:
schema: 2.0.0
---

# Import-GatekeeperConfig

## SYNOPSIS
Load and cache the Gatekeeper module configuration.

## SYNTAX

```
Import-GatekeeperConfig [-ForceReload] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Reads the Gatekeeper configuration from disk using the Configuration module and caches
it in the module-scoped `$GatekeeperConfiguration` variable. Subsequent calls return the
cached copy unless `-ForceReload` is specified. Also parses and compiles the logging
configuration into ready-to-invoke script blocks.

## EXAMPLES

### Example 1
```powershell
Import-GatekeeperConfig
```

Loads the Gatekeeper configuration from disk and caches it for the session.

### Example 2
```powershell
Import-GatekeeperConfig -ForceReload
```

Discards the cached configuration and reloads it from disk.

## PARAMETERS

### -ForceReload
Clears the cached configuration and reloads it from disk.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
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

### None

## OUTPUTS

### System.Collections.Hashtable

The loaded configuration hashtable.

## NOTES

## RELATED LINKS
