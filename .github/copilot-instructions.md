# Copilot Instructions for Gatekeeper

PowerShell feature flag module using JSON definitions and rule-based evaluation.

## Critical Constraints

**Loading Order (breaks if violated):** `Gatekeeper.psm1` dot-sources in strict order—Enums → Classes → Public → Private. Adding new Enums/Classes requires updating `Gatekeeper.psd1` ScriptsToProcess, not just the psm1. Violating order causes "type not found" errors.

**ConditionGroup Validation:** Must be EITHER grouped (`AllOf`/`AnyOf`/`Not`) OR atomic (`Property`+`Operator`+`Value`)—never both in same object. Constructor throws if mixed.

**Safe-by-default:** `Test-FeatureFlag` returns `$false` when rules misconfigured or context incomplete. Prevents accidental feature leakage.

## Build & Test

```powershell
.\build.ps1 -Bootstrap    # First-time: install dependencies
.\build.ps1 -Task Test    # Run Pester tests (default task)
.\build.ps1 -Task Analyze # PSScriptAnalyzer linting
```

Tests import from `Output/Gatekeeper/{version}/` via `$env:BHPSModuleManifest` (set by build). For local dev: `Import-Module .\Gatekeeper\Gatekeeper.psd1 -Force`

## Architecture

**Evaluation Flow:** `Test-FeatureFlag` → iterates Rules top-to-bottom → `Test-Condition` evaluates ConditionGroup recursively → first Allow/Deny stops evaluation → Audit/Warn log and continue → no match returns `$false`

**Key Types:** `[FeatureFlag]` → `[Rule]` → `[ConditionGroup]` (recursive). `[PropertySet]` → `[PropertyDefinition]`. `[Effect]` enum (Allow/Deny/Audit/Warn). All registered as type accelerators.

**Argument Transforms:** `[FeatureFlagTransformAttribute()]` accepts path/hashtable/JSON string. Enables: `Test-FeatureFlag -FeatureFlag "path/to/flag.json"`

## Key Patterns

**Test structure (Pester 5.x):**
```powershell
BeforeDiscovery {
    if (-not $env:BHProjectName) { . $PSScriptRoot\..\build.ps1 -Task Build }
}
BeforeAll {
    $script:propertySet = Read-PropertySet -File "$PSScriptRoot\fixtures\Properties.json"
    Mock Invoke-Logging -ModuleName $env:BHProjectName
}
```

**Valid ConditionGroups:**
```powershell
# Grouped
@{ AllOf = @( @{Property="Env"; Operator="Equals"; Value="Prod"} ) }
# Atomic
@{ Property="Percentage"; Operator="GreaterThan"; Value=50 }
```

**Configuration:** Multi-level precedence via PoshCode/Configuration (Module → Machine → Roaming → Local). Logging scripts configurable per Effect type.

## File Organization

- `Classes/FeatureFlag.ps1` - Rule, ConditionGroup, Operator enum
- `Classes/Property.ps1` - PropertySet, PropertyDefinition
- `Enums/Effect.ps1` - Allow, Deny, Audit, Warn
- `Schemas/` - JSON schemas for validation (`Test-Json -SchemaFile`)
- `tests/fixtures/` - Properties.json, FeatureFlag.json test data
