---
external help file: Gatekeeper-help.xml
Module Name: Gatekeeper
online version:
schema: 2.0.0
---

# New-Context

## SYNOPSIS
Create an empty context from a PropertySet.

## SYNTAX

```
New-Context [-PropertySet] <PropertySet> [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Constructs a hashtable with all keys from the PropertySet, each set to $null.
The caller populates the values before passing the context to Test-FeatureFlag.

## EXAMPLES

### EXAMPLE 1
```
$context = New-Context -PropertySet $propertySet
$context.Hostname = $env:COMPUTERNAME
Test-FeatureFlag -FeatureFlag $flag -PropertySet $propertySet -Context $context
```

## PARAMETERS

### -PropertySet
The PropertySet that defines which keys the context should contain.

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

## RELATED LINKS
