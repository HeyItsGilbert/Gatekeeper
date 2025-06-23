class PropertyValidation {
    [int]$Minimum
    [int]$Maximum
    [int]$MinLength
    [int]$MaxLength
    [string]$Pattern

    PropertyValidation([hashtable]$data) {
        if ($data.ContainsKey("Minimum")) { $this.Minimum = [int]$data.Minimum }
        if ($data.ContainsKey("Maximum")) { $this.Maximum = [int]$data.Maximum }
        if ($data.ContainsKey("MinLength")) { $this.MinLength = [int]$data.MinLength }
        if ($data.ContainsKey("MaxLength")) { $this.MaxLength = [int]$data.MaxLength }
        if ($data.ContainsKey("Pattern")) { $this.Pattern = $data.Pattern }
    }

    [hashtable] ToHashtable() {
        $data = @{
            Minimum = $this.Minimum
            Maximum = $this.Maximum
            MinLength = $this.MinLength
            MaxLength = $this.MaxLength
            Pattern = $this.Pattern
        }
        return $data
    }
}

class PropertyDefinition {
    [string]$Name
    [string]$Type
    [object[]]$Enum
    [PropertyValidation]$Validation

    PropertyDefinition([string]$name, [hashtable]$data) {
        $this.Name = $name
        $this.Type = $data.Type

        if ($data.ContainsKey("Enum")) {
            $this.Enum = $data.Enum
        }

        if ($data.ContainsKey("Validation")) {
            $this.Validation = [PropertyValidation]::new($data.Validation)
        }
    }

    [hashtable] ToHashtable() {
        $data = @{
            Type = $this.Type
        }
        if ($null -ne $this.Enum) {
            $data.Enum = $this.Enum
        }
        if ($null -ne $this.Validation) {
            $data.Validation = $this.Validation.ToHashtable()
        }
        return $data
    }

    [bool]Validate ($Value) {
        if ($null -eq $this.Validation) {
            return $True
        }
        switch ($this.Type) {
            "integer" {
                if ($null -ne $this.Validation.Minimum -and $Value -lt $this.Validation.Minimum) {
                    Write-Warning "Value for '$($this.Name)' ($Value) is less than minimum allowed ($($this.Validation.Minimum))"
                    return $false
                }
                if ($null -ne $this.Validation.Maximum -and $Value -gt $this.Validation.Maximum) {
                    Write-Warning "Value for '$($this.Name)' ($Value) is greater than maximum allowed ($($this.Validation.Maximum))"
                    return $false
                }
            }
            "string" {
                if ($null -ne $this.Validation.MinLength -and $Value.Length -lt $this.Validation.MinLength) {
                    Write-Warning "Value for '$($this.Name)' is shorter than MinLength ($($this.Validation.MinLength))"
                    return $false
                }
                if ($null -ne $this.Validation.MaxLength -and $Value.Length -gt $this.Validation.MaxLength) {
                    Write-Warning "Value for '$($this.Name)' is longer than MaxLength ($($this.Validation.MaxLength))"
                    return $false
                }
                if ($this.Validation.Pattern -and ($Value -notmatch $this.Validation.Pattern)) {
                    Write-Warning "Value for '$($this.Name)' does not match pattern '$($this.Validation.Pattern)'"
                    return $false
                }
            }
        }
        #
        return $true
    }
}

class PropertySet {
    # TODO: Should this class have more properties?
    [string]$Name
    # FilePath is used to save the PropertySet to a file.
    [string]$FilePath
    [hashtable]$Properties

    PropertySet($Name) {
        $this.Name = $Name
        $this.Properties = @{}
    }
    PropertySet([hashtable]$rawData) {
        $this.Properties = @{}
        foreach ($key in $rawData.Keys) {
            if ($key -eq '$schema') { continue }
            Write-Verbose "Saving key: $key"
            $this.Properties[$key] = [PropertyDefinition]::new($key, $rawData[$key])
        }
    }

    static [PropertySet] FromFile ([string]$FilePath) {
        if (-not (Test-Path -Path $FilePath)) {
            throw "File path given did not exist: $FilePath"
        }
        $testJsonSplat = @{
            Path = $FilePath
            SchemaFile = "$PSScriptRoot\..\Schemas\Properties.json"
        }
        $validProperties = Test-Json @testJsonSplat
        if (-not $validProperties) {
            throw 'Properties file is not valid.'
        }
        $json = Get-Content $FilePath -Raw | ConvertFrom-Json -AsHashtable
        if ($json -isnot [hashtable]) {
            throw 'Failed to create hashtable from json file'
        }
        $ps = [PropertySet]::new($json)
        $ps.FilePath = (Resolve-Path $FilePath).Path
        $ps.Name = $ps.FilePath.BaseName
        return $ps
    }

    static [PropertySet] FromJson([string]$json) {
        $data = $json | ConvertFrom-Json -AsHashtable
        return [PropertySet]::new($data)
    }

    [PropertySet]AddProperty([PropertyDefinition]$Property) {
        $this.Properties.Add($Property)
        return $this
    }

    [PropertyDefinition]GetProperty([string]$name) {
        return $this.Properties[$name]
    }

    [string[]]GetNames() {
        return $this.Properties.Keys
    }

    [boolean]ContainsKey($name) {
        return $this.Properties.ContainsKey($name)
    }
    [void]Save() {
        if ($null -eq $this.FilePath) {
            throw "No file path specified to save PropertySet."
        }
        Write-Verbose "Saving PropertySet to file: $($this.FilePath)"
        if (-not (Test-Path -Path (Split-Path -Path $this.FilePath -Parent))) {
            New-Item -ItemType Directory -Path (Split-Path -Path $this.FilePath -Parent) | Out-Null
        }
        # Convert the properties to a hashtable and then to JSON
        # Use -Depth 10 to ensure nested objects are fully serialized
        $hashtable = @{
            '$schema' = 'https://raw.githubusercontent.com/PowerShell/Gatekeeper/main/Schemas/Properties.json'
        }
        foreach ($property in $this.Properties.Keys) {
            $hashtable[$property] = $this.Properties[$property].ToHashtable()
        }
        # Convert to JSON with a depth of 10 to handle nested objects
        $json = $hashtable | ConvertTo-Json -Depth 10
        Set-Content -Path $this.FilePath -Value $json
    }
}

# Argument Transformer
class PropertySetTransformAttribute : System.Management.Automation.ArgumentTransformationAttribute {

    ## Override the abstract method "Transform". This is where the user
    ## provided value will be inspected and transformed if possible.
    [object] Transform([System.Management.Automation.EngineIntrinsics]$engineIntrinsics, [object] $inputData) {
        if ($null -eq $inputData) {
            return $(Read-PropertySet)
        }
        $item = switch ($inputData.GetType().FullName) {
            # Return the existing item if it's already a PropertySet
            'PropertySet' { $inputData }
            'System.Collections.Hashtable' {
                [PropertySet]::new($inputData)
            }
            default {
                throw "Cannot convert type to PropertySet: $($inputData.GetType().FullName)"
            }
        }
        return $item
    }

    [string] ToString() {
        return '[PropertySetTransformAttribute()]'
    }
}
