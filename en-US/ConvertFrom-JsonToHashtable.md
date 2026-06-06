---
external help file: Gatekeeper-help.xml
Module Name: Gatekeeper
online version:
schema: 2.0.0
---

# ConvertFrom-JsonToHashtable

## SYNOPSIS
Converts JSON to a hashtable with PowerShell 5.1 compatibility.

## SYNTAX

```
ConvertFrom-JsonToHashtable [-InputObject] <String> [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Provides a compatibility layer for converting JSON to hashtables that works
with both PowerShell 5.1 and PowerShell 7+.
In PowerShell 7+, uses the native
-AsHashtable parameter.
In PowerShell 5.1, manually converts PSCustomObject
to hashtable.

## EXAMPLES

### EXAMPLE 1
```
$json = Get-Content -Path "file.json" -Raw | ConvertFrom-JsonToHashtable
```

### EXAMPLE 2
```
$data = ConvertFrom-JsonToHashtable -InputObject '{"key":"value"}'
```

## PARAMETERS

### -InputObject
The JSON string to convert or pipeline input from Get-Content.

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
