function Get-PropertySet {
    <#
    .SYNOPSIS
    Retrieve property sets from the Gatekeeper configuration.

    .DESCRIPTION
    This function retrieves property sets from the Gatekeeper configuration.
    It can return all property sets or a specific one by name. Property sets are
    stored in a cache to avoid multiple reads from disk, improving performance.

    .PARAMETER Name
    The name of the property set to retrieve.
    If not specified, all property sets will be returned.
    .EXAMPLE
    $propertySet = Get-PropertySet -Name 'MyPropertySet'

    This retrieves the property set with the name 'MyPropertySet'.
    #>
    param (
        [Parameter()]
        [string]
        $Name
    )
    begin {
        Write-Verbose "Retrieving property set with name: $Name"
        # Store property sets in cache to avoid multiple reads
        # This is a simple cache implementation, could be improved with more complex logic
        # or using a more sophisticated caching mechanism.
        if ($null -eq $script:GatekeeperPropertySets) {
            $script:GatekeeperPropertySets = @{}
            $folder = Get-PropertySetFolder
            Write-Verbose "Loading property sets from folder: $folder"
            $propertySetFiles = Get-ChildItem -Path $folder -Filter '*.json' -File
            foreach ($file in $propertySetFiles) {
                Write-Verbose "Reading property set from file: $($file.FullName)"
                $propertySet = Read-PropertySet -FilePath $file.FullName
                if ($null -ne $propertySet) {
                    $script:GatekeeperPropertySets[$file.BaseName] = $propertySet
                    Write-Verbose "Loaded property set: $($propertySet.Name)"
                } else {
                    Write-Warning "Failed to load property set from file: $($file.FullName)"
                }
            }
        }
        $propertySets = $script:GatekeeperPropertySets
    }

    process {
        # If name is given, return just that property set
        if ($Name) {
            return $propertySets[$Name]
        }

        # If no name is given, return all property sets
        if ($propertySets.Count -eq 0) {
            Write-Warning "No property sets found in the folder."
            return @()
        }
        Write-Verbose "Returning all property sets."
        return $propertySets.Values
    }

    end {
        Write-Verbose "Completed retrieval of property sets."
    }
}
