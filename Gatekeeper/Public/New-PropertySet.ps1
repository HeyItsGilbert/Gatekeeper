function New-PropertySet {
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
