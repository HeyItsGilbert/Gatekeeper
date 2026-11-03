# 0006: Restricted regex subset for `Validation.Pattern`

## Status

Accepted

## Context

`Property.Validation.Pattern` is matched today with .NET regex (`RegexOptions.None`, unanchored `IsMatch`, 250ms timeout). The `Properties.json` schema only annotates it `format: regex` (an ECMA-262 hint that no validator enforces). Neither pins a portable flavor, and the three available engines disagree in ways that matter for a Rust client:

- `\d`/`\w`/`\b` are ASCII-only in ECMA-262 but Unicode-aware in .NET and in Rust's `regex` crate.
- .NET's `$` also matches before a trailing `\n`; ECMA-262's does not.
- Lookaround and backreferences work in ECMA-262 and .NET, but Rust's `regex` crate rejects both in exchange for a worst-case linear-time guarantee; supporting them would require `fancy-regex`, which enforces a backtrack-step limit instead of a wall-clock timeout — a different ReDoS story than PS's 250ms timeout.

[Regex portability across ECMA-262, .NET and Rust](https://github.com/HeyItsGilbert/Gatekeeper/issues/93) is the fact-finding behind this decision; see its resolution for full source citations (JSON Schema 2020-12 §6.4/§7.3.8, RFC 9485, ECMA-262 §22.2, docs.rs for `regex`/`fancy-regex`).

## Decision

`Pattern` is restricted to the JSON Schema 2020-12 §6.4 portable subset: literals, character classes/ranges/negation, quantifiers (including lazy forms), `^`/`$`, groups and alternation. Within that subset:

- No lookaround and no backreferences — this is what lets the Rust client use the plain `regex` crate (linear-time, no backtrack-limit tuning) instead of `fancy-regex`.
- `\d`, `\w` and `\b` are ASCII-only in every implementation — Rust's `regex` crate and .NET both default to Unicode-aware classes, so both must opt out explicitly (`(?-u:\d)` equivalents / `RegexOptions.ECMAScript` in .NET; Rust `regex` needs the ASCII-only class forms) to agree with ECMA-262.
- Matching is unanchored (`IsMatch`-style substring search), matching today's PS behavior and JSON Schema §6.4's "MUST NOT treat patterns as anchored" guidance.
- A `Pattern` that fails to compile under this subset (uses a banned construct, or isn't valid regex at all) is a `definition.schema` error at load — never discovered later as a runtime failure or timeout.

## Consequences

- The Rust client validates and matches `Pattern` with the `regex` crate alone; no `fancy-regex` dependency, no backtrack-limit tuning.
- PS hand-off: `Property.Validate` must force ASCII-only `\d`/`\w`/`\b` (today's `RegexOptions.None` is Unicode-aware) and must reject lookaround/backreferences at **load** time rather than letting them compile silently. The 250ms `RegexMatchTimeoutException` path becomes largely moot once catastrophic-backtracking constructs are rejected at load, but stays as a defense-in-depth backstop.
- Conformance suite needs cases for: a non-ASCII digit against `\d` (must not match), `"abc\n"` against a pattern ending in `$` (must not match, unlike .NET's default), and a banned construct like `(a+)+$` or `(?=...)` (must be a `definition.schema` error, not a slow match).

## Alternatives considered

- **RFC 9485 I-Regexp**: more restrictive than needed — no `\d`/`\w` at all, whole-string XSD matching semantics instead of substring search. Rejected as an unfamiliar surprise for flag authors writing an ordinary substring pattern.
- **Full ECMA-262**: keeps lookaround and backreferences, which defeats the Rust client's linear-time guarantee without pulling in `fancy-regex` and its backtrack-limit knob. Rejected to keep the Rust evaluation core dependency-light and worst-case bounded.
