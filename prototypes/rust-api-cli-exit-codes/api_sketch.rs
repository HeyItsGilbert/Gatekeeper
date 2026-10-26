// PROTOTYPE — throwaway sketch for issue #101, NOT the real gatekeeper-rs crate.
// Signatures only; bodies elided with `todo!()`. Pins down module layout, the hook API,
// the Decision/Error shapes, and the public entry points. Delete once lifted.
//
// Crate layout:
//   src/lib.rs        — re-exports the public surface below
//   src/types.rs       — Effect, Decision
//   src/error.rs        — Error, DefinitionErrorCode, ContextErrorCode, violations
//   src/property.rs      — PropertySet, PropertyDefinition, PropertyType
//   src/flag.rs           — FeatureFlag, Rule, Condition, Operator
//   src/context.rs         — Context, ContextValue
//   src/observe.rs          — Observer trait, Event
//   src/eval.rs               — bind + validate + evaluate (crate-private core)
//   src/bin/gatekeeper.rs      — thin CLI (clap v4), depends only on the public surface

// ===== src/types.rs =====

/// All four rule/default effects. Only `Allow`/`Deny` ever become a final `Decision`;
/// `Audit`/`Warn` are observed (see `observe.rs`) and never terminate evaluation on their
/// own — mid-list they log and fall through to the next rule, and as `DefaultEffect` they
/// log and resolve to `Deny` (settled in #96).
pub enum Effect {
    Allow,
    Deny,
    Audit,
    Warn,
}

/// The only two outcomes `evaluate()` can return on success. Deliberately narrower than
/// `Effect`: a type that can't express "decision was Audit" can't misroute a caller into
/// treating a non-terminal effect as a gate.
pub enum Decision {
    Allow,
    Deny,
}

// ===== src/error.rs =====

/// Fail-closed error, matching #96's two outcome classes. Each class carries the *set* of
/// violations found — binding and context validation both collect everything wrong rather
/// than stopping at the first, so the conformance suite can assert on the full set.
pub enum Error {
    Definition(Vec<DefinitionViolation>),
    Context(Vec<ContextViolation>),
}

pub struct DefinitionViolation {
    pub code: DefinitionErrorCode,
    /// `None` for a flag-level problem (e.g. schema failure) that isn't about one property.
    pub property: Option<String>,
}

pub enum DefinitionErrorCode {
    Schema,
    UnknownProperty,
    ValueType,
    OperatorArity,
}

pub struct ContextViolation {
    pub code: ContextErrorCode,
    pub property: String,
}

pub enum ContextErrorCode {
    Missing,
    Type,
    Constraint,
}

// ===== src/property.rs =====

pub struct PropertySet {
    // property name -> definition
}

pub struct PropertyDefinition {
    pub property_type: PropertyType,
    pub r#enum: Option<Vec<ContextValue>>,
    pub validation: Option<Validation>,
}

pub enum PropertyType {
    String,
    Integer,
    Boolean,
}

pub struct Validation {
    pub minimum: Option<i64>,
    pub maximum: Option<i64>,
    pub min_length: Option<usize>, // Unicode scalar count, not UTF-16 units (#98)
    pub max_length: Option<usize>,
    pub pattern: Option<String>, // restricted ECMA-262 subset, #93/#98
}

impl PropertySet {
    /// Entry point 1: load + mandatory schema validation (ADR 0005). Schema failure is a
    /// `Definition(Schema)` violation, never a panic or a silently-skipped check.
    pub fn from_json(json: &str) -> Result<PropertySet, Error> {
        todo!()
    }
}

// ===== src/flag.rs =====

pub struct FeatureFlag {
    pub name: String,
    pub version: String, // strict MAJOR.MINOR.PATCH string, ADR 0004 — never a parsed struct
    pub default_effect: Effect,
    pub rules: Vec<Rule>, // may be empty
}

pub struct Rule {
    pub name: String,
    pub effect: Effect,
    pub condition: Condition,
}

pub enum Condition {
    AllOf(Vec<Condition>),
    AnyOf(Vec<Condition>),
    Not(Vec<Condition>), // NOR over 1+ children, ADR 0003
    Leaf {
        property: String,
        operator: Operator,
        value: ContextValue,
    },
}

pub enum Operator {
    Equals,
    NotEquals,
    GreaterThan,
    GreaterThanOrEqual,
    LessThan,
    LessThanOrEqual,
    In,
    NotIn,
}

impl FeatureFlag {
    /// Entry point 2: load + mandatory schema validation (ADR 0005).
    pub fn from_json(json: &str) -> Result<FeatureFlag, Error> {
        todo!()
    }

    /// Entry point 3: bind + validate the Context up front, flag-scoped (#96 step 1-2),
    /// without evaluating. Exposed on its own so a caller (or the CLI `check` subcommand)
    /// can distinguish "this Context is bad" from "evaluation says Deny" without paying
    /// for, or triggering observation events from, a full evaluate().
    pub fn validate_context(
        &self,
        properties: &PropertySet,
        context: &Context,
    ) -> Result<(), Error> {
        todo!()
    }

    /// Entry point 4: the one true evaluation call. After bind + validate this is total —
    /// it cannot fail (#96 step 3) — so the `Result` only ever carries a *pre-evaluation*
    /// error. `observer` receives one `Event` per terminal or default-effect outcome,
    /// matching #99's unified payload; a panicking/erroring observer never affects the
    /// returned `Decision` (hook isolation, #99).
    pub fn evaluate(
        &self,
        properties: &PropertySet,
        context: &Context,
        observer: &dyn Observer,
    ) -> Result<Decision, Error> {
        todo!()
    }

    /// Fails closed: `Err(_)` and `Decision::Deny` both read as `false`. Convenience for
    /// callers who only ever wanted a bool and don't care which error fired.
    pub fn is_enabled(
        &self,
        properties: &PropertySet,
        context: &Context,
        observer: &dyn Observer,
    ) -> bool {
        matches!(self.evaluate(properties, context, observer), Ok(Decision::Allow))
    }
}

// ===== src/context.rs =====

pub struct Context {
    // property name -> value; a missing key and an explicit JSON null are both "absent"
    // (#96) — there is no tri-state here, only present-with-a-typed-value or absent.
}

pub enum ContextValue {
    String(String),
    Integer(i64),
    Boolean(bool),
}

// ===== src/observe.rs =====

/// Sync only, by design: the library makes no assumption about an async runtime, and the
/// existing PS scriptblock hook is synchronous. A host that wants async dispatch spawns
/// from inside its `Observer` impl.
pub trait Observer {
    fn observe(&self, event: &Event);
}

/// Blanket impl so `|event| { ... }` closures and plain `fn` pointers satisfy `Observer`
/// without a wrapper type — mirrors how trivial a PS scriptblock hook is to attach.
impl<F: Fn(&Event)> Observer for F {
    fn observe(&self, event: &Event) {
        self(event)
    }
}

/// Does nothing; the default when a caller doesn't pass an observer.
pub struct NoopObserver;
impl Observer for NoopObserver {
    fn observe(&self, _event: &Event) {}
}

/// One unified shape for all four effects plus the error path (#99). `Decision` fires for
/// *every* terminal/default outcome, not just Audit/Warn — no asymmetry where Allow/Deny
/// are silent.
pub enum Event {
    Decision {
        flag_name: String,
        flag_version: String,
        rule_name: Option<String>, // None when DefaultEffect fired with no rule match
        effect: Effect,
        is_default: bool,
    },
    /// A fail-closed error never looks like a rule said Deny — distinct variant, carries
    /// the same (code, property) shape the Result's Error carries.
    Error {
        code: String, // e.g. "context.missing", "definition.unknown-property"
        property: Option<String>,
    },
}

// ===== src/bin/gatekeeper.rs =====
//
// Thin CLI, two subcommands, clap v4 derive. No logic lives here beyond argument parsing,
// wiring a stderr-printing Observer, and mapping the library Result onto an exit code.
//
//   gatekeeper eval   --flag <path> --properties <path> --context <path|k=v,k=v,...>
//   gatekeeper check  --flag <path> --properties <path> [--context <path|k=v,...>]
//
// `eval` runs evaluate() and prints `{"decision":"Allow"|"Deny"}` to stdout.
// `check` runs from_json() on both files (and validate_context() if a Context is given)
// without evaluating — for CI/pre-flight use, where you want a Definition/Context error
// without the side effect of an observation event firing.
//
// Every Event the Observer receives is printed as one JSON line to stderr (suppressed by
// `--quiet`); Audit/Warn are visible *only* on that stream, never through exit status —
// the exit code reflects the final Decision/Error only.
//
// fn main() -> std::process::ExitCode {
//     match run() {
//         Ok(Decision::Allow) => ExitCode::from(0),
//         Ok(Decision::Deny) => ExitCode::from(1),
//         Err(Error::Context(violations)) => {
//             eprint_json(&violations);
//             ExitCode::from(2)
//         }
//         Err(Error::Definition(violations)) => {
//             eprint_json(&violations);
//             ExitCode::from(3)
//         }
//     }
// }
