---
external help file: Gatekeeper-help.xml
Module Name: Gatekeeper
online version:
schema: 2.0.0
---

# Save-FeatureFlag

## SYNOPSIS
Save a FeatureFlag to a file.

## SYNTAX

```
Save-FeatureFlag [-FeatureFlag] <FeatureFlag> [[-FilePath] <String>] [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

## DESCRIPTION
Save a PropertySet to a specified file path in JSON format.
This cmdlet
allows you to persist the PropertySet for later use or sharing.

## EXAMPLES

### EXAMPLE 1
```
Save-FeatureFlag -PropertySet $myPropertySet -FilePath "C:\path\to\file.json"
```

Save the PropertySet to a JSON file at the specified path.

## PARAMETERS

### -FeatureFlag
{{ Fill FeatureFlag Description }}

```yaml
Type: FeatureFlag
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: True (ByValue)
Accept wildcard characters: False
```

### -FilePath
The file path to save the PropertySet to.

```yaml
Type: String
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
