---
external help file: Gatekeeper-help.xml
Module Name: Gatekeeper
online version:
schema: 2.0.0
---

# Get-FeatureFlag

## SYNOPSIS
Retrieve feature flags from the Gatekeeper configuration.

## SYNTAX

```
Get-FeatureFlag [[-Name] <String>] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Retrieves feature flags from the configured feature flag folder.
Results are
cached in module scope to avoid repeated disk reads.
Returns all flags or a
specific one by name.

## EXAMPLES

### EXAMPLE 1
```
$flag = Get-FeatureFlag -Name 'MyFeature'
```

### EXAMPLE 2
```
$allFlags = Get-FeatureFlag
```

## PARAMETERS

### -Name
The name of the feature flag to retrieve.
If not specified, all flags are returned.

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

### FeatureFlag
## NOTES

## RELATED LINKS
