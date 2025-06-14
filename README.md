<center><img src="https://raw.githubusercontent.com/HeyItsGilbert/Gatekeeper/main/static/icon.png" /></center>

# Gatekeeper

Helps implement feature flags in your PowerShell projects.

[![PowerShell Gallery](https://img.shields.io/powershellgallery/dt/Gatekeeper)](https://www.powershellgallery.com/packages/Gatekeeper/)
[![PowerShell Gallery Version](https://img.shields.io/powershellgallery/v/Gatekeeper)](https://www.powershellgallery.com/packages/Gatekeeper/)
[![GitHub Workflow Status](https://img.shields.io/github/actions/workflow/status/HeyItsGilbert/Gatekeeper/Publish.yaml)](https://www.powershellgallery.com/packages/Gatekeeper/)
[![PowerShell Gallery](https://img.shields.io/powershellgallery/p/Gatekeeper)](https://www.powershellgallery.com/packages/Gatekeeper/)

## Overview

This module is meant to allow you to easily create and use feature flags written
in JSON. The module offers the ability to easily create new FeatureFlag files
and leaves it up to you on how to distribute them.

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

## To Do

- [ ] Function to create PropertySet
- [ ] Class for FeatureFlag
- [ ] Evaluate performance
- [ ] Handle fetching/caching feature flags
- [ ] Script level variables for defining where to get/set json files.
- [ ] Function to create property in PropertySet
- [ ] Ability to create PropertySet in memory and then ability to save to disk.
- [ ] Define auditing method that users can overwrite
- [ ] Publish schemas somewhere consistent with some type of versioning
- [ ] CRUD for creating condition
- [ ] TUI?
- [ ] Support for evaluating remote device
