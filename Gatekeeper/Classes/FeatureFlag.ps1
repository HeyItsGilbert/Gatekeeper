. $PSScriptRoot\..\Enums\Effect.ps1
. $PSScriptRoot\..\Public\ConvertFrom-JsonToHashtable.ps1

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
class ConditionGroup {
    [object]$AllOf
    [object]$AnyOf
    [object]$Not
    [string]$Property
    [Operator]$Operator
    [object]$Value

    ConditionGroup([hashtable]$data) {
        if ($null -eq $data) {
            throw "Data cannot be null."
        }
        # This should either have a single condition or a group of conditions
        $groupKeys = @('AllOf', 'AnyOf', 'Not') | Where-Object { $data.ContainsKey($_) }
        if ($groupKeys.Count -gt 1) {
            throw "ConditionGroup may only define one of: AllOf, AnyOf, Not. Got: $($groupKeys -join ', ')"
        }
        if (($data.ContainsKey('AllOf') -or $data.ContainsKey('AnyOf') -or $data.ContainsKey('Not')) -and
            ($data.ContainsKey('Property') -or $data.ContainsKey('Operator') -or $data.ContainsKey('Value'))) {
            throw "ConditionGroup with AllOf, AnyOf, or Not cannot also have Property, Operator, and Value defined."
        }
        if ($data.ContainsKey('Property') -and
            (-not $data.ContainsKey('Operator') -or -not $data.ContainsKey('Value'))) {
            throw "ConditionGroup with Property must also have Operator and Value defined."
        }
        if ($data.ContainsKey('Property')) {
            $this.Property = $data.Property
        }
        if ($data.ContainsKey('Operator')) {
            $this.Operator = $data.Operator
        }
        if ($data.ContainsKey('Value')) {
            $this.Value = $data.Value
        }
        if ($data.ContainsKey('AllOf')) {
            $this.AllOf = $data.AllOf | ForEach-Object { [ConditionGroup]::new($_) }
        }
        if ($data.ContainsKey('AnyOf')) {
            $this.AnyOf = $data.AnyOf | ForEach-Object { [ConditionGroup]::new($_) }
        }
        if ($data.ContainsKey('Not')) {
            $this.Not = $data.Not | ForEach-Object { [ConditionGroup]::new($_) }
        }
    }
    # Constructor for creating a new sub group
    ConditionGroup([string]$operator, [object[]]$conditions) {
        switch ($operator) {
            'AllOf' { $this.AllOf = $conditions }
            'AnyOf' { $this.AnyOf = $conditions }
            'Not' { $this.Not = $conditions }
            default {
                throw "Unknown operator: $operator"
            }
        }
    }

    static [ConditionGroup] FromJson([string]$json) {
        $data = ConvertFrom-JsonToHashtable -InputObject $json
        return [ConditionGroup]::new($data)
    }

    [boolean]IsValid() {
        # This check if for the top level condition group
        # For nested condition groups (AllOf, AnyOf, Not) the validity is not checked.
        if ($null -ne $this.Property -and $null -ne $this.Operator -and $null -ne $this.Value) {
            return $true
        }
        return $false
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
    [ConditionGroup]$Conditions

    Rule([string]$Name) {
        $this.Name = $Name
    }

    Rule([hashtable]$data) {
        $this.Name = $data.Name
        $this.Description = $data.Description
        $this.Effect = $data.Effect
        if ($data.ContainsKey('Conditions')) {
            # Check if it's a condition group
            if ($data.Conditions -is [ConditionGroup]) {
                $this.Conditions = $data.Conditions
            } elseif ($data.Conditions -is [hashtable]) {
                $this.Conditions = [ConditionGroup]::new($data.Conditions)
            } else {
                throw "Unknown type for Conditions: $($data.Conditions.GetType().FullName)"
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
        $this.Version = $data.Version
        $this.Author = $data.Author
        $this.DefaultEffect = $data.DefaultEffect
        $this.Rules = $data.Rules | ForEach-Object { [Rule]::new($_) }
    }

    # Example usage:
    # $json = Get-Content -Raw -Path 'd:\Gatekeeper\Gatekeeper\featureFlag.json'
    # $featureFlag = [FeatureFlag]::FromJson($json)
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
        $json = $this | ConvertTo-Json -Depth 10 -EnumsAsStrings
        Set-Content -Path $this.FilePath -Value $json
    }
}

class GatekeeperPath {
    # Validates a user-supplied string as a safe path to an existing JSON file.
    # Rejects wildcard patterns, non-.json files, and UNC paths (unless enabled
    # via the Security.AllowUncPaths configuration setting) so callers that accept
    # untrusted flag names cannot be redirected to read arbitrary files. Returns
    # the resolved provider path on success and throws otherwise.
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

    ## Override the abstract method "Transform". This is where the user
    ## provided value will be inspected and transformed if possible.
    [object] Transform([System.Management.Automation.EngineIntrinsics]$engineIntrinsics, [object] $inputData) {
        $item = switch ($inputData.GetType().FullName) {
            # Return the existing item if it's already a FeatureFlag
            'FeatureFlag' { $inputData }
            'System.Collections.Hashtable' {
                [FeatureFlag]::new($inputData)
            }
            'System.String' {
                $resolvedPath = [GatekeeperPath]::ResolveJsonFilePath($inputData)
                $json = Get-Content -Raw -LiteralPath $resolvedPath
                [FeatureFlag]::FromJson($json)
            }
            default {
                throw "Cannot convert type to FeatureFlag: $($inputData.GetType().FullName)"
            }
        }
        return $item
    }

    [string] ToString() {
        return '[FeatureFlagTransformAttribute()]'
    }
}

class ConditionGroupTransformAttribute : System.Management.Automation.ArgumentTransformationAttribute {

    ## Override the abstract method "Transform". This is where the user
    ## provided value will be inspected and transformed if possible.
    [object] Transform([System.Management.Automation.EngineIntrinsics]$engineIntrinsics, [object] $inputData) {
        $item = switch ($inputData.GetType().FullName) {
            # Return the existing item if it's already a ConditionGroup
            'ConditionGroup' { $inputData }
            'System.Collections.Hashtable' {
                [ConditionGroup]::new($inputData)
            }
            'System.String' {
                $resolvedPath = [GatekeeperPath]::ResolveJsonFilePath($inputData)
                $json = Get-Content -Raw -LiteralPath $resolvedPath
                [ConditionGroup]::FromJson($json)
            }
            default {
                throw "Cannot convert type to ConditionGroup: $($inputData.GetType().FullName)"
            }
        }
        return $item
    }

    [string] ToString() {
        return '[ConditionGroupTransformAttribute()]'
    }
}
