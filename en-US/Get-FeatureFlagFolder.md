---
external help file: Gatekeeper-help.xml
Module Name: Gatekeeper
online version:
schema: 2.0.0
---

# Get-FeatureFlagFolder

## SYNOPSIS
Return the folder path where feature flag JSON files are stored.

## SYNTAX

```
Get-FeatureFlagFolder [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Returns the configured folder path for feature flag JSON files. If no path has been
configured yet, a default path is created under the machine-wide configuration
location and saved to the Gatekeeper configuration.

## EXAMPLES

### Example 1
```powershell
$folder = Get-FeatureFlagFolder
Get-ChildItem -Path $folder -Filter '*.json'
```

Returns the feature flag folder path and lists all flag files in it.

## PARAMETERS

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

### System.String

The absolute path to the feature flag folder.

## NOTES

## RELATED LINKS
