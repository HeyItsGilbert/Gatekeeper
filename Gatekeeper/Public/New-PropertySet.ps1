function New-PropertySet {
    <#
    .SYNOPSIS
    Create a new property set.

    .DESCRIPTION
    Create a new property set to export.

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
        [Parameter(ValueFromPipeline)]
        [PropertyDefinition[]]
        $Properties
    )
    begin {
        $propertySet = [PropertySet]::new()
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
