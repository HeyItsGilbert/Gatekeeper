# ADR 0001: Rule accepts a single pre-built Condition

**Status**: Accepted  
**Date**: 2026-05-16

## Context

`New-Rule` previously accepted multiple `Condition` objects via pipeline and silently wrapped them in an implicit `AllOf`. This meant:

- `New-Rule -Conditions $c1, $c2` silently produced `AllOf($c1, $c2)`.
- Passing a pre-built composite `Condition` alongside a leaf produced a nested `AllOf` the caller couldn't see.
- `Rule.Conditions` was named plural but held a single `ConditionGroup` object.

## Decision

`New-Rule` accepts exactly one `Condition` via `-Condition` (singular). The caller is responsible for composing multiple comparisons into a `Condition` tree using `New-Condition` and `New-ConditionGroup` before passing it to the rule.

`Rule.Condition` is renamed to singular to match.

## Consequences

- **Breaking**: callers passing multiple conditions to `New-Rule` must be updated to wrap them in `New-ConditionGroup` explicitly.
- **Gain**: the logical structure of a rule's condition is always visible at the call site. No hidden `AllOf` injection.
- **Gain**: `New-Rule` is simpler — no `begin`/`process`/`end` pipeline accumulation needed.
