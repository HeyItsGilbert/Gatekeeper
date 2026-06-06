---
external help file: Gatekeeper-help.xml
Module Name: Gatekeeper
online version:
schema: 2.0.0
---

# Export-GatekeeperConfig

## SYNOPSIS
Exports the Gatekeeper configuration to disk.

## SYNTAX

```
Export-GatekeeperConfig [[-ConfigurationScope] <Object>] [[-Configuration] <Hashtable>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
This cmdlet exports the current Gatekeeper configuration to a specified
scope (Enterprise, User, or Machine).

## EXAMPLES

### EXAMPLE 1
```
Export-GatekeeperConfig -ConfigurationScope 'Machine'
```

Exports the Gatekeeper configuration to the Machine scope.

### EXAMPLE 2
```
Export-GatekeeperConfig -ConfigurationScope 'User' -Configuration $customConfig
```

Exports the Gatekeeper configuration to the User scope using a custom configuration
hashtable.

## PARAMETERS

### -ConfigurationScope
The scope to which the configuration should be exported.
Valid values are 'Enterprise', 'User', or 'Machine'.
Default is 'Machine'.

```yaml
Type: Object
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: Machine
Accept pipeline input: False
Accept wildcard characters: False
```

### -Configuration
Use this override the default configuration with a custom hashtable.
It is
recommended to get the configuration using the Import-GatekeeperConfig
cmdlet before using this parameter to ensure you don't lose any existing
settings.

```yaml
Type: Hashtable
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
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

## OUTPUTS

## NOTES

## RELATED LINKS
