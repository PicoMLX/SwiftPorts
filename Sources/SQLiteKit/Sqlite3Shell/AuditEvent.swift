import Foundation

/// A single audit record. This shell-layer trail is the **attempted** tier:
/// it records *intent* — the statement or dot-command the shell was asked to
/// run, before execution — not which rows actually committed. A committed /
/// per-row tier needs SQLite's commit/update/rollback hooks, which live in the
/// SDK (out of this package) and are tracked as a follow-up.
public enum AuditEvent: Sendable {
    /// `kind` is `"sql"` or `"dot"`; `text` is the (trimmed) statement or command.
    case attempted(kind: String, text: String)

    var jsonLine: String {
        switch self {
        case let .attempted(kind, text):
            let object: [String: Any] = ["event": "attempted", "kind": kind, "text": text]
            guard
                let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
                let string = String(data: data, encoding: .utf8)
            else { return "{}" }
            return string
        }
    }
}
