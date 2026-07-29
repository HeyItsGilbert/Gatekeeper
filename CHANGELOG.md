# Change Log

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/)
and this project adheres to [Semantic Versioning](http://semver.org/).

## [Unreleased]

## [1.0.1] - 2026-07-29

### Fixed

- Argument transforms (`FeatureFlag`, `PropertySet`, `Condition`) now accept
  any `IDictionary` instead of only exact `System.Collections.Hashtable`, so
  configuration built via `ConvertFrom-Json -AsHashtable` (which returns an
  `OrderedHashtable`) and other ordered/generic dictionaries bind correctly.
- `PropertySetTransformAttribute` no longer calls the broken, argument-less
  `Read-PropertySet` when `-PropertySet` is omitted (that call could never
  bind and always threw). `-PropertySet` is now a mandatory parameter on
  `Test-FeatureFlag`, matching `Test-Condition`, so the missing value is
  reported with a clear mandatory-parameter error instead. (#84)
- `Test-Condition`/`Test-FeatureFlag` no longer throw an opaque
  "You cannot call a method on a null-valued expression" error when a rule's
  `Condition` is `$null` (e.g. omitted or misspelled). `ConditionTransformAttribute`
  now null-guards and raises a clear `ArgumentNullException` explaining that the
  rule must define a `Condition`. `FeatureFlagTransformAttribute` gained the same
  guard for a null `FeatureFlag`. (#83)

## [1.0.0] 2026-06-05

### Added

- `Get-FeatureFlag` — retrieves feature flags from the configured folder
  with module-scope caching; replaces direct `Read-FeatureFlag` calls.
- `New-Context` — creates an empty context hashtable from a PropertySet;
  replaces `Get-DefaultContext`.
- `Export-FeatureFlag` — persists a FeatureFlag to disk; replaces
  `Save-FeatureFlag`.
- `Export-PropertySet` — persists a PropertySet to disk; replaces
  `Save-PropertySet`.
- Comprehensive comment-based help with examples for all public functions.
- ADR `adr/0001-rule-accepts-single-condition.md` documenting the
  single-Condition-per-Rule design decision.

### Changed

- `Rule.Conditions` JSON key renamed to `Rule.Condition` (singular) in
  feature flag definition files. Update any existing `.json` flag files
  that use `"Conditions": { ... }` to `"Condition": { ... }`.
- Type accelerator registration is now idempotent: existing accelerators
  are replaced on re-import instead of throwing.
- `adr/` folder moved to the project root (was `docs/adr/`).

### Removed

- `Save-FeatureFlag` — use `Export-FeatureFlag` instead.
- `Save-PropertySet` — use `Export-PropertySet` instead.
- `Get-DefaultContext` — use `New-Context` instead.
- `Read-FeatureFlag` public export — now private; use `Get-FeatureFlag`.
- `Read-PropertySet` public export — now private.
- `ConvertFrom-JsonToHashtable` public export — now private.

### Fixed

- CI: `create_release` and `publish` workflow inputs are now passed
  through to the reusable `PublishModule` workflow so phases can be
  skipped on re-run.

## [0.4.0] 2026-05-14

### Changed

- Logging configuration key renamed from `Warning` to `Warn` to match
  the `Effect` enum. Update any `Configuration.psd1` logging section
  that uses `Warning = @{ ... }` to `Warn = @{ ... }`.
- `FunctionsToExport` in the module manifest now enumerates all 19
  public functions explicitly instead of using a wildcard.
- `ConvertFrom-JsonToHashtable` moved to `ScriptsToProcess` to
  eliminate circular class-loading dependencies.

### Fixed

- `Test-Condition` now captures the result of property validation,
  enforcing the fail-closed contract — a context value violating
  constraints now correctly returns `$false` instead of continuing
  evaluation.
- `PropertyValidation` threshold fields (`Minimum`, `Maximum`,
  `MinLength`, `MaxLength`) changed to `Nullable[int]` so an unconfigured
  constraint is no longer treated as zero.
- `PropertyValidation.ToHashtable` now omits null/unset fields to
  prevent invalid entries in serialized JSON during Save/FromFile
  round-trips.
- `ConditionGroup` constructor now treats JSON-serialized null-valued
  keys as absent, and uses `Property` presence (not `Operator`) as the
  canonical discriminator for leaf vs. group conditions.
- `FeatureFlag` constructor now handles `Version` deserialized as a
  dictionary from `ConvertTo-Json` round-trips.
- `Convert-ToTypedValue` now correctly coerces string values to boolean.
- `PropertyDefinition.Validate` now applies a regex timeout to prevent
  catastrophic backtracking on untrusted input.
- Argument transform attributes (`FeatureFlagTransformAttribute`,
  `PropertySetTransformAttribute`) now reject path traversal sequences.
- Logging script execution hardened against misconfigured or missing
  scripts in `Configuration.psd1`.
- `ConditionGroup` now exposes a `FromJson` static method, enabling
  round-trip deserialization from JSON.
- `ConditionGroup` now detects when two or more mutually exclusive
  group keys (`AllOf`, `AnyOf`, `Not`) are set simultaneously.
- `PropertySet.AddProperty` now keys the property hashtable by name
  correctly.
- `PropertySet` uses `GetFileNameWithoutExtension` instead of `.BaseName`
  on string paths for cross-platform compatibility.
- `New-FeatureFlag` `$Rules` parameter is no longer `Mandatory`, allowing
  flags to be created without initial rules.
- Feature flag evaluation now applies `DefaultEffect` when no terminal
  (`Allow`/`Deny`) rule fires, instead of always returning `$false`.
- Feature flag evaluation uses a labeled `break` to exit the rule loop
  on `Allow`/`Deny`, preventing spurious continued evaluation.
- `Convert-ToTypedValue` source file renamed to match the function name.
- `psake` dependency updated to 5.0.4.

## [0.3.2] 2026-01-30

### Fixed

- Added PowerShell 5.1 compatibility by detecting `Test-Json` availability
  using `Get-Command` instead of version checks, as `PSVersionTable` is not
  available in class static methods. PropertySet files are validated with
  schema in PS 7+ and with basic JSON parsing in PS 5.1.
- Updated fixture tests to skip schema validation test on PowerShell versions
  below 7.

## [0.3.1] 2026-01-23

### Changed

- Refactored logging execution to use dedicated `Invoke-Logging` function for
  improved maintainability and consistency across feature flag evaluation.
- Fixed parameter name in `Test-FeatureFlag` from `Properties` to `PropertySet`
  for consistency with function implementation.

### Fixed

- Fixed variable name reference in `Test-FeatureFlag` from `$Feature` to
  `$FeatureFlag` to correctly process feature flag rules.

## [0.3.0] 2026-01-23

### Added

- `GreaterThanOrEqual` and `LessThanOrEqual` operators to the Operator enum
  for enhanced comparison capabilities in conditions.
- `ConditionGroupTransformAttribute` class to support automatic conversion of
  input values to ConditionGroup objects in function parameters.

### Changed

- `Test-Condition` function now accepts `ConditionGroup` objects instead of
  hashtables for the Condition parameter, providing stronger type safety.
- `Test-Condition` function now accepts `PropertySet` objects instead of a
  generic Properties hashtable for the Properties parameter.
- Internal condition evaluation logic updated to use null checks on
  ConditionGroup object properties instead of hashtable ContainsKey calls.
- Updated corresponding switch statement in `Test-Condition` to handle
  `GreaterThanOrEqual` and `LessThanOrEqual` operators.

## [0.2.0] 2026-01-22

### Added

- Documentation for `ConvertFrom-JsonToHashtable` cmdlet with syntax,
  parameters, and examples for PowerShell 5.1 and 7+ compatibility.
- CLAUDE.md project guidance document with module overview, architecture,
  development commands, testing patterns, and key concepts.

### Changed

- Refactored logging script handling in configuration to support both file
  paths and inline script blocks.
- Enhanced auditing functionality with detailed instructions for configuring
  logging in Configuration.psd1.
- Improved logging configuration options and integrated cached configuration
  in Import-GatekeeperConfig.
- Enhanced Test-FeatureFlag to execute logging scripts based on rule outcomes.
- Updated README with configuration details and logging behavior explanations.

## [0.1.1]

### Changed

- `Read-FeatureFile` uses a new static method to read the file and set the
  FilePath.

## [0.1.0] Initial Release

### Added

- Custom Classes to support the creation and serialization to custom objects for
  FeatureFlags and PropertySets.
- Two JSON Schemas that define what the FeatureFlag and Property json files
  should look like.
- Configuration via the Configuration module to define where the default JSON
  folders would be for new/existing FeatureFlag and PropertySets are.
- Several commands for parsing and evaluating. Quick tl;dr:
  - `Export-GatekeeperConfig`: Exports the current Gatekeeper configuration to
    disk for a specified scope.
  - `Get-DefaultContext`: Returns a hashtable of all property keys from a
    property set with null values.
  - `Get-FeatureFlagFolder`: Gets the folder path where feature flag files are
    stored.
  - `Get-PropertySet`: Retrieves one or all property sets from the default
    property set folder.
  - `Get-PropertySetFolder`: Gets the folder path where property set files are
    stored.
  - `Import-GatekeeperConfig`: Imports the Gatekeeper configuration, optionally
    forcing a reload.
  - `New-Condition`: Creates a new condition for evaluating a property in
    feature flag rules.
  - `New-ConditionGroup`: Creates a new group of conditions joined by a logical
    operator (AllOf, AnyOf, Not).
  - `New-FeatureFlag`: Creates a new feature flag object with specified rules
    and metadata.
  - `New-Property`: Creates a new property definition for use in a property set.
  - `New-PropertySet`: Creates a new property set from a list of property
    definitions.
  - `New-Rule`: Creates a new rule that defines conditions and effects for a
    feature flag.
  - `Read-FeatureFlag`: Reads a feature flag from a JSON file and returns it as
    an object.
  - `Read-PropertySet`: Reads a property set from a JSON file and returns it as
    an object.
  - `Save-FeatureFlag`: Saves a feature flag object to a JSON file.
  - `Save-PropertySet`: Saves a property set object to a JSON file.
  - `Test-Condition`: Evaluates whether a given condition or group of conditions
    matches the provided context and properties.
  - `Test-FeatureFlag`: Checks if a context passes the rules for a specified
    feature flag.

[Unreleased]: https://github.com/HeyItsGilbert/Gatekeeper/compare/1.0.1...HEAD
[1.0.1]: https://github.com/HeyItsGilbert/Gatekeeper/compare/1.0.0...1.0.1
[1.0.0]: https://github.com/HeyItsGilbert/Gatekeeper/compare/0.4.0...1.0.0
[0.4.0]: https://github.com/HeyItsGilbert/Gatekeeper/compare/0.3.2...0.4.0
[0.3.2]: https://github.com/HeyItsGilbert/Gatekeeper/compare/1def993...0.3.2
[0.3.1]: https://github.com/HeyItsGilbert/Gatekeeper/compare/ddef266...1def993
[0.3.0]: https://github.com/HeyItsGilbert/Gatekeeper/compare/077cb1c...ddef266
[0.2.0]: https://github.com/HeyItsGilbert/Gatekeeper/compare/80a2507...077cb1c
[0.1.1]: https://github.com/HeyItsGilbert/Gatekeeper/compare/bfcfee3...80a2507
[0.1.0]: https://github.com/HeyItsGilbert/Gatekeeper/tree/bfcfee3
