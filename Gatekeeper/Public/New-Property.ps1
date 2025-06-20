function New-Property {
    <#
    .SYNOPSIS
    Create a new property definition.

    .DESCRIPTION
    Create a new property definition to use with your property set.

    .PARAMETER Name
    The name of the property.

    .PARAMETER Type
    The type of property. Limited to: string, integer, boolean

    .PARAMETER EnumValues
    If the values should be limited to a set, private an array of values.

    .PARAMETER Validation
    Parameter description

    .EXAMPLE
    $properties = @()
    $properties += New-Property -Name 'Hostname' -Type 'string' -Validation @{Pattern='*.contoso.com'}
    $set = New-PropertySet -Properties $properties

    This would create a new property object and create a new set with that property.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([PropertyDefinition])]
    param (
        [Parameter(Mandatory)]
        [String]
        $Name,
        [Parameter(Mandatory)]
        [ValidateSet('string', 'integer', 'boolean')]
        [string]
        $Type,
        [object[]]
        $EnumValues,
        [hashtable]
        $Validation
    )
    $data = @{
        Type = $Type
    }
    if ($EnumValues) { $data['Enum'] += $EnumValues }
    if ($Validation) { $data['Validation'] += $Validation }

    if ($PSCmdlet.ShouldProcess("Name", "Create new Property Definition")) {
        [PropertyDefinition]::new($Name, $Data)
    }
}
