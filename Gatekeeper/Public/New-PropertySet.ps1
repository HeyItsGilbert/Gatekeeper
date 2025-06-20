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
    [CmdletBinding()]
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
            $propertySet.Properties[$property.Name] = $property
        }
    }
    end {
        return $propertySet
    }
}
