# Getting Started

This guide takes you from installation to evaluating your first feature flag.

## Install

```powershell
Install-Module Gatekeeper
```

Gatekeeper supports PowerShell 5.1+ on Windows, Linux, and macOS.

## 1. Define your properties

A **PropertySet** describes the context your rules will evaluate against. Think of it as a schema for your device metadata.

```powershell
$props = New-PropertySet -Name 'OrgProperties' -Properties @(
    (New-Property -Name 'Environment' -Type string -EnumValues @('Production', 'Staging', 'Dev'))
    (New-Property -Name 'Tier' -Type integer -Validation @{ Minimum = 1; Maximum = 3 })
    (New-Property -Name 'IsCompliant' -Type boolean)
)
```

Save it to disk so other tools and flags can reference it:

```powershell
$props | Save-PropertySet
```

## 2. Create a feature flag

A feature flag contains rules that decide who gets the feature. Rules are evaluated top-down; the first `Allow` or `Deny` wins.

```powershell
# Build conditions
$condition = New-Condition -Property 'Environment' -Operator Equals -Value 'Staging'

# Build a rule
$rule = New-Rule -Name 'Allow Staging' -Effect Allow -Conditions $condition

# Build the flag
$flag = New-FeatureFlag -Name 'NewDashboard' -DefaultEffect Deny -Rules $rule
$flag | Save-FeatureFlag
```

This flag allows the feature in Staging and denies it everywhere else.

## 3. Build your context

Context is a hashtable representing the current device's state. You populate it however makes sense for your environment -- a script, a config management tool, an API call.

```powershell
$context = Get-DefaultContext -PropertySet $props
$context['Environment'] = 'Staging'
$context['Tier'] = 1
$context['IsCompliant'] = $true
```

## 4. Evaluate

```powershell
$enabled = Test-FeatureFlag -FeatureFlag 'NewDashboard' -PropertySet $props -Context $context
if ($enabled) {
    # Feature is on for this device
    Enable-NewDashboard
}
```

That's the complete workflow: define properties, create a flag, provide context, evaluate.

## Working with JSON directly

Gatekeeper flags and property sets are JSON files validated against schemas. You can author them by hand or with any tool that produces JSON.

**PropertySet (`properties.json`):**

```json
{
    "$schema": "https://raw.githubusercontent.com/HeyItsGilbert/Gatekeeper/main/Gatekeeper/Schemas/Properties.json",
    "Environment": {
        "Type": "string",
        "Enum": ["Production", "Staging", "Dev"]
    },
    "IsCompliant": {
        "Type": "boolean"
    }
}
```

**Feature flag (`NewDashboard.json`):**

```json
{
    "$schema": "https://raw.githubusercontent.com/HeyItsGilbert/Gatekeeper/main/Gatekeeper/Schemas/FeatureFlag.json",
    "Name": "NewDashboard",
    "Description": "Roll out the new dashboard UI.",
    "Version": "1.0.0",
    "Author": "platform-team@contoso.com",
    "DefaultEffect": "Deny",
    "Rules": [
        {
            "Name": "Allow Staging",
            "Effect": "Allow",
            "Conditions": {
                "Property": "Environment",
                "Operator": "Equals",
                "Value": "Staging"
            }
        }
    ]
}
```

Load and evaluate:

```powershell
$props = Read-PropertySet -FilePath ./properties.json
$flag  = Read-FeatureFlag -FilePath ./NewDashboard.json
$ctx   = @{ Environment = 'Staging'; IsCompliant = $true }

Test-FeatureFlag -FeatureFlag $flag -PropertySet $props -Context $ctx
# True
```

## Next steps

- [Concepts](concepts.md) -- understand the data model
- [Creating Feature Flags](creating-flags.md) -- complex rules, conditions, and operators
- [How Evaluation Works](evaluation.md) -- what happens inside `Test-FeatureFlag`
