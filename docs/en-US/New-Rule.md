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
New-Rule [-Name] <String> [[-Description] <Object>] [-Effect] <Effect> [-Condition] <Condition>
 [-ProgressAction <ActionPreference>] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
Create a new rule that pairs a Condition with an Effect.
When the Condition
matches a Context, the Effect is applied.
The Condition must be fully
constructed before being passed - use New-Condition or New-ConditionGroup to
build it.

## EXAMPLES

### EXAMPLE 1
```
$condition = New-Condition -Property 'Environment' -Operator 'Equals' -Value 'Production'
$rule = New-Rule -Name 'ProductionRule' -Effect 'Allow' -Condition $condition
```

### EXAMPLE 2
```
$condition = New-ConditionGroup -AllOf @(
    (New-Condition -Property 'Environment' -Operator 'Equals' -Value 'Production'),
    (New-Condition -Property 'Region' -Operator 'In' -Value @('US', 'EU'))
)
$rule = New-Rule -Name 'ProductionUS-EU' -Effect 'Allow' -Condition $condition
```

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
The effect to apply when the Condition matches (Allow, Deny, Audit, Warn).

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

### -Condition
The Condition to evaluate.
Must be a single pre-built Condition object.

```yaml
Type: Condition
Parameter Sets: (All)
Aliases:

Required: True
Position: 4
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

### Rule
## NOTES

## RELATED LINKS
