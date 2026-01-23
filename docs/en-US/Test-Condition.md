---
external help file: Gatekeeper-help.xml
Module Name: Gatekeeper
online version:
schema: 2.0.0
---

# Test-Condition

## SYNOPSIS
Evaluate whether a feature flag rule applies.

## SYNTAX

```
Test-Condition [-Context] <Hashtable> [-PropertySet] <PropertySet> [-Condition] <ConditionGroup>
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Takes the given context, properties, and rule/condition and evaluates
whether the rule applies and what it's effect is.

## EXAMPLES

### EXAMPLE 1
```
$context = Get-DeviceContext
$properties = Read-PropertySet
$rule = $rules[0]
Test-Condition -Context $context -Properties $properties -Condition $rule
```

This would return a true/false

## PARAMETERS

### -Context
The device context.

```yaml
Type: Hashtable
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -PropertySet
{{ Fill PropertySet Description }}

```yaml
Type: PropertySet
Parameter Sets: (All)
Aliases:

Required: True
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Condition
A condition to test which are part of rules.

```yaml
Type: ConditionGroup
Parameter Sets: (All)
Aliases:

Required: True
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
