---
external help file: Gatekeeper-help.xml
Module Name: Gatekeeper
online version:
schema: 2.0.0
---

# Export-PropertySet

## SYNOPSIS
Save a PropertySet to a JSON file.

## SYNTAX

```
Export-PropertySet [-PropertySet] <PropertySet> [[-FilePath] <String>] [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

## DESCRIPTION
Persists a PropertySet to disk at the specified path, or at the path already
stored on the PropertySet object.

## EXAMPLES

### EXAMPLE 1
```
Export-PropertySet -PropertySet $myPropertySet -FilePath "C:\props\MySet.json"
```

### EXAMPLE 2
```
$myPropertySet | Export-PropertySet
```

## PARAMETERS

### -PropertySet
The PropertySet to export.

```yaml
Type: PropertySet
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: True (ByValue)
Accept wildcard characters: False
```

### -FilePath
The file path to write to.
Overrides the PropertySet's existing FilePath.

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
