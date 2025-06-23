. $PSScriptRoot\..\Enums\Effect.ps1
class ConditionGroup {
    [object]$AllOf
    [object]$AnyOf
    [object]$Not
    [string]$Property
    [string]$Operator
    [object]$Value

    ConditionGroup([hashtable]$data) {
        $this.Property = $data.Property
        $this.Operator = $data.Operator
        $this.Value = $data.Value
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
}

class Rule {
    [string]$Name
    [string]$Description
    [Effect]$Effect
    [ConditionGroup]$Conditions

    Rule([hashtable]$data) {
        $this.Name = $data.Name
        $this.Description = $data.Description
        $this.Effect = $data.Effect
        $this.Conditions = [ConditionGroup]::new($data.Conditions)
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
    # $json = Get-Content -Raw -Path 'd:\Gatekeeper\Gatekeeper\featureflag.json'
    # $featureFlag = [FeatureFlag]::FromJson($json)
    static [FeatureFlag] FromJson([string]$json) {
        $data = ConvertFrom-Json $json -AsHashtable
        return [FeatureFlag]::new($data)
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
                if (Test-Path $inputData) {
                    $json = Get-Content -Raw -Path $inputData
                    [FeatureFlag]::FromJson($json)
                } else {
                    throw "Unknown string. If this is a file path, please check if it correct. $inputData"
                }
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
