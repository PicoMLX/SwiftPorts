import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

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

/// Where audit events are flushed. Implementations must write **outside** the
/// database under audit, so a free-form `DROP`/`DELETE` cannot erase its trail.
public protocol AuditSink: Sendable {
    func record(_ event: AuditEvent) async
}

/// An `AuditSink` that discards everything — used when no audit destination is
/// configured. Accumulates nothing, so a long run can't grow memory.
public struct NoOpAuditSink: AuditSink {
    public init() {}
    public func record(_ event: AuditEvent) async {}
}

/// An `AuditSink` that appends one JSON object per event (JSON Lines) to a host
/// file outside the database. The append uses a raw `O_NOFOLLOW` open so a
/// symlink swapped into the log's final path component after it was authorized
/// can't redirect the write outside the sandbox.
///
/// Deliberate limitation: `O_NOFOLLOW` guards only the leaf — a *parent
/// directory* swapped to a symlink after authorization is still followed.
/// Closing that race needs `openat`-style walking from a trusted root fd, which
/// is out of scope for this shell-layer trail.
public actor FileAuditSink: AuditSink {
    private let url: URL

    public init(url: URL) {
        self.url = url
    }

    /// Verify the log can be created/appended *before* any SQL runs, so an
    /// explicit audit request fails closed (a directory, an unwritable
    /// location, or a leaf symlink that `O_NOFOLLOW` rejects) rather than
    /// silently dropping records after statements may have committed.
    public func preflight() throws {
        let fd = openLog()
        guard fd >= 0 else { throw AuditWriteError(message: String(cString: strerror(errno))) }
        close(fd)
    }

    public func record(_ event: AuditEvent) async {
        var blob = Data((event.jsonLine + "\n").utf8)
        let fd = openLog()
        guard fd >= 0 else { Self.reportFailure(url: url); return }
        defer { close(fd) }
        blob.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
            guard let base = raw.baseAddress else { return }
            var written = 0
            while written < raw.count {
                let n = write(fd, base + written, raw.count - written)
                if n <= 0 { Self.reportFailure(url: url); return }
                written += n
            }
        }
    }

    /// O_APPEND keeps each flush atomic; O_CREAT makes the log on first write
    /// (mode 0600); O_NOFOLLOW rejects a leaf swapped to a symlink.
    private func openLog() -> Int32 {
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        return url.path.withCString {
            open($0, O_WRONLY | O_CREAT | O_APPEND | O_NOFOLLOW, 0o600)
        }
    }

    /// Surface an audit-write failure on stderr rather than silently dropping
    /// records — the trail matters most exactly when writes fail.
    private static func reportFailure(url: URL) {
        let reason = String(cString: strerror(errno))
        FileHandle.standardError.write(
            Data("sqlite3: AUDIT WRITE FAILED for \(url.path): \(reason)\n".utf8))
    }
}

private struct AuditWriteError: Error, CustomStringConvertible {
    let message: String
    var description: String { message }
}
