class PropertyValidation {
    [Nullable[int]]$Minimum
    [Nullable[int]]$Maximum
    [Nullable[int]]$MinLength
    [Nullable[int]]$MaxLength
    [string]$Pattern

    PropertyValidation([hashtable]$data) {
        if ($data.ContainsKey("Minimum") -and $null -ne $data.Minimum) { $this.Minimum = [int]$data.Minimum }
        if ($data.ContainsKey("Maximum") -and $null -ne $data.Maximum) { $this.Maximum = [int]$data.Maximum }
        if ($data.ContainsKey("MinLength") -and $null -ne $data.MinLength) { $this.MinLength = [int]$data.MinLength }
        if ($data.ContainsKey("MaxLength") -and $null -ne $data.MaxLength) { $this.MaxLength = [int]$data.MaxLength }
        if ($data.ContainsKey("Pattern")) { $this.Pattern = $data.Pattern }
    }

    [hashtable] ToHashtable() {
        $data = @{}
        if ($null -ne $this.Minimum) { $data.Minimum = $this.Minimum }
        if ($null -ne $this.Maximum) { $data.Maximum = $this.Maximum }
        if ($null -ne $this.MinLength) { $data.MinLength = $this.MinLength }
        if ($null -ne $this.MaxLength) { $data.MaxLength = $this.MaxLength }
        if ($this.Pattern) { $data.Pattern = $this.Pattern }
        return $data
    }
}

class Property {
    [string]$Name
    [string]$Type
    [object[]]$Enum
    [PropertyValidation]$Validation

    Property([string]$name, [hashtable]$data) {
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
                if ($this.Validation.Pattern) {
                    try {
                        $re = [regex]::new($this.Validation.Pattern, [System.Text.RegularExpressions.RegexOptions]::None, [TimeSpan]::FromMilliseconds(250))
                        if (-not $re.IsMatch($Value)) {
                            Write-Warning "Value for '$($this.Name)' does not match pattern '$($this.Validation.Pattern)'"
                            return $false
                        }
                    } catch [System.Text.RegularExpressions.RegexMatchTimeoutException] {
                        Write-Warning "Pattern evaluation timed out for '$($this.Name)'"
                        return $false
                    }
                }
            }
        }
        return $true
    }
}

class PropertySet {
    [string]$Name
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
            $this.Properties[$key] = [Property]::new($key, $rawData[$key])
        }
    }

    static [PropertySet] FromFile ([string]$FilePath) {
        if (-not (Test-Path -Path $FilePath)) {
            throw "File path given did not exist: $FilePath"
        }
        if (Get-Command -Name Test-Json -ErrorAction SilentlyContinue) {
            $testJsonSplat = @{
                Path = $FilePath
                SchemaFile = "$PSScriptRoot\..\Schemas\Properties.json"
            }
            $validProperties = Test-Json @testJsonSplat
            if (-not $validProperties) {
                throw 'Properties file is not valid.'
            }
        }
        $json = Get-Content $FilePath -Raw | ConvertFrom-JsonToHashtable
        if ($json -isnot [hashtable]) {
            throw 'Failed to create hashtable from json file'
        }
        $ps = [PropertySet]::new($json)
        $ps.FilePath = (Resolve-Path $FilePath).Path
        $ps.Name = [System.IO.Path]::GetFileNameWithoutExtension($ps.FilePath)
        return $ps
    }

    static [PropertySet] FromJson([string]$json) {
        $data = ConvertFrom-JsonToHashtable -InputObject $json
        return [PropertySet]::new($data)
    }

    [PropertySet]AddProperty([Property]$Property) {
        $this.Properties.Add($Property.Name, $Property)
        return $this
    }

    [Property]GetProperty([string]$name) {
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
        $hashtable = @{
            '$schema' = 'https://raw.githubusercontent.com/PowerShell/Gatekeeper/main/Schemas/Properties.json'
        }
        foreach ($property in $this.Properties.Keys) {
            $hashtable[$property] = $this.Properties[$property].ToHashtable()
        }
        $json = $hashtable | ConvertTo-Json -Depth 10
        $tmpPath = "$($this.FilePath).tmp"
        Set-Content -Path $tmpPath -Value $json
        Move-Item -Path $tmpPath -Destination $this.FilePath -Force
    }
}

class PropertySetTransformAttribute : System.Management.Automation.ArgumentTransformationAttribute {

    [object] Transform([System.Management.Automation.EngineIntrinsics]$engineIntrinsics, [object] $inputData) {
        if ($null -eq $inputData) {
            return $(Read-PropertySet)
        }
        if ($inputData -is [PropertySet]) {
            return $inputData
        }
        if ($inputData -is [System.Collections.IDictionary]) {
            return [PropertySet]::new([hashtable]$inputData)
        }
        throw "Cannot convert type to PropertySet: $($inputData.GetType().FullName)"
    }

    [string] ToString() {
        return '[PropertySetTransformAttribute()]'
    }
}
