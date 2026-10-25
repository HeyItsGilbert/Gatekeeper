# Regex portability: ECMA-262, .NET, Rust `regex` / `fancy-regex`

Ticket: #93 (map #92). All sources below were opened and checked on 2026-10-25. Facts and options only; the decision belongs to *Enum enforcement and Validation semantics*.

## Where Gatekeeper uses regex today

- `Gatekeeper/Schemas/Properties.json`: `Validation.Pattern` is `"type": "string", "format": "regex"`.
- `Gatekeeper/Classes/Property.ps1` L85: `[regex]::new($Pattern, RegexOptions::None, 250ms)` then `IsMatch($Value)`. That is **unanchored search**, .NET backtracking engine, culture-sensitive defaults, and a timeout that is caught and treated as a failed validation (returns `$false`).

## What JSON Schema 2020-12 says

- `format: "regex"` means "a valid regular expression according to the ECMA-262 dialect" ([Validation §7.3.8](https://json-schema.org/draft/2020-12/json-schema-validation#section-7.3.8)). `format` is annotation-only by default, so validators may not check it.
- Core [§6.4 Regular Expressions](https://json-schema.org/draft/2020-12/json-schema-core#section-6.4): keywords using regex "SHOULD" be valid ECMA-262, and the spec **recommends a portable subset** for interoperability: Unicode characters, simple character classes `[abc]`, ranges `[a-z]`, complemented classes `[^abc]`, `[^a-z]`, quantifiers `+ * ? {n} {n,} {n,m}` (and lazy versions), anchors `^` `$`, grouping `( )`, alternation `|`. The same section says regexes "SHOULD be built with the `u` flag (or equivalent)" and that implementations "MUST NOT take regular expressions to be anchored". Validation §7.3.8 adds that implementations validating `format` "MUST accept at least" this subset.
- [RFC 9485 I-Regexp](https://www.rfc-editor.org/rfc/rfc9485) (Oct 2023) is a stricter interoperable profile written with JSONPath/JSON Schema in mind: no backreferences, no lookaround, no flags, no `^`/`$` anchors. Matching uses XSD semantics (§4), i.e. the whole string; the non-normative §5.3 ECMAScript mapping wraps the pattern in `^(?:` … `)$` with the `u` flag and rewrites `.` to `[^\n\r]`, and §5.4 uses `\A(?:` … `)\z` for PCRE/RE2/Ruby. Only general categories are allowed in `\p{..}`/`\P{..}` (no scripts or blocks). Multi-char escapes such as `\d` and `\S` are **not** supported (§5.1 suggests `[0-9]`). §6 says implementations of the subset "can, with care, be designed to generally run in linear time", and §8 covers security. JSON Schema 2020-12 does **not** reference RFC 9485; it predates it. RFC 9535 JSONPath `match()`/`search()` uses I-Regexp, with `search()` showing how to do unanchored use (wrap with `.*`).

## Feature matrix

| Feature | ECMA-262 (`u` off/on) | .NET `RegexOptions.None` | Rust `regex` | `fancy-regex` |
|---|---|---|---|---|
| Lookahead `(?=)` `(?!)` | yes | yes | **no** (parse error) | yes |
| Lookbehind `(?<=)` `(?<!)` | yes (ES2018) | yes | **no** | yes; variable-length via default `variable-lookbehinds` feature |
| Backreferences `\1` | yes | yes | **no** | yes |
| Named groups | `(?<n>)` | `(?<n>)`, `(?'n')` | `(?P<n>)`, `(?<n>)` | same as regex |
| Atomic/possessive | no | `(?>)` | no | `(?>)` |
| `\d` | ASCII `[0-9]` | **Unicode Nd** (unless `ECMAScript` option) | **Unicode Nd** (ASCII with `(?-u)`) | as regex |
| `\w`, `\b` | ASCII (plus ſ/K with `u`+`i`) | Unicode (L*, Mn, Nd, Pc) | Unicode | as regex |
| `\p{..}` | only with `u`/`v` flag | yes (blocks `IsGreek`, categories; no scripts) | yes (categories, scripts, binary props) | as regex |
| `.` | not `\n`,`\r`,`\u2028/9`; UTF-16 unit unless `u` | not `\n`; UTF-16 unit | not `\n`; Unicode scalar | as regex |
| Case-insensitive | `i` flag (pattern-external); bounded `(?i:…)` modifiers only from ES2025 (no unbounded `(?i)`) | `(?i)` inline; culture-sensitive unless `CultureInvariant` | `(?i)` inline; Unicode simple case folding | as regex |
| `$` without multiline | end of input only | end **or before a final `\n`** | end of input only | as regex |
| `\z` / `\A` | none | yes | yes | yes |
| Implicit anchoring | none (`test` searches) | none (`IsMatch` searches) | none (`is_match` searches) | none |
| Complexity | backtracking, no bound | backtracking; `NonBacktracking` (.NET 7+) linear, rejects atomic groups, backrefs, balancing groups, conditionals, lookarounds, `\G` | **guaranteed O(m·n)** | linear when pattern has no fancy features (delegates to `regex`); backtracking otherwise |
| ReDoS mitigation | none in spec; host-specific | `matchTimeout` → `RegexMatchTimeoutException` | not needed; `size_limit`/`dfa_size_limit` cap compile size | `backtrack_limit` (default 1,000,000) → error |

Sources: [ECMA-262 RegExp §22.2](https://tc39.es/ecma262/#sec-regexp-regular-expression-objects) (`\d` = ten-element set 0–9; `WordCharacters` = ASCII; `$` matches only at input end unless multiline); [RegExp modifiers proposal (stage 4, ES2025)](https://github.com/tc39/proposal-regexp-modifiers) / [finished proposals](https://github.com/tc39/proposals/blob/main/finished-proposals.md); [.NET regex language quick reference](https://learn.microsoft.com/dotnet/standard/base-types/regular-expression-language-quick-reference); [.NET anchors (`$` before final `\n`)](https://learn.microsoft.com/dotnet/standard/base-types/anchors-in-regular-expressions); [.NET options incl. ECMAScript, CultureInvariant, NonBacktracking, AnyNewLine (.NET 11)](https://learn.microsoft.com/dotnet/standard/base-types/regular-expression-options); [.NET character classes (`\d`=`\p{Nd}`, `\w`)](https://learn.microsoft.com/dotnet/standard/base-types/character-classes-in-regular-expressions); [.NET regex best practices / timeouts](https://learn.microsoft.com/dotnet/standard/base-types/best-practices-regex); [Rust `regex` syntax](https://docs.rs/regex/latest/regex/#syntax) and [untrusted input](https://docs.rs/regex/latest/regex/#untrusted-input); [`fancy-regex` docs](https://docs.rs/fancy-regex/latest/fancy_regex/) and [`RegexOptionsBuilder::backtrack_limit`](https://docs.rs/fancy-regex/latest/fancy_regex/struct.RegexOptionsBuilder.html#method.backtrack_limit) (default 1,000,000, returns `Error::BacktrackLimitExceeded`); JSON-Schema-Test-Suite [`optional/ecmascript-regex.json`](https://github.com/json-schema-org/JSON-Schema-Test-Suite/blob/main/tests/draft2020-12/optional/ecmascript-regex.json) (cases: "$ does not match trailing newline", "\d matches ascii digits only", "\w matches ascii letters only").

## Divergences that bite portability

1. `\d`, `\w`, `\b` are ASCII in ECMA, Unicode in .NET and Rust. `^\d+$` accepts `"١٢٣"` (Arabic-Indic) in .NET/Rust, rejects in JS.
2. `$` in .NET matches before a trailing newline: `^abc$` matches `"abc\n"` in .NET, not in ECMA/Rust. Validation bypass risk.
3. Lookaround/backrefs: valid in ECMA and .NET, rejected at compile time by Rust `regex`.
4. Case-insensitivity: ECMA has no in-pattern flag before ES2025; .NET and Rust accept `(?i)`. .NET case folding is culture-dependent (Turkish `I`).
5. Unicode classes `\p{L}` need ECMA `u` flag; .NET lacks script names (`\p{Greek}` is `\p{IsGreek}` block); Rust supports both.
6. Performance: only Rust `regex` (and .NET `NonBacktracking`) guarantee linear time. .NET timeout and fancy-regex step limit are not equivalent units, so "timed out" results differ across implementations.

## Common portable core

The JSON Schema §6.4 subset is accepted with identical meaning by all four engines, **provided** the spec also forbids or pins: shorthand classes `\d \w \s \b` (or defines them as ASCII and implementations translate), `$` (or define as end-of-string; .NET must use `\z` or `RegexOptions.ECMAScript`-like rewriting), and `.` vs line terminators. RFC 9485 I-Regexp is the strictest published subset; all four engines can run it after the §5 rewrite, and it avoids every construct that needs backtracking. Its whole-string matching differs from JSON Schema `pattern` and Gatekeeper's current unanchored `IsMatch`.

## Options (input only, not a decision)

- **A. JSON Schema §6.4 subset, unanchored** — matches current behavior and the schema; spec must pin `\d`/`$` semantics and implementations must enforce the subset at load time. Rust can use `regex` only.
- **B. RFC 9485 I-Regexp** — citable standard, linear-time everywhere, Unicode properties included; breaking change to whole-string anchoring (or spec a `search` wrapper as RFC 9535 does).
- **C. Full ECMA-262** — matches `format: regex` literally; Rust needs `fancy-regex` (or a JS engine), .NET needs `RegexOptions.ECMAScript` (which itself disallows many constructs) and still diverges; ReDoS requires a non-portable limit.
- Orthogonal: replace .NET timeout with `RegexOptions.NonBacktracking` (.NET 7+, PS 7.3+) to match Rust's linear guarantee; not available on Windows PowerShell 5.1.

**Recommendation (input only):** A or B, both rejecting lookaround/backrefs so Rust uses the linear `regex` crate and the timeout becomes a defense-in-depth detail rather than a semantic. Conformance tests should include `\d` vs non-ASCII digits, `abc\n` vs `$`, and a catastrophic pattern like `(a+)+$`.
