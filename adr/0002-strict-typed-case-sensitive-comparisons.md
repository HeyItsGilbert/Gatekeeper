# ADR 0002: Comparisons are strictly typed and case-sensitive

**Status**: Accepted
**Date**: 2026-10-25

## Context

PowerShell's `Test-Condition` compares values using native operators (`-eq`, `-gt`, `-contains`) after coercing the Context value to the Property's declared type via `[int]`/`[bool]`/`[string]` casts. This makes string comparison culture-aware case-insensitive, lets `"0x10"` coerce to `16`, rounds `2.5` to `2` (banker's rounding), accepts `"1"`/`"0"`/`"true"`/`"false"` as booleans, and orders booleans (`false < true`). None of this is portable: Rust has no culture-aware string collation without pulling in ICU, and the coercion table has no single portable definition every implementation could replicate bit-for-bit.

## Decision

The spec defines comparisons as strict and case-sensitive:

- **No coercion.** A Context value's JSON type must match the Property's declared type exactly (`string`→JSON string, `integer`→JSON number with zero fractional part, `boolean`→JSON boolean). A mismatch is a `context.type` error, never a silent cast. The same rule applies to a leaf `Value` at definition time (`definition.value-type`).
- **Integer range is signed 64-bit** (widened from PS's `Int32`), and "integer" is a numeric test (zero fractional part), not a lexical one — `5`, `5.0`, and `5e0` all qualify; `5.5` does not.
- **String comparison is case-sensitive, ordinal.** `Equals`/`NotEquals`/`In`/`NotIn` compare bytes, not culture-folded text.
- **Ordering operators (`GreaterThan`/`LessThan`/`…OrEqual`) apply only to `integer` properties.** Strings and booleans have no portable or domain-meaningful ordering here, so applying an ordering operator to a non-integer property is a definition-time error.
- **Enum and key spellings are exact-case.** `Operator`/`Effect` values and JSON object keys (`AllOf`, `Condition`, …) must match case; no `"allow"`/`"equals"`-style folding.

## Consequences

- **Breaking**: PS flags/contexts relying on coercion (numeric strings, hex, boolean-spelling, case-insensitive string match, string/boolean ordering, lowercase enum values) must be updated; ships under a major version bump per the spec's own `specVersion`.
- **Gain**: comparison semantics are now a small, portable, byte-exact rule set a conformance suite can assert directly, instead of a PowerShell cast table every implementation would need to replicate.
- **Gain**: integer range widens (Int32 → i64), which is purely additive — no currently-valid flag or context becomes invalid.
