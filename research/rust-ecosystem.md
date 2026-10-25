# Rust ecosystem: JSON Schema validation and recursive Condition parsing

Ticket: #94 (map #92). Facts and options only; the recommendation at the end is input for a later decision.

Context in this repo: `Gatekeeper/Schemas/FeatureFlag.json` declares draft 2020-12 (and uses `pattern`).
`Gatekeeper/Schemas/Properties.json` declares draft-07 and uses `"format": "regex"`. So a Rust client needs
both dialects, and it needs `format: regex` to be *asserted*, not just annotated.

## 1. JSON Schema validator crates

Data from the crates.io API on 2026-10-25 (`https://crates.io/api/v1/crates/<name>`).

| Crate | Latest | Downloads | Last release | License | Drafts |
|---|---|---|---|---|---|
| [`jsonschema`](https://github.com/Stranger6667/jsonschema) | 0.60.1 | ~108.7M | 2026-10-23 | MIT | 4, 6, 7, 2019-09, 2020-12 |
| [`boon`](https://github.com/santhosh-tekuri/boon) | 0.6.1 | ~650k | 2025-01-07 | MIT OR Apache-2.0 | 4, 6, 7, 2019-09, 2020-12 |
| `valico` | 4.0.0 | ~22.8M | 2023-05-13 | MIT | draft-07 at most; inactive |
| [`jsonschema-valid`](https://github.com/mdboom/jsonschema-valid) | 0.5.2 | ~600k | 2023-11-08 | MPL-2.0 | up to draft-07; inactive |

Only `jsonschema` and `boon` cover **both** draft-07 and 2020-12 and are still maintained.

### `jsonschema` (Stranger6667)
- Maturity: the de facto standard crate. It releases often, is pre-1.0 (0.x, so expect breaking bumps), and also ships Python (`jsonschema-rs`) and Ruby bindings. Docs: <https://docs.rs/jsonschema>.
- Compliance: the crate docs say "Compliance levels vary across drafts, with newer versions having some unimplemented keywords". Live per-draft numbers: <https://bowtie.report/#/implementations/rust-jsonschema>.
- `format`: draft-dependent by default. In 2019-09/2020-12, `format` is an annotation unless you call `.should_validate_formats(true)` (docs, "Note on `format` keyword").
- `format: regex`: `is_valid_regex` calls `jsonschema_regex::is_valid_ecma_regex`, an ECMA-262 syntax check (source: `crates/jsonschema/src/keywords/format.rs`, around L1092–1104 at v0.60.1). It has a regression test for ECMA-only syntax such as `\cc` (GH-230).
- `pattern`/`patternProperties` engine: `fancy-regex` by default (backtracking; supports lookaround and backrefs). You can set `PatternOptions::fancy_regex().backtrack_limit(n)`, or switch to `PatternOptions::regex()`. The docs say the `regex` crate "guarantees linear-time matching, preventing potential Denial of Service attacks", but lookbehind and backrefs then fail.
- Extras: Structured Output v1 (flag/list/hierarchical), structured `ValidationErrorKind`, instance paths, compile-time `#[jsonschema::validator]` macro, custom formats and keywords, WASM.

### `boon` (santhosh-tekuri)
- Maturity: smaller, single-maintainer, last release Jan 2025. It is a port of the author's Go `santhosh-tekuri/jsonschema` and has a companion CLI, `boon-cli`.
- Compliance: the README says it passes JSON-Schema-Test-Suite "excluding optional" for all five drafts, and it carries Bowtie badges (<https://bowtie.report/#/implementations/rust-boon>). It also passes `optional/ecmascript-regex.json`.
- `format: regex`: `formats.rs::validate_regex` → `ecma::convert`. This parses with `regex-syntax`'s AST and rewrites ECMA constructs into Rust regex syntax, so a pattern that cannot be expressed in the `regex` crate is rejected.
- `pattern` engine: the `regex` crate (a dependency; no `fancy-regex`), so matching is linear-time. Lookaround and backrefs are not supported.
- Format assertions need a flag for draft ≥ 2019-09 (`--assert-format` in the CLI). Errors are introspectable and hierarchical, with flag/basic/detailed output.

### The regex question for the spec (cross-ref RegexResearch ticket)
- In both crates, `format: regex` means "valid **ECMA-262** regex". It does not mean .NET regex, which is what the PowerShell implementation uses at runtime. A pattern can be accepted by the schema and still behave differently in .NET (or the reverse). [INFERENCE]: the spec has to name one regex dialect, or a safe subset, for the `Matches`-style operator and for `format: regex`.
- Engine trade-off: `regex` gives linear time and DoS safety but has no lookaround. `fancy-regex` supports lookaround but backtracks; the backtrack limit can be set.

## 2. serde shape for the recursive, mutually exclusive Condition

Target grammar: `{AllOf:[C..]}` | `{AnyOf:[C..]}` | `{Not: C}` | `{Property, Operator, Value}`. Mixed or unknown keys must be rejected.

I ran a throwaway prototype (serde 1, serde_json 1) on six inputs. The table shows the actual error output.

| Input | A. `#[serde(untagged)]` enum + `deny_unknown_fields` structs | C. custom `Deserialize` |
|---|---|---|
| valid nested AllOf | ok | ok |
| `AllOf` + leaf keys mixed | `data did not match any variant of untagged enum C` | `condition mixes group keys (AllOf/AnyOf/Not) with leaf keys (Property/Operator/Value)` |
| `AllOf` + `AnyOf` | same generic message | `condition must have exactly one of AllOf, AnyOf, Not` |
| leaf missing `Value` (nested) | same generic message | ``missing field `Value` `` |
| typo `Propety` | same generic message | ``unknown field `Propety`, expected one of `Property`, `Operator`, `Value` `` |
| `{"Not":{"Not":{"Bogus":1}}}` | same generic message | ``unknown field `Bogus`, expected one of ...`` |

### Option A: untagged enum + `deny_unknown_fields` on each variant struct
- It rejects everything correctly, because each variant struct refuses foreign keys.
- Error quality is poor. serde reports only "did not match any variant", with no path and no reason (see the serde docs on [untagged](https://serde.rs/enum-representations.html#untagged)). It also re-parses every variant from buffered `Content`, so cost grows with nesting depth.

### Option B: externally tagged enum for groups (`enum Group { AllOf(Vec<C>), AnyOf(Vec<C>), Not(Box<C>) }`)
- The serde [externally tagged](https://serde.rs/enum-representations.html) representation needs exactly one key, so it naturally rejects `{AllOf, AnyOf}`.
- It cannot express the leaf on its own, because the leaf is untagged. It therefore has to be combined with A or C. Used as the group half of C (which is what the prototype does), it gives good errors for free.
- Caveat: `deny_unknown_fields` does not compose with `#[serde(flatten)]` (see the [serde docs on container attrs](https://serde.rs/container-attrs.html#deny_unknown_fields)). Avoid flatten-based designs.

### Option C: custom `Deserialize` (the prototype)
- Buffer into `serde_json::Map`, then classify keys: group keys present, leaf keys present, both, or more than one group key. Emit a precise `Error::custom`, then dispatch to the derived `Group` or `Leaf` (`deny_unknown_fields`).
- This gives the best messages and keeps the rest derived. It is about 15 lines.
- Costs: it is tied to `serde_json::Value` buffering, so it is not format-agnostic unless written with a `MapAccess` visitor. Errors raised through `from_value` lose line and column. Fix this with the `MapAccess` visitor approach, or wrap the top-level call with [`serde_path_to_error`](https://docs.rs/serde_path_to_error) to get a JSON path like `Rules[0].Conditions.AllOf[2]`.
- Open spec point: key **case sensitivity**. PowerShell hashtables and `ConvertFrom-Json` match property names case-insensitively, while serde is case-sensitive. The spec should fix this either way. [INFERENCE]

### Belt and braces
Because the Rust client validates against the JSON Schema first (section 1), shape errors can be caught there too. If the schema encodes the exclusivity with `oneOf` and `additionalProperties: false`, you get schema-path errors as well. The serde layer then guarantees typed correctness even when validation is skipped.

## 3. CLI (brief)
`clap` v4 with the derive API (`#[derive(Parser)]`, subcommands via `#[derive(Subcommand)]`) is the convention (<https://docs.rs/clap>). Common companions are `anyhow` or `miette` for error reporting, and documented exit codes. For example, `boon-cli` uses 1 for bad args and 2 for validation errors.

## Recommendation (input only, not a decision)
- Validator: `jsonschema`, for its maturity, release cadence, one crate for both drafts, structured errors, and selectable regex engine. Pin a 0.x minor version, enable `should_validate_formats(true)`, and consider `PatternOptions::regex()` for DoS safety. `boon` is a credible fallback if the spec mandates strict ECMA conformance with a linear-time engine.
- Condition parsing: Option C (a custom `Deserialize` that dispatches to an externally tagged `Group` enum and a `deny_unknown_fields` `Leaf`), plus `serde_path_to_error` for paths. Avoid a bare untagged enum because of its error quality.
