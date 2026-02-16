# Gatekeeper

**Feature flags for PowerShell projects.**

[![PowerShell Gallery](https://img.shields.io/powershellgallery/dt/Gatekeeper)](https://www.powershellgallery.com/packages/Gatekeeper/)
[![PowerShell Gallery Version](https://img.shields.io/powershellgallery/v/Gatekeeper)](https://www.powershellgallery.com/packages/Gatekeeper/)
[![GitHub Workflow Status](https://github.com/HeyItsGilbert/Gatekeeper/actions/workflows/Publish.yaml/badge.svg)](https://github.com/HeyItsGilbert/Gatekeeper/actions/workflows/Publish.yaml)

---

Gatekeeper lets you control feature rollouts using JSON-based feature flags with a rule engine. Define properties, write rules, and evaluate them against device context -- all in PowerShell.

```powershell
Install-Module Gatekeeper
```

## Quick example

You have a new feature. You want it enabled only in Staging for compliant devices. Here's the entire workflow:

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

That's it. One boolean tells your code whether to enable the feature.

## Why use feature flags?

Feature flags decouple **deployment** from **release**. You can ship code to all environments and then control who sees it through configuration, not code branches.

Common use cases:

- **Staged rollouts** -- enable a feature for 10% of devices, then 50%, then everyone
- **Environment gating** -- test in Staging before Production
- **Compliance enforcement** -- only allow features on compliant devices
- **Kill switches** -- instantly disable a feature without redeploying
- **Canary testing** -- target specific device tiers or groups

## Why Gatekeeper specifically?

- **JSON-native** -- flags are JSON files validated by JSON Schema, easy to generate, distribute, and version
- **Pluggable context** -- you define properties and context; Gatekeeper doesn't assume your environment
- **Safe by default** -- evaluation returns `$false` unless an explicit Allow rule matches
- **No external dependencies at runtime** -- just PowerShell and a JSON file
- **Cross-platform** -- works on Windows, Linux, and macOS (PowerShell 5.1+)

## Who is this for?

| Audience | Use case |
|----------|----------|
| **DevOps / Platform Engineers** | Control feature rollouts across environments and deployment rings |
| **IT Admins / Endpoint Managers** | Gate software features based on device compliance, OS version, or group membership |
| **PowerShell Module Authors** | Ship experimental features behind flags in your own modules |
| **Security / Compliance Teams** | Enforce policy-based access to features using auditable JSON rules |
| **QA / Release Engineers** | Manage canary releases and A/B testing with targeted conditions |

## Next steps

- [Getting Started](getting-started.md) -- install and evaluate your first flag
- [Concepts](concepts.md) -- understand the data model and terminology
- [Creating Feature Flags](guides/creating-flags.md) -- build flags step by step
- [How Evaluation Works](guides/evaluation.md) -- learn the rule engine
