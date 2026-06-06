function New-Context {
    <#
    .SYNOPSIS
    Create an empty context from a PropertySet.

    .DESCRIPTION
    Constructs a hashtable with all keys from the PropertySet, each set to $null.
    The caller populates the values before passing the context to Test-FeatureFlag.

    .PARAMETER PropertySet
    The PropertySet that defines which keys the context should contain.

    .EXAMPLE
    $context = New-Context -PropertySet $propertySet
    $context.Hostname = $env:COMPUTERNAME
    Test-FeatureFlag -FeatureFlag $flag -PropertySet $propertySet -Context $context

    Creates a blank context from the property set, populates it, then evaluates the flag.
    #>
    [CmdletBinding()]
    [OutputType('System.Collections.Hashtable')]
    param (
        [Parameter(Mandatory)]
        [PropertySet]
        [PropertySetTransformAttribute()]
        $PropertySet
    )
    $hashtable = @{}
    foreach ($property in $PropertySet.Properties.Keys) {
        Write-Verbose "Adding property: $property"
        $hashtable[$property] = $null
    }
    return $hashtable
}
