# 0007: Bind-time constraint checking for literal condition `Value`s

## Status

Accepted

## Context

[Error model and safe-by-default](https://github.com/HeyItsGilbert/Gatekeeper/issues/96) defined **binding** as checking that a leaf's `Property` exists and that its literal `Value` matches the Property's declared *type* (`definition.value-type`). It did not extend binding to the Property's `Enum` or `Validation` constraints (`Minimum`/`Maximum`/`MinLength`/`MaxLength`/`Pattern`) — those were only ever checked against *Context* values, lazily, at evaluation time (today, via `Property.Validate`; normatively, as a `context.constraint` error per #96).

That leaves a gap: a leaf condition like `Tier Equals 99` where `Tier`'s `Enum` is `[1, 2, 3]`, or `Age GreaterThan 5` where `Age`'s `Validation.Maximum` is `3`, passes binding today even though it can **never** match — the literal `Value` itself already violates the Property's constraints, independent of any Context. Today this either silently never fires, or only surfaces indirectly if a Context happens to contain `99`.

## Decision

Binding checks a leaf's literal `Value` against the **full** `Enum`/`Validation` of its `Property`, not just its type. A violation is a new Definition error code, `definition.constraint`, carrying the offending property — extending the taxonomy from #96 (`definition.schema`, `definition.unknown-property`, `definition.value-type`, `definition.operator-arity`, `context.missing`, `context.type`, `context.constraint`).

This is checked once per leaf at bind time, using the same `Enum`/`Validation` rules decided alongside this ADR:

- `Enum` applies to all three property types (`string`, `integer`, `boolean`), compared per ADR 0002 (ordinal, case-sensitive, strictly typed).
- `Minimum`/`Maximum` are `integer`-typed (widened to signed 64-bit per ADR 0002), inclusive at the boundary; `Minimum > Maximum` on the same Property is `definition.schema`.
- `MinLength`/`MaxLength` count Unicode code points, not UTF-16 code units.
- A `Validation` key that doesn't apply to the Property's declared `Type` (e.g. `Minimum` on a `string` property) is `definition.schema`, enforced by a 2020-12 conditional schema (`if Type == "string" then only Enum/MinLength/MaxLength/Pattern`, etc.) rather than silently ignored.

## Consequences

- New error code: `definition.constraint`. The conformance suite gains cases asserting it for an out-of-`Enum`/out-of-range literal `Value`, distinct from `context.constraint` for the equivalent Context-value failure.
- PS hand-off: the bind step (already being added per #96) must additionally run each leaf's literal `Value` through `Property.Validate`/`Enum` membership, not just a type check; failures become `definition.constraint`, not a lazily-discovered always-false leaf. `Property.ps1`'s `MinLength`/`MaxLength` checks move from `.Length` (UTF-16 units) to code-point counting (e.g. `[System.Globalization.StringInfo]` rune enumeration). `Properties.json` gains the type-conditional restriction on which `Validation` keys are legal per `Type`, and `Minimum`/`Maximum` move from schema `number` to `integer`.
- This closes the same category of gap ADR 0002 closed for comparisons and #96 closed for Context validation: a flag author's mistake is caught once, at load, rather than discovered piecemeal at evaluation time or never.

## Alternatives considered

- **Leave literal-`Value` constraint checking at evaluation time only** (status quo): rejected — it reproduces exactly the "fails somewhere downstream instead of at load" problem #96 already ruled out for Context values, just for the author's own literal instead of the caller's Context.
- **Reuse `context.constraint` for this case too**: rejected — collapsing the two blurs whose fault it is (flag author vs. caller), which is the same distinction `definition.value-type` vs. `context.type` already preserves for type mismatches.
