---
external help file: Gatekeeper-help.xml
Module Name: Gatekeeper
online version:
schema: 2.0.0
---

# Get-PropertySetFolder

## SYNOPSIS
Return the folder path where property set JSON files are stored.

## SYNTAX

```
Get-PropertySetFolder [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Returns the configured folder path for property set JSON files. If no path has been
configured yet, a default path is created under the machine-wide configuration
location and saved to the Gatekeeper configuration.

## EXAMPLES

### Example 1
```powershell
$folder = Get-PropertySetFolder
Get-ChildItem -Path $folder -Filter '*.json'
```

Returns the property set folder path and lists all property set files in it.

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

The absolute path to the property set folder.

## NOTES

## RELATED LINKS
