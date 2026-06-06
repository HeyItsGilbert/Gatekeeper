---
external help file: Gatekeeper-help.xml
Module Name: Gatekeeper
online version:
schema: 2.0.0
---

# Get-FeatureFlagFolder

## SYNOPSIS
Returns the configured directory where feature flag JSON files are stored.

## SYNTAX

```
Get-FeatureFlagFolder [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Retrieves the feature flag folder path from the active Gatekeeper configuration.
If no path has been configured, a default location is created under the machine-wide
configuration path and saved automatically via Export-GatekeeperConfig.

Use Export-GatekeeperConfig to set the path explicitly and avoid the auto-create
behavior on first run.

## EXAMPLES

### EXAMPLE 1
```
$folder = Get-FeatureFlagFolder
Get-ChildItem -Path $folder -Filter '*.json'
```

Returns the feature flag folder path and lists all JSON files in it.

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

## OUTPUTS

### System.String
## NOTES
On first run, if no path is configured, this function creates the default directory
and persists the path to configuration automatically.

## RELATED LINKS
