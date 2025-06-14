function Get-DefaultContext {
    [CmdletBinding()]
    [OutputType('System.Collections.Hashtable')]
    param (
        [PropertySet]
        [PropertySetTransformAttribute()]
        $Properties
    )
    if (-not $PSBoundParameters.ContainsKey('Properties')) {
        # This means we're determining the context of the current device.
        $currentProperties = Read-PropertySet
    } else {
        # PropertySet has a Properties item
        $currentProperties = $Properties
    }
    $hashtable = @{}
    foreach ($property in $currentProperties.Properties.Keys) {
        Write-Verbose "Adding property: $property"
        $hashtable[$property] = $null
    }
    return $hashtable
}
