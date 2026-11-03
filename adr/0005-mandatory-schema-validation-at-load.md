# ADR 0005: Schema validation is mandatory at load, not optional

**Status**: Accepted
**Date**: 2026-10-25

## Context

Today, `FeatureFlag.json` is never checked at runtime at all — only the Pester test suite validates fixtures against it. `Properties.json` is checked via `Test-Json -SchemaFile` only when that cmdlet exists (`Property.ps1:123-131`), so it's silently skipped on PowerShell 5.1. A malformed flag or property set (wrong types, bad `oneOf` shape, unknown keys) can load and evaluate today; only an unrelated downstream throw (or silent wrong behavior) surfaces the problem, if anything does. The glossary already defines **Definition error** as "the `FeatureFlag` or `PropertySet` is invalid on its own" — which presumes something actually checks that.

## Decision

A conforming implementation MUST validate both the `FeatureFlag` and the `PropertySet` against their JSON Schemas before binding or evaluation proceeds. A schema violation is a Definition error. This is not optional and not skippable on any supported host — PowerShell drops its PS 5.1 `Test-Json`-availability skip as part of this change.

## Consequences

- **Breaking**: any currently-loadable-but-schema-invalid flag or property set (e.g. anything hitting the disagreements catalogued in the map's baseline comment — stray `Not` shapes, unknown rule keys, non-string `Version`) now fails to load with a Definition error instead of loading successfully.
- **Gain**: "Definition error" becomes a real, checked guarantee instead of aspirational glossary text — a flag that loads is schema-valid, in every implementation, every time.
- **Cost**: PowerShell can no longer skip schema validation on 5.1; it needs a schema-validation path that doesn't depend on `Test-Json`.
