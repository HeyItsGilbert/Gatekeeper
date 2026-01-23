# Change Log

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/)
and this project adheres to [Semantic Versioning](http://semver.org/).

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
