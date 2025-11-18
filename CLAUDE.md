# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Gatekeeper is a PowerShell module for implementing feature flags in PowerShell projects. It uses JSON-based feature flag definitions with a rule-based evaluation system to control feature rollouts based on device context.

The module leverages JSON schemas to enforce structure and uses PowerShell classes to model the core concepts: PropertySets, FeatureFlags, Rules, ConditionGroups, and Effects.

## Development Commands

### Build and Test

```powershell
# Bootstrap dependencies (first time setup)
.\build.ps1 -Bootstrap

# Run tests (default task)
.\build.ps1

# Run specific build task
.\build.ps1 -Task <TaskName>

# List available tasks
.\build.ps1 -Help
```

### Testing

```powershell
# Run all tests using Pester
Invoke-Pester

# Run specific test file
Invoke-Pester -Path tests/Test-FeatureFlag.tests.ps1
```

### Module Development

```powershell
# Import module for local development
Import-Module .\Gatekeeper\Gatekeeper.psd1 -Force

# Test module manifest
Test-ModuleManifest .\Gatekeeper\Gatekeeper.psd1
```

## Core Architecture

### Module Structure

The module follows a standard PowerShell module layout:

- **Gatekeeper/**: Root module folder
  - **Classes/**: PowerShell class definitions (Property.ps1, FeatureFlag.ps1)
  - **Enums/**: Enumeration definitions (Effect.ps1)
  - **Public/**: Exported functions (Test-FeatureFlag, New-FeatureFlag, etc.)
  - **Private/**: Internal helper functions (Convert-ToTypeValue, Test-TypedValue)
  - **Schemas/**: JSON schemas for validation (FeatureFlag.json, Properties.json)
  - **Configuration.psd1**: Default module configuration
  - **Gatekeeper.psm1**: Module loader that dot-sources all functions and registers type accelerators
  - **Gatekeeper.psd1**: Module manifest

### Key Concepts

**PropertySet**: Defines the structure and validation rules for context properties. Each property has a type (string, integer, boolean) and optional validations (min/max, enum values, regex pattern). Implemented as the `PropertySet` class containing `PropertyDefinition` objects.

**Context**: A hashtable representing a device's current state. Keys match property names from the PropertySet, values are evaluated against rules. Context is provided by the user and can come from any source (scripts, tools, manual creation).

**FeatureFlag**: Contains the feature name, description, metadata, default effect, and an ordered list of rules. Implemented as the `FeatureFlag` class with a `Rules` property containing `Rule` objects.

**Rule**: Defines a condition to evaluate and an effect to apply if the condition matches. Rules are evaluated top-down, first Allow/Deny wins. Audit/Warn effects don't stop evaluation. Implemented as the `Rule` class.

**ConditionGroup**: Represents logical conditions supporting `AllOf`, `AnyOf`, `Not` grouping operators and individual property comparisons using operators (Equals, NotEquals, GreaterThan, LessThan, In, NotIn). Recursively defined to support nested conditions.

**Effect**: Enumeration with values: Allow, Deny, Audit, Warn. Determines the outcome when a rule matches.

### Evaluation Flow

1. `Test-FeatureFlag` receives a FeatureFlag, PropertySet, and Context
2. Rules are evaluated sequentially from top to bottom
3. For each rule, `Test-Condition` evaluates the ConditionGroup against the Context
4. If a condition matches:
   - **Allow**: Returns true, stops evaluation
   - **Deny**: Returns false, stops evaluation
   - **Audit**: Logs via configured script, continues evaluation
   - **Warn**: Logs warning, continues evaluation
5. If no Allow/Deny rule matches, DefaultEffect determines the outcome
6. Result is always a boolean (defaults to $false for safety)

### Type Accelerators

The module registers type accelerators for easier type references:

- `[PropertySet]`
- `[PropertyDefinition]`
- `[FeatureFlag]`
- `[Rule]`
- `[ConditionGroup]`
- `[Effect]`

### Argument Transformation

The module uses custom ArgumentTransformationAttributes to automatically convert input:

- `[FeatureFlagTransformAttribute()]`: Converts hashtables, file paths, or JSON strings to FeatureFlag objects
- `[PropertySetTransformAttribute()]`: Converts hashtables to PropertySet objects

## Configuration System

Configuration uses the PoshCode/Configuration module with multi-level precedence:

1. Module-level `Configuration.psd1`
2. Machine-wide settings (`$Env:ProgramData` or `/etc/xdg/`)
3. Enterprise roaming settings (`$Env:AppData` or `~/.local/share/`)
4. User local settings (`$Env:LocalAppData` or `~/.config/`)

Configuration path: `Gilbert Sanchez\Gatekeeper\Configuration.psd1`

### Configuration Structure

```powershell
@{
    Version = '0.1.0'
    FilePaths = @{
        Schemas = "<module>\Schemas"
        FeatureFlags = $null  # Defaults to machine-wide config location
        PropertySet = $null   # Defaults to machine-wide config location
    }
    Logging = @{
        Allow = @{ Enabled = $bool; Script = {param($Rule) ...} }
        Deny = @{ Enabled = $bool; Script = {param($Rule) ...} }
        Warning = @{ Enabled = $bool; Script = {param($Rule) ...} }
        Audit = @{ Enabled = $bool; Script = {param($Rule) ...} }
    }
}
```

Logging scripts can be either a scriptblock or a file path to a .ps1 script that accepts a `$Rule` parameter.

## Important Implementation Details

### Class Loading Order

Classes must be loaded in dependency order. The module manifest specifies:

```powershell
ScriptsToProcess = @('Enums\Effect.ps1', 'Classes\Property.ps1', 'Classes\FeatureFlag.ps1')
```

This ensures enums are available before classes that reference them.

### JSON Schema Validation

All FeatureFlag and PropertySet files should validate against their respective schemas:

- `Schemas/FeatureFlag.json`: Validates feature flag structure
- `Schemas/Properties.json`: Validates property set definitions

Use `Test-Json -SchemaFile` to validate before loading.

### Safe Evaluation Philosophy

The module errs on the side of caution:

- `Test-FeatureFlag` returns `$false` by default if no Allow rule matches
- If DefaultEffect is not "Allow", returns `$false` even if it matches
- Validation failures are reported as warnings and fail evaluation

## Testing Patterns

Test files follow standard Pester 5.x patterns:

- `*.tests.ps1` in the `tests/` folder
- Use `BeforeAll` for setup, `AfterAll` for cleanup
- Mock external dependencies where appropriate
- Tests validate both positive and negative cases
- Fixture files provide sample data for integration tests

## Dependencies

Required modules (see `requirements.psd1`):

- **Configuration** (1.6.0): Multi-level config management
- **Pester** (5.7.1): Testing framework
- **PSScriptAnalyzer** (1.19.1): Code quality checks
- **psake** (4.9.1): Build automation
- **PowerShellBuild** (0.7.2): Build helper tasks
- **BuildHelpers** (2.0.16): Build environment utilities
- **PSDepend** (0.3.8): Dependency management

## Common Patterns

### Creating a New Feature Flag

```powershell
$flag = New-FeatureFlag -Name "MyFeature" -DefaultEffect Deny
$rule = New-Rule -Name "Allow Staging" -Effect Allow -Conditions $conditions
$flag.Rules += $rule
Save-FeatureFlag -FeatureFlag $flag -Path "path/to/flag.json"
```

### Testing a Feature Flag

```powershell
$properties = Get-PropertySet -FilePath "properties.json"
$context = Get-DefaultContext -Properties $properties
$context['Environment'] = 'Staging'
$result = Test-FeatureFlag -FeatureFlag "MyFeature" -Properties $properties -Context $context
```

### Creating Complex Conditions

Use `New-ConditionGroup` with `-AllOf`, `-AnyOf`, or `-Not` for logical grouping. Conditions can be nested recursively.

## File Locations

- Module configuration loads from machine-wide location by default
- Feature flags and property sets default to the machine-wide config folder
- Override in configuration or provide explicit paths to commands
- Use `Get-FeatureFlagFolder` and `Get-PropertySetFolder` to retrieve configured paths
