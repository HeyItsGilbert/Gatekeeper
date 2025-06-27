# Change Log

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/)
and this project adheres to [Semantic Versioning](http://semver.org/).

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
