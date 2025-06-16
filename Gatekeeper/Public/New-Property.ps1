function New-Property {
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
