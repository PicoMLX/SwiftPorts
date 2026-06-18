/// An `AuditSink` that discards everything — used when no audit destination is
/// configured. Accumulates nothing, so a long run can't grow memory. Always
/// "succeeds" (there is nothing to fail), so it never blocks execution.
public struct NoOpAuditSink: AuditSink {
    public init() {}
    public func record(_ event: AuditEvent) async -> Bool { true }
}
