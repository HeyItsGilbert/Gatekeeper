function Get-DefaultContext {
    <#
    .SYNOPSIS
    Get a hashtable of all the properties.

    .DESCRIPTION
    Return a hash table of all the keys for the properties with null values.

    .PARAMETER PropertySet
    The PropertySet or file path to your properties.

    .EXAMPLE
    $context = Get-DefaultContext -Properties .\props.json
    $context.Hostname = $(hostname)

    Get all the property keys and then set the hostname using the hostname command.
    .NOTES
    If you don't pass in Properties explicitly you will be prompted to for a
    properties file.
    #>
    [CmdletBinding()]
    [OutputType('System.Collections.Hashtable')]
    param (
        [Parameter(Mandatory)]
        [PropertySet]
        [PropertySetTransformAttribute()]
        $PropertySet
    )
    # PropertySet has a Properties item
    $hashtable = @{}
    foreach ($property in $PropertySet.Properties.Keys) {
        Write-Verbose "Adding property: $property"
        $hashtable[$property] = $null
    }
    return $hashtable
}
