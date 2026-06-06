---
external help file: Gatekeeper-help.xml
Module Name: Gatekeeper
online version:
schema: 2.0.0
---

# Get-PropertySet

## SYNOPSIS
Retrieve property sets from the Gatekeeper configuration.

## SYNTAX

```
Get-PropertySet [[-Name] <String>] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
This function retrieves property sets from the Gatekeeper configuration.
It can return all property sets or a specific one by name.
Property sets are
stored in a cache to avoid multiple reads from disk, improving performance.

## EXAMPLES

### EXAMPLE 1
```
$propertySet = Get-PropertySet -Name 'MyPropertySet'
```

This retrieves the property set with the name 'MyPropertySet'.

## PARAMETERS

### -Name
The name of the property set to retrieve.
If not specified, all property sets will be returned.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
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
