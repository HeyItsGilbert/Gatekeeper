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
    [hashtable]$Properties

    #PropertySet() {}
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
        return [PropertySet]::new($json)
    }

    static [PropertySet] FromJson([string]$json) {
        $data = $json | ConvertFrom-Json -AsHashtable
        return [PropertySet]::new($data)
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
