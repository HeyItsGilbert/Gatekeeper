<center><img src="https://raw.githubusercontent.com/HeyItsGilbert/Gatekeeper/main/static/icon.png" /></center>

# Gatekeeper

Helps implement feature flags in your PowerShell projects.

[![PowerShell Gallery](https://img.shields.io/powershellgallery/dt/Gatekeeper)](https://www.powershellgallery.com/packages/Gatekeeper/)
[![PowerShell Gallery Version](https://img.shields.io/powershellgallery/v/Gatekeeper)](https://www.powershellgallery.com/packages/Gatekeeper/)
[![GitHub Workflow Status](https://img.shields.io/github/actions/workflow/status/HeyItsGilbert/Gatekeeper/Publish.yaml)](https://www.powershellgallery.com/packages/Gatekeeper/)
[![PowerShell Gallery](https://img.shields.io/powershellgallery/p/Gatekeeper)](https://www.powershellgallery.com/packages/Gatekeeper/)

## Overview

Easily create and use feature flags written in JSON. Offers the ability to
easily create new FeatureFlag files and leaves it up to you on how to distribute
them.

## Installation

```powershell
Install-Module Gatekeeper
```

## Why?

I had a desire for an easy to use rule system that allowed me to specifically
target devices. I love JSON schemas (I know I know, I have a problem) and I
thought that with a tightly schematized rule and property system this could make
an easy to build open tool.

This was also a challenge for myself to leverage JSON, classes, and the ability
to serialize custom objects.

## Goals

1. Allow easy gate keeping of new features by offering a simple
   `Test-FeatureFlag` command to add to any conditional logic.
2. Leverage JSON because it's a format that can be generated/distributed easily
   by various public/private tools.
3. Use JSON schemas to ensure that different aspects of the system are easily
   enforced. And more importantly that tools guide users on how to fill these
   files out.
4. Allow properties and property sets to be organic and not baked into this
   tool. This means that you can support any business logic that makes sense for
   you and your organization.
5. Ensure flexibility by allowing context, properties, and feature flags to be
   defined outside of this tool, while still enforcing the schema.
6. Err on the side of caution when possible during evaluations.

> [!IMPORTANT]
> The decision to allow context, properties, and flags to come from
> external sources was deliberate to allow you to plug this into any system/tool
> you want.

## Terminology

- Feature Flag: This is a name for feature you want to be able to flip on or off
  given a set of conditions.
- Context: A hash table that defines a devices context. Context can be defined
  by whatever tooling you're using. (i.e. ohai, script, etc.).
- Properties: These are units that define different business logic groupings.
  These could be things like the hostname, environment, etc. The properties file
  defines the type and possible validations for each property.
- PropertySet: This is a collection of properties.
- Rules: This is a list of conditions to check against. These evaluated top/down
  and the first Allow/Deny wins.
- Conditions: These are sets of properties to match with the given context.
  There are higher level groupings such as `AnyOf`, `OneOf`, and `Not` available
  to join these. The conditions are composed of a `Property`, an `Operator`, and
  a `Value`.
- Effect: The effect defines what should happen when a given rule matches. These
  include: `Allow, Deny, Audit, and Warn`.

## Examples

### Creating a PropertySet

Create a set of properties we want to evaluate.

```json
{
    "$schema": "https://raw.githubusercontent.com/HeyItsGilbert/Gatekeeper/main/Gatekeeper/Schemas/Properties.json",
    "Percentage": {
        "Type": "integer",
        "Validation": {
            "Minimum": 0,
            "Maximum": 99
        }
    },
    "Environment": {
        "Type": "string",
        "Enum": [
            "Production",
            "Staging",
            "Dev"
        ]
    },
    "IsCompliant": {
        "Type": "boolean"
    }
}
```

This defines a percentage property that must be an integer between 0-99, an
environment string thats limited to Production, Stage, or Dev, and a boolean
named IsCompliant. Note that these don't see how these properties are calculated
only their type and how to validate them.

For our later examples I'll save this as `properties.json`

### Feature Flag

Next we will create a feature flag.

```json
{
    "$schema": "https://raw.githubusercontent.com/HeyItsGilbert/Gatekeeper/main/Gatekeeper/Schemas/FeatureFlag.json",
    "Name": "New Startup Sound",
    "Description": "Roll out new screaming goat start up sound.",
    "Version": "1.0.0",
    "Author": "Your Name aka who to e-mail when customers are upset",
    "Tags": [
        "Goat",
        "Managed"
    ],
    "DefaultEffect": "Deny",
    "Rules": [
        {
            "Name": "Audit staging",
            "Effect": "Audit",
            "Conditions": {
                "Property": "Environment",
                "Operator": "Equals",
                "Value": "Staging"
            }
        },
        {
            "Name": "Warn Production",
            "Effect": "Warn",
            "Conditions": {
                "Property": "Environment",
                "Operator": "Equals",
                "Value": "Production"
            }
        },
        {
            "Name": "Allow Staging and Complaint or 10%",
            "Effect": "Allow",
            "Conditions": {
                "AllOf": [
                    {
                        "AnyOf": [
                            {
                                "Property": "IsCompliant",
                                "Operator": "Equals",
                                "Value": "true"
                            },
                            {
                                "Property": "Percent",
                                "Operator": "LessThan",
                                "Value": "11"
                            }
                        ]
                    },
                    {
                        "Property": "Environment",
                        "Operator": "Equals",
                        "Value": "Staging"
                    }
                ]
            }
        }
    ]
}
```

We'll save this as `NewStartUpSound.json`.

Note that how this feature is implemented isn't part of the file. That's because
this is purely to define what should get this feature. We have a name and
description to allow users/developers/etc. to understand what feature this is
for. A version allows tracking of changes. An email allows teams to understand
who to reach out for with questions or concerns.

The real power is in the rules. Rules are evaluated top down and the first
`Allow` or `Deny` wins. `Audit` and `Warn` won't stop evaluations, but will take
their respective action.

### Defining the Context

The last step in evaluating whether a flag passes/fails is to provide context
for the device.

Context can be composed however you wish as long as the final output is a hash
table.

To make it easy to start you can create an empty hash using your property set
file.

```pwsh
$propertySet = Get-PropertySet -FilePath 'myProperties.json'
$context = Get-DefaultContext -Properties $propertySet
```

That would make `$context` a hash table with 3 keys (each with an $null value)
that matches the property set: `Percentage`, `Environment`, and `IsComplaint`.

I'll define these manually but you can imagine this could be a call to another
tool, etc. Or maybe this is just a file you store on disk.

```pwsh
$context['Percentage'] = 30
$context['Environment'] = 'Production'
$context['IsCompliant'] = $true
```

> [!NOTE]
> Another value add of this not being hard coded is that you can create a mock
> context object to see how it would apply. Or you could create a function to
> determine another devices context values and see how it would apply before
> ever rolling out the change.

### Evaluating the Feature Flag

Now that the context, property set, and feature flag have been defined we can
evaluate if the flag applies to the current device.

```powershell
Test-FeatureFlag -Feature 'NewStartUpSound' -Context $context -Properties $propertySet
```

The feature flag will be loaded from disk and each rule will be evaluated.

The first rule is:

```json
{
    "Name": "Audit staging",
    "Effect": "Audit",
    "Conditions": {
        "Property": "Environment",
        "Operator": "Equals",
        "Value": "Staging"
    }
}
```

Because the `Environment` property in the Context is `Production` this rule does
not apply and is skipped.

```json
{
    "Name": "Warn Production",
    "Effect": "Warn",
    "Conditions": {
        "Property": "Environment",
        "Operator": "Equals",
        "Value": "Production"
    }
}
```

This rule would apply because the only condition checks if it's the `Production`
environment. Because the Effect is `Warn` the command will write a warning to
the screen and move to the next rule.

```json
{
    "Name": "Allow Staging and Complaint or 10%",
    "Effect": "Allow",
    "Conditions": {
        "AllOf": [
            {
                "AnyOf": [
                    {
                        "Property": "IsCompliant",
                        "Operator": "Equals",
                        "Value": "true"
                    },
                    {
                        "Property": "Percent",
                        "Operator": "LessThan",
                        "Value": "11"
                    }
                ]
            },
            {
                "Property": "Environment",
                "Operator": "Equals",
                "Value": "Staging"
            }
        ]
    }
}
```

The first (and only condition) is an `AllOf` which means the items in it must
both evaluate to true. The first item in that group is an `AnyOf` which means
that either of the values can be true.

Because the device context has `IsCompliant` to true, then the first condition
matches. Then we proceed back up to the second item in the `AllOf` condition.
This one again matches on environment, but is false because the context has
environment set to `Production`.

Because one of the items in the `AllOf` condition failed, then the rule is
skipped.

Because there are no more rules, we apply the effect from the `DefaultEffect`
property.

> [!IMPORTANT]
> The `Test-FeatureFlag` command will always default to $False if the default
> effect is not an approval. This protects against accidentally opening a
> feature when your default is warn or audit.

## Configuration

| Key        | Description                                                                                         | Default |
|------------|-----------------------------------------------------------------------------------------------------| -|
| `Version`    | The version of the configuration file, used for safe upgrades.                                      | `0.1.0` |
| `FilePaths`  | An object containing paths to important folders, such as Schemas.                                   | Objects |
| `FilePaths.Schemas` | The path to the the Schemas on disk. | `Schemas` in Module directory |
| `FilePaths.FeatureFlags` | The path to the the FeatureFlags on disk. | `$null`. ^[1] |
| `FilePaths.PropertySet` | The path to the the PropertySet's on disk. | `$null`. ^[1] |
| `Logging`    | An object defining logging behaviors for different rule outcomes (Allow, Deny, Warning, Audit).     | Object with `Allow`, `Deny`, `Warning`, and `Audit` defined. |
| `Logging.Allow`      | Logging settings for allowed rules, including whether logging is enabled and the script to execute. | See the [Logging](#logging) table |
| `Logging.Deny`       | Logging settings for denied rules, including whether logging is enabled and the script to execute.  | See the [Logging](#logging) table |
| `Logging.Warning`    | Logging settings for warning rules, including whether logging is enabled and the script to execute. | See the [Logging](#logging) table |
| `Logging.Audit`      | Logging settings for audit rules, including whether logging is enabled and the script to execute.   | See the [Logging](#logging) table |

[^1]: These folders are evaluated during a run and the configuration is saved
  to disk. These default to the same folder as the machine wide configuration.

### Loading Precedent

Configuration begins by loading the
[Configuration.psd1](config) from the module.
Then it loads the machine-wide settings (e.g. `$Env:ProgramData` or
`/etc/xdg/`). Then it imports the users' enterprise roaming settings (e.g. from
`$Env:AppData` (the roaming path) or `~/.local/share/`). Finally it imports the
users' local settings (from `$Env:LocalAppData` or `~/.config/`).

> [!NOTE]
> All the logic of placing configuration is thanks to the Configuration module.

## Logging

Logging is defined in the configuration file and can be a a path on disk or a
scriptblock. Either should accept a `$Rule` parameter (but don't necessarily
need to use it).

The default configuration has the Allow and Deny logging rule set to disable to
avoid cluttering the screen. The default warning will `Write-Warning` to let you
know the rule would have passed.

| Logging Level | Enabled  | Default                                                      |
|---------------|----------|--------------------------------------------------------------|
| Allow         | Disabled | `Write-Host "✅ Rule [$($Rule.Name)] matched and is allowed"` |
| Deny          | Disabled | `Write-Host "⛔ Rule [$($Rule.Name)] matched and is denied."` |
| Warning       | Enabled  | `Write-Warning "⚠️ Rule [$($Rule.Name)] matched."`           |
| Audit         | Enabled  | `Write-Host "Audit: $($Rule.Name)"`                          |

The most obvious logging method to overwrite will be `Audit`. In your
[configuration file](#configuration) you will need to overwrite the script
block.

### Changing Auditing Function

To change your auditing function you need to update your `Configuration.psd1` to
contain something like the following:

```powershell
Logging = @{
    ... # Your other logging functions (if any)
    Audit = @{
        # Ensure it's enabled
        Enabled = $true
        Script = {
            param($Rule)
            $line = "✅ Rule [$($Rule.Name)] matched and is allowed."
            $line | Out-File C:\Contoso\Logs\Gatekeeper.log -Append
        }
    }
}
```

Here is an example if you prefer to use a script from disk.

Let's say you have a script called `C:\Contoso\Logging.ps1`. That script writes
to a log file. The script could look something like :

```powershell
param($Rule)
$line = "✅ Rule [$($Rule.Name)] matched and is allowed."
$line | Out-File C:\Contoso\Logs\Gatekeeper.log -Append
```

Then you would update your configuration to look like:

```powershell
Logging = @{
    ... # Your other logging functions (if any)
    Audit = @{
        # Ensure it's enabled
        Enabled = $true
        Script = 'C:\Contoso\Logging.ps1'
    }
}
```

> [!IMPORTANT]
> If you supply a string, it must be a valid path to a script file
> that accepts the `$Rule` parameter.

# ToDo List

These are items that may or may not be setup.

- [ ] Evaluate performance
- [ ] Support for evaluating remote device
