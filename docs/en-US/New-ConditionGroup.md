---
external help file: Gatekeeper-help.xml
Module Name: Gatekeeper
online version:
schema: 2.0.0
---

# New-ConditionGroup

## SYNOPSIS
Create a composite Condition by connecting child Conditions with a logical connective.

## SYNTAX

### AllOf (Default)
```
New-ConditionGroup -AllOf <Condition[]> [-ProgressAction <ActionPreference>] [-WhatIf] [-Confirm]
 [<CommonParameters>]
```

### AnyOf
```
New-ConditionGroup -AnyOf <Condition[]> [-ProgressAction <ActionPreference>] [-WhatIf] [-Confirm]
 [<CommonParameters>]
```

### Not
```
New-ConditionGroup -Not <Condition[]> [-ProgressAction <ActionPreference>] [-WhatIf] [-Confirm]
 [<CommonParameters>]
```

## DESCRIPTION
Composes multiple Conditions using AllOf (all must match), AnyOf (at least one
must match), or Not (none must match).
Use parameter sets to select the connective.

## EXAMPLES

### EXAMPLE 1
```
$condition = New-ConditionGroup -AllOf @(
    (New-Condition -Property 'Environment' -Operator 'Equals' -Value 'Production'),
    (New-Condition -Property 'IsCompliant' -Operator 'Equals' -Value $true)
)
```

### EXAMPLE 2
```
$condition = New-ConditionGroup -AnyOf @(
    (New-Condition -Property 'Region' -Operator 'Equals' -Value 'US'),
    (New-Condition -Property 'Region' -Operator 'Equals' -Value 'EU')
)
```

### EXAMPLE 3
```
$condition = New-ConditionGroup -Not @(
    (New-Condition -Property 'Environment' -Operator 'Equals' -Value 'Production')
)
```

## PARAMETERS

### -AllOf
Child Conditions that must ALL match for this Condition to match.

```yaml
Type: Condition[]
Parameter Sets: AllOf
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -AnyOf
Child Conditions where AT LEAST ONE must match for this Condition to match.

```yaml
Type: Condition[]
Parameter Sets: AnyOf
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Not
Child Conditions that must NONE match for this Condition to match.

```yaml
Type: Condition[]
Parameter Sets: Not
Aliases:

Required: True
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

### Condition
## NOTES

## RELATED LINKS
