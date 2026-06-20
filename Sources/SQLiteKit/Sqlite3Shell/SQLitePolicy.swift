import Foundation

/// Trusted, embedder-set security policy for the `sqlite3` shell port.
///
/// **Control surface (why this is not a set of argv flags).** When the command
/// is installed as a SwiftBash builtin, an LLM agent writes the command line —
/// so any hardening expressed as an *opt-in* flag is no boundary at all: the
/// same agent simply omits it, inflates it, or redirects it. The policy is
/// therefore bound by the **trusted embedder** at registration
/// (`Sqlite3Builtin(policy:)`) or derived automatically from the host shell's
/// sandbox, and the argv layer may only ever *tighten* it, never relax it (the
/// only argv lever, `-hardened`, can turn hardening on but not off — see
/// `Parser` / `Sqlite3Executable.run`).
///
/// Hardened mode deliberately does **not** touch the SQL feature surface: it
/// sets resource limits, pins temp storage, caps result output, and records an
/// attempted-audit trail, but it does not deny virtual tables, functions, or
/// PRAGMA — so `sqlite-vec` (`vec0`) and FTS5 workloads keep working.
public struct SQLitePolicy: Sendable {

    /// Master switch for the hardened-mode runtime controls. When `false` the
    /// command behaves exactly like stock sqlite3 (the default for the
    /// standalone human CLI and for a shell with no sandbox bound).
    public var hardened: Bool

    /// Maximum rendered result bytes emitted across a run before output is
    /// truncated. `nil` means unbounded. This bounds what flows back into an
    /// LLM's context or a `$(…)` capture buffer; it is an *output* bound, not
    /// an engine-memory bound (a true row cap needs the SDK stepping API).
    public var maxResultBytes: Int?

    /// Wall-clock **script budget** checked between statements. `nil` means no
    /// budget. NOTE: this is not a per-query interrupt — it cannot stop a
    /// single long-running statement (e.g. a recursive CTE); that requires the
    /// SDK progress handler + `sqlite3_interrupt`.
    public var statementTimeout: TimeInterval?

    /// Overrides the ceiling on the size of a file that `.read` / `-init` /
    /// `.import` will load whole (via `String(contentsOf:)`) under a bounding
    /// policy (hardened / read-only / timeout). `nil` falls back to
    /// `defaultInputByteCeiling`. Has no effect under the permissive policy,
    /// which reads files unbounded like stock sqlite3. The slurp happens before
    /// `statementTimeout`, `SQLITE_LIMIT_SQL_LENGTH`, or `maxResultBytes` can
    /// apply, so without this an authorized multi-GB regular file could exhaust
    /// memory in a sandboxed run regardless of the budget.
    public var maxInputBytes: Int?

    /// Force read-only opens regardless of argv. Off by default so hardened
    /// mode does not block legitimate writes (incl. vec0/FTS5 index builds).
    public var forceReadOnly: Bool

    /// Where the attempted-audit trail is written. **Embedder-set only** —
    /// never an LLM-supplied argv path. `nil` means no audit file.
    public var auditURL: URL?

    public init(hardened: Bool = false,
                maxResultBytes: Int? = nil,
                statementTimeout: TimeInterval? = nil,
                forceReadOnly: Bool = false,
                maxInputBytes: Int? = nil,
                auditURL: URL? = nil) {
        self.hardened = hardened
        self.maxResultBytes = maxResultBytes
        self.statementTimeout = statementTimeout
        self.forceReadOnly = forceReadOnly
        self.maxInputBytes = maxInputBytes
        self.auditURL = auditURL
    }

    /// Stock sqlite3 behavior — no added confinement.
    public static let permissive = SQLitePolicy()

    /// The default hardened profile for untrusted (LLM-driven) SQL.
    public static func hardened(auditURL: URL? = nil) -> SQLitePolicy {
        SQLitePolicy(hardened: true,
                     maxResultBytes: 8 * 1024 * 1024,   // 8 MiB of output
                     statementTimeout: 30,
                     forceReadOnly: false,
                     maxInputBytes: defaultInputByteCeiling,
                     auditURL: auditURL)
    }

    /// argv `-hardened` (the one allowed tighten-only override): turn hardening
    /// on, never off, keeping any embedder-set audit destination.
    func tightenedToHardened() -> SQLitePolicy {
        guard !hardened else { return self }
        var p = self
        p.hardened = true
        p.maxResultBytes = p.maxResultBytes ?? 8 * 1024 * 1024
        p.statementTimeout = p.statementTimeout ?? 30
        p.maxInputBytes = p.maxInputBytes ?? Self.defaultInputByteCeiling
        return p
    }

    // MARK: Runtime SQLITE_LIMIT codes (raw ints; match the `.limit` table)

    static let limitLength: Int32 = 0
    static let limitSQLLength: Int32 = 1
    static let limitAttached: Int32 = 7

    /// Ceilings applied in hardened mode (and enforced against `.limit` raises).
    static let lengthCeiling: Int32 = 1_000_000_000
    static let sqlLengthCeiling: Int32 = 1_000_000

    /// Default ceiling for a whole-file `.read` / `-init` / `.import` slurp under
    /// a bounding policy when `maxInputBytes` is unset: generous enough for real
    /// setup scripts and CSV imports, bounded enough that an authorized multi-GB
    /// file can't exhaust memory in a sandboxed run. (Codex review P2, PR #1.)
    static let defaultInputByteCeiling = 64 * 1024 * 1024   // 64 MiB
}
