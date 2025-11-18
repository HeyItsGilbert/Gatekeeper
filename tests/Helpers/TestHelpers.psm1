# TestHelpers.psm1
# Shared utilities for Gatekeeper tests

<#
.SYNOPSIS
Creates a sample PropertySet for testing.

.DESCRIPTION
Creates a PropertySet with common properties used across tests.

.PARAMETER IncludeAllTypes
Include all property types (string, integer, boolean).

.EXAMPLE
$properties = New-TestPropertySet
#>
function New-TestPropertySet {
    [CmdletBinding()]
    param(
        [switch]$IncludeAllTypes
    )

    $properties = @()

    # String property with enum
    $properties += [PropertyDefinition]::new('Environment', @{
        Type = 'string'
        Enum = @('Development', 'Staging', 'Production')
    })

    # Integer property with range
    $properties += [PropertyDefinition]::new('Percentage', @{
        Type = 'integer'
        Validation = @{
            Minimum = 0
            Maximum = 100
        }
    })

    # Boolean property
    $properties += [PropertyDefinition]::new('IsCompliant', @{
        Type = 'boolean'
    })

    if ($IncludeAllTypes) {
        # String with regex pattern
        $properties += [PropertyDefinition]::new('Hostname', @{
            Type = 'string'
            Validation = @{
                Pattern = '^[a-zA-Z0-9\-\.]+$'
            }
        })

        # Integer without constraints
        $properties += [PropertyDefinition]::new('Count', @{
            Type = 'integer'
        })
    }

    $set = [PropertySet]::new('TestProperties')
    foreach ($prop in $properties) {
        $set.Properties[$prop.Name] = $prop
    }

    return $set
}

<#
.SYNOPSIS
Creates a sample context for testing.

.DESCRIPTION
Creates a hashtable context with typical test values.

.PARAMETER Environment
The environment value (defaults to 'Production').

.PARAMETER Percentage
The percentage value (defaults to 50).

.PARAMETER IsCompliant
The compliance value (defaults to $true).

.EXAMPLE
$context = New-TestContext -Environment 'Staging' -Percentage 75
#>
function New-TestContext {
    [CmdletBinding()]
    param(
        [string]$Environment = 'Production',
        [int]$Percentage = 50,
        [bool]$IsCompliant = $true
    )

    return @{
        Environment = $Environment
        Percentage = $Percentage
        IsCompliant = $IsCompliant
    }
}

<#
.SYNOPSIS
Creates a simple condition for testing.

.DESCRIPTION
Creates a basic condition using the ConditionGroup class.

.PARAMETER Property
The property name.

.PARAMETER Operator
The comparison operator.

.PARAMETER Value
The comparison value.

.EXAMPLE
$condition = New-TestCondition -Property 'Environment' -Operator 'Equals' -Value 'Production'
#>
function New-TestCondition {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Property,

        [Parameter(Mandatory)]
        [string]$Operator,

        [Parameter(Mandatory)]
        $Value
    )

    return [ConditionGroup]::new(@{
        Property = $Property
        Operator = $Operator
        Value = $Value
    })
}

<#
.SYNOPSIS
Creates a simple rule for testing.

.DESCRIPTION
Creates a basic rule with a single condition.

.PARAMETER Name
The rule name.

.PARAMETER Effect
The rule effect (Allow, Deny, Warn, Audit).

.PARAMETER Property
The property to evaluate.

.PARAMETER Operator
The comparison operator.

.PARAMETER Value
The comparison value.

.EXAMPLE
$rule = New-TestRule -Name 'AllowProd' -Effect 'Allow' -Property 'Environment' -Operator 'Equals' -Value 'Production'
#>
function New-TestRule {
    [CmdletBinding()]
    param(
        [string]$Name = 'TestRule',
        [Effect]$Effect = [Effect]::Allow,
        [string]$Property = 'Environment',
        [string]$Operator = 'Equals',
        $Value = 'Production'
    )

    $condition = New-TestCondition -Property $Property -Operator $Operator -Value $Value

    $rule = [Rule]::new($Name)
    $rule.Effect = $Effect
    $rule.Conditions = $condition

    return $rule
}

<#
.SYNOPSIS
Creates a simple FeatureFlag for testing.

.DESCRIPTION
Creates a basic FeatureFlag with optional rules.

.PARAMETER Name
The feature flag name.

.PARAMETER DefaultEffect
The default effect.

.PARAMETER Rules
Optional array of rules to include.

.EXAMPLE
$flag = New-TestFeatureFlag -Name 'MyFeature' -DefaultEffect 'Deny'
#>
function New-TestFeatureFlag {
    [CmdletBinding()]
    param(
        [string]$Name = 'TestFeature',
        [Effect]$DefaultEffect = [Effect]::Deny,
        [Rule[]]$Rules = @()
    )

    $flag = [FeatureFlag]::new()
    $flag.Name = $Name
    $flag.Description = "Test feature: $Name"
    $flag.Version = [version]"1.0.0"
    $flag.DefaultEffect = $DefaultEffect
    $flag.Rules = $Rules

    return $flag
}

<#
.SYNOPSIS
Gets a temporary test file path.

.DESCRIPTION
Creates a temporary file path for testing file operations.

.PARAMETER Extension
The file extension (defaults to '.json').

.EXAMPLE
$testFile = Get-TestFilePath -Extension '.json'
#>
function Get-TestFilePath {
    [CmdletBinding()]
    param(
        [string]$Extension = '.json'
    )

    $tempPath = [System.IO.Path]::GetTempPath()
    $fileName = "GatekeeperTest_$(New-Guid)$Extension"
    return Join-Path $tempPath $fileName
}

<#
.SYNOPSIS
Removes test files created during testing.

.DESCRIPTION
Cleans up temporary test files.

.PARAMETER Path
The path to remove.

.EXAMPLE
Remove-TestFile -Path $testFile
#>
function Remove-TestFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (Test-Path $Path) {
        Remove-Item -Path $Path -Force -ErrorAction SilentlyContinue
    }
}

<#
.SYNOPSIS
Asserts that an object has specific properties.

.DESCRIPTION
Helper function to validate object structure.

.PARAMETER Object
The object to test.

.PARAMETER Properties
Array of property names that must exist.

.EXAMPLE
Assert-HasProperties -Object $flag -Properties @('Name', 'Rules', 'DefaultEffect')
#>
function Assert-HasProperties {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Object,

        [Parameter(Mandatory)]
        [string[]]$Properties
    )

    foreach ($prop in $Properties) {
        if (-not (Get-Member -InputObject $Object -Name $prop -MemberType Properties)) {
            throw "Object is missing required property: $prop"
        }
    }
}

# Export functions
Export-ModuleMember -Function @(
    'New-TestPropertySet',
    'New-TestContext',
    'New-TestCondition',
    'New-TestRule',
    'New-TestFeatureFlag',
    'Get-TestFilePath',
    'Remove-TestFile',
    'Assert-HasProperties'
)
