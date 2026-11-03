# ADR 0004: `FeatureFlag.Version` is a strict `MAJOR.MINOR.PATCH` string

**Status**: Accepted
**Date**: 2026-10-25

## Context

`FeatureFlag.json` requires `Version` to match `^\d+\.\d+\.\d+$`, but the PowerShell constructor parses it with .NET's `[version]`, which also accepts 2-part (`1.0`) and 4-part (`1.2.3.4`) forms. `FeatureFlag.Save()` (`FeatureFlag.ps1:190-203`) then writes `Version` back out as a `{Major,Minor,Build,Revision}` object, which the constructor reads back in but which violates the schema's string pattern outright. None of this has a portable equivalent: Rust has no `[version]` type with .NET's partial-component parsing, and a round-trippable spec needs one canonical on-disk shape.

## Decision

`Version` is always exactly three dot-separated non-negative integers (`MAJOR.MINOR.PATCH`), serialized as a JSON string. No 2-part or 4-part forms, and no object representation. This matches the existing schema pattern; PowerShell's constructor and `Save()` are fixed to only accept and only emit this form.

## Consequences

- **Breaking**: any flag with a 2-part or 4-part `Version`, or any flag round-tripped through `Save()` (which currently emits an object), must be rewritten to a 3-part string before it validates.
- **Gain**: `Version` becomes a trivial type to port — three integers — instead of carrying .NET's `[version]` parsing rules and object serialization quirk into every implementation.
