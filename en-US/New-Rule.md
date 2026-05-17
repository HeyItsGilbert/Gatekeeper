---
external help file: Gatekeeper-help.xml
Module Name: Gatekeeper
online version:
schema: 2.0.0
---

# New-Rule

## SYNOPSIS
Create a new rule for a feature flag.

## SYNTAX

```
New-Rule [-Name] <String> [[-Description] <Object>] [-Effect] <Effect> [-Conditions] <ConditionGroup>
 [-ProgressAction <ActionPreference>] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
Create a new rule that can be used to define conditions under which a feature flag is applied.

## EXAMPLES

### EXAMPLE 1
```
$condition1 = New-Condition -Property 'Environment' -Operator 'Equals' -Value 'Production'
$condition2 = New-Condition -Property 'Region' -Operator 'In' -Value @('US', 'EU')
$rule = New-Rule -Name 'ProductionRule' -Effect 'Allow' -Conditions $condition1, $condition2
```

This would create a new rule named 'ProductionRule' that allows the feature flag in production environments and specific regions.

## PARAMETERS

### -Name
The name of the rule.

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
A brief description of the rule.
This is optional and can be used to provide additional context about the rule.

```yaml
Type: Object
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Effect
The effect of the rule (e.g., allow, deny).

```yaml
Type: Effect
Parameter Sets: (All)
Aliases:
Accepted values: Allow, Deny, Audit, Warn

Required: True
Position: 3
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Conditions
The conditions under which the rule applies.

```yaml
Type: ConditionGroup
Parameter Sets: (All)
Aliases:

Required: True
Position: 4
Default value: None
Accept pipeline input: True (ByValue)
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

### Rule
## NOTES

## RELATED LINKS
