---
external help file: Gatekeeper-help.xml
Module Name: Gatekeeper
online version:
schema: 2.0.0
---

# Get-DefaultContext

## SYNOPSIS
Get a hashtable of all the properties.

## SYNTAX

```
Get-DefaultContext [-PropertySet] <PropertySet> [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Return a hash table of all the keys for the properties with null values.

## EXAMPLES

### EXAMPLE 1
```
$context = Get-DefaultContext -Properties .\props.json
$context.Hostname = $(hostname)
```

Get all the property keys and then set the hostname using the hostname command.

## PARAMETERS

### -PropertySet
The PropertySet or file path to your properties.

```yaml
Type: PropertySet
Parameter Sets: (All)
Aliases:

Required: True
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

### System.Collections.Hashtable
## NOTES
If you don't pass in Properties explicitly you will be prompted to for a
properties file.

## RELATED LINKS
