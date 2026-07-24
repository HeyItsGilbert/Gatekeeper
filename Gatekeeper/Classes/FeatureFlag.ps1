. $PSScriptRoot\..\Enums\Effect.ps1

enum Operator {
    Equals
    NotEquals
    GreaterThan
    GreaterThanOrEqual
    LessThan
    LessThanOrEqual
    In
    NotIn
}
class Condition {
    [object]$AllOf
    [object]$AnyOf
    [object]$Not
    [string]$Property
    [Operator]$Operator
    [object]$Value

    Condition([hashtable]$data) {
        if ($null -eq $data) {
            throw "Data cannot be null."
        }
        $groupKeys = @('AllOf', 'AnyOf', 'Not') | Where-Object { $data.ContainsKey($_) -and $null -ne $data[$_] }
        if ($groupKeys.Count -gt 1) {
            throw "Condition may only define one of: AllOf, AnyOf, Not. Got: $($groupKeys -join ', ')"
        }
        $hasGroup = $groupKeys.Count -gt 0
        $hasProperty = $data.ContainsKey('Property') -and $null -ne $data['Property']
        if ($hasGroup -and $hasProperty) {
            throw "Condition with AllOf, AnyOf, or Not cannot also have Property, Operator, and Value defined."
        }
        if ($hasProperty) {
            $hasOperator = $data.ContainsKey('Operator') -and $null -ne $data['Operator']
            $hasValue = $data.ContainsKey('Value') -and $null -ne $data['Value']
            if (-not $hasOperator -or -not $hasValue) {
                throw "Condition with Property must also have Operator and Value defined."
            }
        }
        if ($hasProperty) {
            $this.Property = $data.Property
        }
        if ($data.ContainsKey('Operator') -and $null -ne $data['Operator']) {
            $this.Operator = $data.Operator
        }
        if ($data.ContainsKey('Value') -and $null -ne $data['Value']) {
            $this.Value = $data.Value
        }
        if ($data.ContainsKey('AllOf') -and $null -ne $data['AllOf']) {
            $this.AllOf = $data.AllOf | ForEach-Object { [Condition]::new($_) }
        }
        if ($data.ContainsKey('AnyOf') -and $null -ne $data['AnyOf']) {
            $this.AnyOf = $data.AnyOf | ForEach-Object { [Condition]::new($_) }
        }
        if ($data.ContainsKey('Not') -and $null -ne $data['Not']) {
            $this.Not = $data.Not | ForEach-Object { [Condition]::new($_) }
        }
    }

    Condition([string]$operator, [object[]]$conditions) {
        switch ($operator) {
            'AllOf' { $this.AllOf = $conditions }
            'AnyOf' { $this.AnyOf = $conditions }
            'Not'   { $this.Not = $conditions }
            default {
                throw "Unknown operator: $operator"
            }
        }
    }

    static [Condition] FromJson([string]$json) {
        $data = ConvertFrom-JsonToHashtable -InputObject $json
        return [Condition]::new($data)
    }

    [boolean]IsValid() {
        if ($null -ne $this.AllOf -or $null -ne $this.AnyOf -or $null -ne $this.Not) { return $true }
        return $null -ne $this.Property -and $null -ne $this.Operator -and $null -ne $this.Value
    }
    [string]ToString() {
        $sb = [System.Text.StringBuilder]::new()
        if ($this.AllOf) {
            [void]$sb.Append("AllOf(")
            $list = @()
            foreach ($condition in $this.AllOf) {
                $list += $condition.ToString()
            }
            [void]$sb.Append($list -join ', ')
            [void]$sb.Append(")")
        }
        if ($this.AnyOf) {
            [void]$sb.Append("AnyOf(")
            $list = @()
            foreach ($condition in $this.AnyOf) {
                $list += $condition.ToString()
            }
            [void]$sb.Append($list -join ', ')
            [void]$sb.Append(")")
        }
        if ($this.Not) {
            [void]$sb.Append("Not(")
            $list = @()
            foreach ($condition in $this.Not) {
                $list += $condition.ToString()
            }
            [void]$sb.Append($list -join ', ')
            [void]$sb.Append(")")
        }
        if ($null -ne $this.Property -and $null -ne $this.Operator -and $null -ne $this.Value) {
            [void]$sb.Append("$($this.Property) $($this.Operator) $($this.Value)")
        }
        return $sb.ToString()
    }
}

class Rule {
    [string]$Name
    [string]$Description
    [Effect]$Effect
    [Condition]$Condition

    Rule([string]$Name) {
        $this.Name = $Name
    }

    Rule([hashtable]$data) {
        $this.Name = $data.Name
        $this.Description = $data.Description
        $this.Effect = $data.Effect
        if ($data.ContainsKey('Condition')) {
            if ($data.Condition -is [Condition]) {
                $this.Condition = $data.Condition
            } elseif ($data.Condition -is [hashtable]) {
                $this.Condition = [Condition]::new($data.Condition)
            } else {
                throw "Unknown type for Condition: $($data.Condition.GetType().FullName)"
            }
        }
    }
}

class FeatureFlag {
    [string]$Name
    [string]$Description
    [string[]]$Tags
    [version]$Version
    [string]$Author
    [Effect]$DefaultEffect
    [Rule[]]$Rules
    [string]$FilePath

    FeatureFlag() {}
    FeatureFlag([hashtable]$data) {
        $this.Name = $data.Name
        $this.Description = $data.Description
        $this.Tags = $data.Tags
        if ($null -ne $data.Version) {
            if ($data.Version -is [System.Collections.IDictionary]) {
                $b = [int]$data.Version.Build
                $this.Version = if ($b -ge 0) {
                    [version]"$($data.Version.Major).$($data.Version.Minor).$b"
                } else {
                    [version]"$($data.Version.Major).$($data.Version.Minor)"
                }
            } else {
                $this.Version = [version]$data.Version
            }
        }
        $this.Author = $data.Author
        $this.DefaultEffect = $data.DefaultEffect
        $this.Rules = $data.Rules | ForEach-Object { [Rule]::new($_) }
    }

    static [FeatureFlag] FromJson([string]$json) {
        $data = ConvertFrom-JsonToHashtable -InputObject $json
        return [FeatureFlag]::new($data)
    }

    static [FeatureFlag] FromFile([string]$filePath) {
        if (-not (Test-Path $filePath)) {
            throw "File not found: $filePath"
        }
        $json = Get-Content -Raw -Path $filePath
        $featureFlag = [FeatureFlag]::FromJson($json)
        $featureFlag.FilePath = $filePath
        return $featureFlag
    }

    [void]Save() {
        if ($null -eq $this.FilePath) {
            throw "No file path specified to save FeatureFlag."
        }
        Write-Verbose "Saving FeatureFlag to file: $($this.FilePath)"
        $jsonParams = @{ Depth = 10 }
        if ((Get-Command ConvertTo-Json).Parameters.ContainsKey('EnumsAsStrings')) {
            $jsonParams['EnumsAsStrings'] = $true
        }
        $json = $this | ConvertTo-Json @jsonParams
        $tmpPath = "$($this.FilePath).tmp"
        Set-Content -Path $tmpPath -Value $json
        Move-Item -Path $tmpPath -Destination $this.FilePath -Force
    }
}

class GatekeeperPath {
    static [string] ResolveJsonFilePath([string]$Path) {
        if ([string]::IsNullOrWhiteSpace($Path)) {
            throw "File path cannot be empty."
        }
        if ([System.Management.Automation.WildcardPattern]::ContainsWildcardCharacters($Path)) {
            throw "File path cannot contain wildcard characters: $Path"
        }
        if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
            throw "File not found: $Path"
        }
        $resolved = (Resolve-Path -LiteralPath $Path).ProviderPath
        if ([System.IO.Path]::GetExtension($resolved) -ne '.json') {
            throw "File path must point to a .json file: $Path"
        }
        if (([uri]$resolved).IsUnc -and -not [GatekeeperPath]::AllowUncPaths()) {
            throw "UNC file paths are not permitted unless enabled via the Security.AllowUncPaths configuration: $Path"
        }
        return $resolved
    }

    static [boolean] AllowUncPaths() {
        try {
            return [boolean](Import-GatekeeperConfig).Security.AllowUncPaths
        } catch {
            return $false
        }
    }
}

class FeatureFlagTransformAttribute : System.Management.Automation.ArgumentTransformationAttribute {

    [object] Transform([System.Management.Automation.EngineIntrinsics]$engineIntrinsics, [object] $inputData) {
        if ($inputData -is [FeatureFlag]) {
            return $inputData
        }
        if ($inputData -is [System.Collections.IDictionary]) {
            return [FeatureFlag]::new([hashtable]$inputData)
        }
        if ($inputData -is [string]) {
            $resolvedPath = [GatekeeperPath]::ResolveJsonFilePath($inputData)
            $json = Get-Content -Raw -LiteralPath $resolvedPath
            return [FeatureFlag]::FromJson($json)
        }
        throw "Cannot convert type to FeatureFlag: $($inputData.GetType().FullName)"
    }

    [string] ToString() {
        return '[FeatureFlagTransformAttribute()]'
    }
}

class ConditionTransformAttribute : System.Management.Automation.ArgumentTransformationAttribute {

    [object] Transform([System.Management.Automation.EngineIntrinsics]$engineIntrinsics, [object] $inputData) {
        if ($inputData -is [Condition]) {
            return $inputData
        }
        if ($inputData -is [System.Collections.IDictionary]) {
            return [Condition]::new([hashtable]$inputData)
        }
        if ($inputData -is [string]) {
            $resolvedPath = [GatekeeperPath]::ResolveJsonFilePath($inputData)
            $json = Get-Content -Raw -LiteralPath $resolvedPath
            return [Condition]::FromJson($json)
        }
        throw "Cannot convert type to Condition: $($inputData.GetType().FullName)"
    }

    [string] ToString() {
        return '[ConditionTransformAttribute()]'
    }
}
