# ADR 0003: `Not` takes an array of children with NOR semantics

**Status**: Accepted
**Date**: 2026-10-25

## Context

`FeatureFlag.json`'s `oneOf` for `condition` models `Not` as `{Not: <single condition object>}` — plain negation of one child. `guides/evaluation.md` instead shows `Not` taking an array. The PowerShell constructor (`FeatureFlag.ps1:56-58`) already accepts either shape, and `Test-Condition` evaluates a `Not` by iterating its children and returning `false` if *any* child matches — i.e. NOR over a list, not negation of a single condition. The schema is the odd one out: it's narrower than what the code and docs already do.

## Decision

The spec defines `Not` as taking an array of 1 or more child Conditions (`minItems: 1`), with NOR semantics: the `Not` matches only when *none* of its children match. A single condition is expressed as a 1-element array; there is no separate single-object shape. This matches the existing PowerShell evaluation behavior and the docs; the schema is fixed to match.

## Consequences

- **Breaking for schema consumers only**: any flag authored against the old single-object `Not` shape (`{Not: {...}}`) must be rewritten as `{Not: [{...}]}`. No PowerShell evaluation behavior changes, since the code already accepted and evaluated arrays this way.
- **Gain**: one shape for `Not` instead of two, and it's strictly more capable (NOR over N) than plain negation (NOR over 1), so no expressiveness is lost.
