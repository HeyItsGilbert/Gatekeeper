<center><img src="https://raw.githubusercontent.com/HeyItsGilbert/Gatekeeper/main/static/icon.png" /></center>

# Gatekeeper

Feature flags for PowerShell projects.

[![PowerShell Gallery](https://img.shields.io/powershellgallery/dt/Gatekeeper)](https://www.powershellgallery.com/packages/Gatekeeper/)
[![PowerShell Gallery Version](https://img.shields.io/powershellgallery/v/Gatekeeper)](https://www.powershellgallery.com/packages/Gatekeeper/)
[![GitHub Workflow Status](https://github.com/HeyItsGilbert/Gatekeeper/actions/workflows/Publish.yaml/badge.svg)](https://github.com/HeyItsGilbert/Gatekeeper/actions/workflows/Publish.yaml)
[![PowerShell Gallery](https://img.shields.io/powershellgallery/p/Gatekeeper)](https://www.powershellgallery.com/packages/Gatekeeper/)

Gatekeeper lets you control feature rollouts using JSON-based feature flags with a rule engine. Define properties, write rules, and evaluate them against device context -- all in PowerShell.

**[Read the full documentation](https://heyitsgilbert.github.io/Gatekeeper)**

## Install

```powershell
Install-Module Gatekeeper
```

Works on Windows, Linux, and macOS with PowerShell 5.1+.

## Quick example

```powershell
# Define what properties matter to your org
$props = New-PropertySet -Name 'MyProps' -Properties @(
    (New-Property -Name 'Environment' -Type string -EnumValues @('Production', 'Staging', 'Dev'))
    (New-Property -Name 'IsCompliant' -Type boolean)
)

# Create a rule: allow only compliant staging devices
$conditions = New-ConditionGroup -Operator AllOf -Conditions @(
    (New-Condition -Property 'Environment' -Operator Equals -Value 'Staging')
    (New-Condition -Property 'IsCompliant' -Operator Equals -Value 'true')
)
$rule = New-Rule -Name 'Compliant Staging' -Effect Allow -Conditions $conditions

# Create the flag (deny by default)
$flag = New-FeatureFlag -Name 'NewDashboard' -DefaultEffect Deny -Rules $rule

# Evaluate against a device's context
$context = @{ Environment = 'Staging'; IsCompliant = $true }
Test-FeatureFlag -FeatureFlag $flag -PropertySet $props -Context $context
# Returns: True
```

## Why Gatekeeper?

- **JSON-native** -- flags are JSON files validated by JSON Schema
- **Pluggable context** -- you define properties and context; Gatekeeper doesn't assume your environment
- **Safe by default** -- returns `$false` unless an explicit Allow rule matches
- **No external runtime dependencies** -- just PowerShell and a JSON file
- **Cross-platform** -- Windows, Linux, macOS

## Documentation

| Topic | Description |
|-------|-------------|
| [Getting Started](https://heyitsgilbert.github.io/Gatekeeper/getting-started/) | Install and evaluate your first flag |
| [Concepts](https://heyitsgilbert.github.io/Gatekeeper/concepts/) | Data model, terminology, and how evaluation works |
| [Creating Flags](https://heyitsgilbert.github.io/Gatekeeper/guides/creating-flags/) | Build properties, conditions, rules, and flags |
| [Configuration](https://heyitsgilbert.github.io/Gatekeeper/guides/configuration/) | Multi-level configuration system |
| [Logging](https://heyitsgilbert.github.io/Gatekeeper/guides/logging/) | Audit and warning script setup |
| [Command Reference](https://heyitsgilbert.github.io/Gatekeeper/en-US/) | All exported cmdlets |

## Contributing

See the [CHANGELOG](CHANGELOG.md) for version history.
