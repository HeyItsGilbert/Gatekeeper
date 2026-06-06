# Gatekeeper — Domain Glossary

## Condition
A single evaluable expression. Can take two forms:
- **Leaf**: a comparison of a context property against a value using an `Operator` (e.g. `Environment Equals Production`)
- **Composite**: a logical grouping of child Conditions using `AllOf`, `AnyOf`, or `Not`

Both forms are the same concept. The leaf and composite are not different constructs — they are two modes of a single recursive type. The class is canonically named `Condition`.

> Previously named `ConditionGroup` in code. That name implied the type was always a group, which it isn't.

---

## PropertySet
The schema that defines what properties are valid in a Context. Each entry is a `Property` with a type (`string`, `integer`, `boolean`) and optional validation constraints (min/max, enum, regex pattern).

> Persistence: `Get-PropertySet` (public, cached), `Read-PropertySet` (private I/O), `Export-PropertySet` (write to disk). Previously `Save-PropertySet` — `Save-` is not an approved PowerShell verb.

## Property
A single entry within a `PropertySet`. Describes the type (`string`, `integer`, `boolean`) and validation rules for one context key. Created via `New-Property`.

> Previously named `PropertyDefinition` — the "Definition" suffix added no information. A `PropertySet` contains `Property` objects; `New-Property` returns a `[Property]`.

## Context
A hashtable of actual runtime values representing the current device or environment state. Keys must correspond to properties declared in the `PropertySet`. Provided by the caller — Gatekeeper does not own or fetch it.

> `New-Context` constructs an empty context (all keys present, all values `$null`) from a `PropertySet`. The caller then populates the values. Previously named `Get-DefaultContext` — "default" implied pre-filled values, which was wrong.

## FeatureFlag
Defines a feature, its `DefaultEffect`, and an ordered list of `Rules`. Evaluated top-to-bottom; first terminal rule wins.

> Loading pattern: `Get-FeatureFlag` is the public API (module-scoped cache). `Read-FeatureFlag` is the private I/O primitive it delegates to. Mirrors the PropertySet pattern.

## Rule
A named pair of a single `Condition` and an `Effect`. When the `Condition` matches the `Context`, the `Effect` is applied. A `Rule` holds exactly one `Condition` — if multiple comparisons are needed, they must be composed into a `Condition` tree before being passed to the `Rule`.

## Effect
The outcome applied when a `Rule` matches. Values: `Allow`, `Deny`, `Audit`, `Warn`. `Allow` and `Deny` are terminal (stop evaluation). `Audit` and `Warn` are non-terminal (log and continue).

## Operator
A comparison operator used in a leaf `Condition`. Values: `Equals`, `NotEquals`, `GreaterThan`, `GreaterThanOrEqual`, `LessThan`, `LessThanOrEqual`, `In`, `NotIn`.

> Distinct from **logical connectives** (`AllOf`, `AnyOf`, `Not`), which are grouping modes on a composite `Condition` — not operators. `New-ConditionGroup` exposes these as three distinct parameter sets (`-AllOf`, `-AnyOf`, `-Not`) rather than a single `-Operator` parameter.
