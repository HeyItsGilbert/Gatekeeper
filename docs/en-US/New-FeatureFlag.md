---
external help file: Gatekeeper-help.xml
Module Name: Gatekeeper
online version:
schema: 2.0.0
---

# New-FeatureFlag

## SYNOPSIS
Create a new feature flag.

## SYNTAX

```
New-FeatureFlag [-Name] <String> [[-Description] <String>] [-Tags <String[]>] [-Version <Version>]
 [-Author <String>] [-DefaultEffect <Effect>] -Rules <Rule[]> [-FilePath <String>]
 [-ProgressAction <ActionPreference>] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
Create a new feature flag to export.

## EXAMPLES

### EXAMPLE 1
```
$featureFlag = New-FeatureFlag -Name 'MyFeatureFlag'
```

This would create a new feature flag object with the specified name.

## PARAMETERS

### -Name
The name of the feature flag.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Description
A description of the feature flag.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: "Feature flag for $Name"
Accept pipeline input: False
Accept wildcard characters: False
```

### -Tags
Tags associated with the feature flag, useful for categorization.

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Version
The version of the feature flag, defaults to "1.0.0".

```yaml
Type: Version
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: [version]"1.0.0"
Accept pipeline input: False
Accept wildcard characters: False
```

### -Author
The author of the feature flag, defaults to the current username.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: $env:USERNAME
Accept pipeline input: False
Accept wildcard characters: False
```

### -DefaultEffect
The default effect of the feature flag, which can be Warn, Allow, or Deny.
Defaults to Warn.

```yaml
Type: Effect
Parameter Sets: (All)
Aliases:
Accepted values: Allow, Deny, Audit, Warn

Required: False
Position: Named
Default value: Warn
Accept pipeline input: False
Accept wildcard characters: False
```

### -Rules
A list of rules that define the conditions under which the feature flag is applied.

```yaml
Type: Rule[]
Parameter Sets: (All)
Aliases:

Required: True
Position: Named
Default value: @()
Accept pipeline input: True (ByValue)
Accept wildcard characters: False
```

### -FilePath
The file path where the feature flag will be saved.
If not specified, it
will be saved in the default feature flag folder.
This is usually preferred.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -WhatIf
Shows what would happen if the cmdlet runs.
The cmdlet is not run.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases: wi

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Confirm
Prompts you for confirmation before running the cmdlet.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases: cf

Required: False
Position: Named
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
