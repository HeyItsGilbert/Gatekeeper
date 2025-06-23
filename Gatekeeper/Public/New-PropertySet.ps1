function New-PropertySet {
    <#
    .SYNOPSIS
    Create a new property set.

    .DESCRIPTION
    Create a new property set to export.

    .PARAMETER Name
    The name of the property set. This is used to create the file name when
    saving the property set to disk.

    .PARAMETER Properties
    A list of properties, typically created by `New-Property`.

    .EXAMPLE
    $properties = @()
    $properties += New-Property -Name 'Hostname' -Type 'string' -Validation @{Pattern='*.contoso.com'}
    $set = New-PropertySet -Properties $properties

    This would create a new property object and create a new set with that property.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([PropertySet])]
    param (
        [String]
        $Name,
        [Parameter(ValueFromPipeline)]
        [PropertyDefinition[]]
        $Properties
    )
    begin {
        $propertySet = [PropertySet]::new()
        $propertySet.Name = $Name
        $folder = Get-PropertySetFolder
        $propertySet.FilePath = Join-Path $folder "$($Name).json"
    }
    process {
        foreach ($property in $Properties) {
            if ($PSCmdlet.ShouldProcess($property.Name, "Create new property with value: $($property.Value)")) {
                $propertySet.Properties[$property.Name] = $property
            }
        }
    }
    end {
        return $propertySet
    }
}
