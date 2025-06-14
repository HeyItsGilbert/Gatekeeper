---
external help file: Gatekeeper-help.xml
Module Name: Gatekeeper
online version:
schema: 2.0.0
---

# Test-FeatureFlag

## SYNOPSIS
Checks if the current machine's context will pass the feature flag rules.

## SYNTAX

```
Test-FeatureFlag [-Feature] <String> [[-Properties] <PropertySet>] [[-Context] <Hashtable>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Determines if a given context will pass the feature flag rules.
Returns a
\`$True\` or \`$False\` allowing you to gate keep your features.

## EXAMPLES

### EXAMPLE 1
```
$context = Get-DeviceContext
Test-FeatureFlag -Feature '' -Context $context
```

This will test if the current device will pass the feature flag rules.

## PARAMETERS

### -Feature
The name of the feature flag to test.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: True (ByValue)
Accept wildcard characters: False
```

### -Properties
{{ Fill Properties Description }}

```yaml
Type: PropertySet
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Context
{{ Fill Context Description }}

```yaml
Type: Hashtable
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
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
