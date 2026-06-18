/// Where audit events are flushed. Implementations must write **outside** the
/// database under audit, so a free-form `DROP`/`DELETE` cannot erase its trail.
///
/// `record` returns `false` if the event could not be durably recorded. A
/// caller that records *before* execution treats a `false` as fail-closed —
/// it must not run the action, since audit is a trusted policy control.
public protocol AuditSink: Sendable {
    @discardableResult
    func record(_ event: AuditEvent) async -> Bool
}
