# Gatekeeper conformance suite

A portable, language-neutral set of evaluation cases. Both the PowerShell
module (via Pester) and the Rust client (via `cargo test`) load the same
JSON and assert the same outcome, so neither implementation can drift from
the spec on its own.

> **Prototype status.** This directory is the output of a `wayfinder`
> prototype ticket (issue #100), reacted to and then folded into the real
> spec work. The format below is deliberately small: a handful of cases per
> category, enough to prove the shape, not an exhaustive port of every
> existing Pester expectation.

## Layout

```
conformance/
├── property-sets/   shared PropertySet fixtures, referenced by relative path
├── flags/            shared FeatureFlag fixtures, referenced by relative path
└── cases/            one JSON array of cases per category
```

`property-sets/` and `flags/` hold the fixtures every case links to — kept
out of `cases/*.json` so the same flag or PropertySet can be reused by many
cases without duplication, the same way `tests/fixtures/` works today.

## Case shape

```jsonc
{
  "name": "deny-before-allow-wins",          // unique, kebab-case
  "description": "…",                         // optional, one line
  "kind": "condition" | "flag",
  "propertySet": "../property-sets/basic.json",
  "condition": { … } | "../path/to/condition.json",   // kind: condition
  "flag": { … } | "../flags/startup-sound.json",       // kind: flag
  "context": { "Environment": "Staging", … },
  "expect": {
    // kind: condition — the condition's own boolean result
    "result": true,

    // kind: flag — the Decision (effect, bool, matching rule, default-ness)
    "decision": { "effect": "Allow", "result": true, "ruleName": "AllowRule", "isDefault": false },

    // optional on flag cases — the observation events fired, in order
    // (issue #99's unified payload is {FlagName, FlagVersion, RuleName,
    // Effect, IsDefault}; a case only needs to assert the fields that vary
    // per case, since FlagName/FlagVersion are fixed by which flag the case
    // names)
    "events": [ { "ruleName": "AllowRule", "effect": "Allow", "isDefault": false } ],

    // mutually exclusive with result/decision — a failed-closed outcome.
    // "property" is null for a definition error that isn't property-scoped
    // (e.g. a structurally invalid Condition).
    "error": { "pairs": [ { "code": "context.missing", "property": "Environment" } ] }
  }
}
```

`condition`/`flag`/`propertySet` accept either an inline object (for small,
case-specific fixtures, the common case for `effects.json`) or a path
relative to the case file, for a larger shared fixture reused across cases
(`groups.json`'s `nested-allof-anyof` case points at
`flags/startup-sound.json`). Both languages resolve the same way: inline
means "parse this object", a string means "load this file" — which is
exactly what `FeatureFlagTransformAttribute`/`ConditionTransformAttribute`
already do in PowerShell, so the suite format rides the existing transform,
not a new one.

Error cases key on `(code, property)` pairs, matching issue #96: never on
message text, because messages aren't spec. `pairs` is a set — order
doesn't matter, and a case may list more than one when the up-front,
flag-scoped context validation is expected to collect multiple violations
(`context-validation-collects-every-violation`).

## Running it

**PowerShell (Pester):** `tests/Conformance.tests.ps1` discovers every file
under `conformance/cases/`, builds one Pester `It` per case via `-ForEach`,
and calls `Test-Condition`/`Test-FeatureFlag` the same way the existing
`Test-Condition.tests.ps1`/`Test-FeatureFlag.tests.ps1` do. It runs as part
of `.\build.ps1 -Task Test` alongside the rest of the suite.

**Rust (planned, `gatekeeper-rs` not yet built — see issue #92):** a
`#[test]` fixture walks `conformance/cases/*.json` with `serde_json`,
deserializes each case into a `ConformanceCase` struct mirroring the shape
above, and calls `PropertySet::load` / `Condition::evaluate` /
`FeatureFlag::evaluate`. `expect.decision`/`result` assert on `Ok(..)`;
`expect.error` asserts on `Err(Error { code, property })` matching every
pair in the set. Fixture paths resolve the same way (relative to the case
file) so the loader is one function shared by every `#[test]`, not
duplicated per case. This is a plan, not working code: the crate doesn't
exist in this repo yet, and building it is outside this map's destination.

## Migrating the ~30 existing Pester expectations

`tests/Test-Condition.tests.ps1` and `tests/Test-FeatureFlag.tests.ps1`
assert the same things these cases do, just inline in PowerShell and
unreachable from Rust. The migration is mechanical, one `It` at a time:

1. Lift the `$condition`/`$flag`, `$context` and expected `Should` value out
   of the `It` block into a case object (`cases/operators.json`,
   `cases/groups.json` and `cases/effects.json` already port a
   representative slice — `equals`/`notequals`/ordering operators,
   `AllOf`/`AnyOf`/`Not` short-circuiting, effect/ordering/`DefaultEffect`
   fallback).
2. Where the existing `It`'s title doubled as documentation, keep that in
   `description`.
3. `Should -Invoke -CommandName Invoke-Logging -ParameterFilter { $Effect -eq 'Allow' }`
   assertions become an `events` entry.
4. Delete the ported `It`. `tests/Conformance.tests.ps1` is the replacement,
   not an addition — once every case is ported, `Test-Condition.tests.ps1`
   and `Test-FeatureFlag.tests.ps1` only keep PowerShell-specific concerns
   (pipeline behaviour, argument transforms, path validation) that aren't
   part of the language-neutral spec.

## Handling the broken fixtures

The two bugs flagged in the baseline scout (`tests/fixtures/FeatureFlag.json`
referencing the undefined property `Percent` instead of `Percentage`;
`tests/fixtures/Updawg.json` referencing the undefined property `Tier`) are
**not** carried into this suite unfixed:

- **`Percent`/`Percentage`.** `flags/startup-sound.json` here uses the
  correct `Percentage`, matching issue #96's hand-off item ("Fix
  `fixtures/FeatureFlag.json`: change `Percent` to `Percentage`"). The *bug
  shape itself* — a leaf naming a property the bound PropertySet doesn't
  declare — is kept on purpose as its own fixture,
  `flags/broken-property-ref.json`, driving the
  `definition-unknown-property-reference` case in `cases/errors.json`. That
  turns an accidental fixture/schema mismatch into a deliberate
  `definition.unknown-property` conformance case.
- **`Tier`.** `property-sets/basic.json` declares `Tier`, so
  `flags/updawg.json` binds cleanly and is usable as-is (see
  `nested-allof-anyof`-style cases).

## Current status against the real module

Running `tests/Conformance.tests.ps1` today exercises the real
`Test-Condition`/`Test-FeatureFlag` entry points as they exist *before* the
issue #96/#97/#98/#99 hand-off lands: **24 pass, 3 fail, 6 skip.**

`cases/operators.json`, `cases/groups.json` and `cases/effects.json` mostly
pass already — first-match-wins, `Audit`/`Warn` as non-terminal, and
`DefaultEffect` fallback are already implemented as decided. Three cases
currently fail, each pinned to a specific, already-decided hand-off item:

- `equals-string-case-sensitive-no-match` — today's `-eq` is
  case-insensitive; ADR 0002 requires ordinal, case-sensitive comparison.
- `default-effect-allow-no-rule-matches` and
  `default-effect-warn-no-rule-matches-still-denies` — today's
  `Test-FeatureFlag` never calls `Invoke-Logging` for the `DefaultEffect`
  fallback path; issue #99 requires a `RuleName: null, IsDefault: true`
  event there too.

`cases/errors.json` is skipped (`-Skip`, not deleted): fail-closed error
records, up-front flag-scoped context validation, and bind-time
unknown-property/schema checks are hand-off work this map lists but does
not execute. The case file is the acceptance criteria for that hand-off;
un-skipping it and watching it go green is how that work gets proven done.
