---
external help file: Gatekeeper-help.xml
Module Name: Gatekeeper
online version:
schema: 2.0.0
---

# Read-FeatureFlag

## SYNOPSIS
Read a feature flag from disk.

## SYNTAX

```
Read-FeatureFlag [-FilePath] <Object> [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Reads the feature flag json file from disk and convert it to a feature flag
object.

## EXAMPLES

### EXAMPLE 1
```
Read-FeatureFlag -FilePath 'MyFeature.json
```

Read the feature from disk.

## PARAMETERS

### -FilePath
The file path to the json.

```yaml
Type: Object
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: True (ByValue)
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

### System.Collections.Generic.List`1[[PropertySet, PowerShell Class Assembly, Version=1.0.0.2, Culture=neutral, PublicKeyToken=null]]
## NOTES

## RELATED LINKS
