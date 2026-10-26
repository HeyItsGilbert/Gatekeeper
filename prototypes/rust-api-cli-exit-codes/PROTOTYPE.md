# PROTOTYPE — throwaway, answers issue #101 only

**Question:** with the error model (#96) and observation hook contract (#99) settled, what
is the Rust crate/CLI's public surface — module layout, hook registration API, `Decision`/
`Error` shapes, public entry points, CLI subcommand layout, and how the four `Effect` values
plus the two error classes map onto a process exit code?

This is not the real `gatekeeper-rs` crate. It's two disposable artifacts to react to:

- `api_sketch.rs` — a module-layout + type-signature sketch (no implementation bodies, no
  `cargo` project, won't compile standalone) that pins down the shape the two questions in
  #101 are actually asking about. Lift the validated shape into the real crate's module
  structure when `gatekeeper-rs` is created; delete this file.
- `exit-code-demo.html` — double-click, no install. A free-play + guided-walkthrough demo of
  the trickiest part on paper: how `Decision`/`Error`/`Effect` interact across Allow, Deny,
  mid-list Audit/Warn (non-terminal), `DefaultEffect` Audit/Warn (terminal, per #96), a
  Definition error, a Context error with *multiple* collected violations, and a hook that
  throws — to land on one exit-code table.

## Answer (captured on resolution of #101)

See the resolution comment on issue #101 for the accepted shape. Gist: `evaluate()` returns
`Result<Decision, Error>` where `Decision` is only ever `Allow`/`Deny` (Audit/Warn are
never a final decision, only observation events — matching the existing PS behaviour that
non-terminal effects log and continue); CLI exit codes are `0=Allow, 1=Deny, 2=ContextError,
3=DefinitionError`, with Audit/Warn visible only through the observation hook's stderr
stream, never through exit status.
