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
///
/// `record` returns `false` if the event could not be durably recorded. A
/// caller that records *before* execution treats a `false` as fail-closed —
/// it must not run the action, since audit is a trusted policy control.
public protocol AuditSink: Sendable {
    @discardableResult
    func record(_ event: AuditEvent) async -> Bool
}

/// An `AuditSink` that discards everything — used when no audit destination is
/// configured. Accumulates nothing, so a long run can't grow memory. Always
/// "succeeds" (there is nothing to fail), so it never blocks execution.
public struct NoOpAuditSink: AuditSink {
    public init() {}
    public func record(_ event: AuditEvent) async -> Bool { true }
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
        if let message = appendBytes(Data()) {   // empty append: create + probe
            throw AuditWriteError(message: message)
        }
    }

    @discardableResult
    public func record(_ event: AuditEvent) async -> Bool {
        if let message = appendBytes(Data((event.jsonLine + "\n").utf8)) {
            Self.reportFailure(url: url, reason: message)
            return false
        }
        return true
    }

    /// Atomically append `blob` to the log, creating the file (and parent
    /// directory) on first write. Returns `nil` on success, or an error message.
    ///
    /// Two implementations: a POSIX `O_NOFOLLOW` open (so a leaf swapped to a
    /// symlink after authorization can't redirect the write) on Darwin/Glibc,
    /// and a Foundation fallback on platforms without those headers (e.g.
    /// Windows) — the fallback loses the leaf-symlink guard but keeps the trail
    /// working and the package building.
    private func appendBytes(_ blob: Data) -> String? {
#if canImport(Darwin) || canImport(Glibc)
        let fd = openLogPOSIX()
        guard fd >= 0 else { return String(cString: strerror(errno)) }
        defer { close(fd) }
        var failure: String?
        if !blob.isEmpty {
            blob.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
                guard let base = raw.baseAddress else { return }
                var written = 0
                while written < raw.count {
                    let n = write(fd, base + written, raw.count - written)
                    if n <= 0 { failure = String(cString: strerror(errno)); return }
                    written += n
                }
            }
        }
        return failure
#else
        do {
            try ensureDirectory()
            if !FileManager.default.fileExists(atPath: url.path) {
                FileManager.default.createFile(atPath: url.path, contents: nil)
            }
            let handle = try FileHandle(forWritingTo: url)
            defer { try? handle.close() }
            if !blob.isEmpty {
                try handle.seekToEnd()
                try handle.write(contentsOf: blob)
            }
            return nil
        } catch {
            return String(describing: error)
        }
#endif
    }

    private func ensureDirectory() throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    }

#if canImport(Darwin) || canImport(Glibc)
    /// Open the log for an atomic append. Try the open first and create the
    /// parent directory only on ENOENT, so the common (directory-exists) path
    /// is a single syscall rather than a `createDirectory` on every record.
    /// O_APPEND keeps each flush atomic; O_CREAT makes the log on first write
    /// (mode 0600); O_NOFOLLOW rejects a leaf swapped to a symlink.
    private func openLogPOSIX() -> Int32 {
        let path = url.path
        var fd = path.withCString {
            open($0, O_WRONLY | O_CREAT | O_APPEND | O_NOFOLLOW, mode_t(0o600))
        }
        if fd < 0 && errno == ENOENT {
            try? ensureDirectory()
            fd = path.withCString {
                open($0, O_WRONLY | O_CREAT | O_APPEND | O_NOFOLLOW, mode_t(0o600))
            }
        }
        return fd
    }
#endif

    /// Surface an audit-write failure on stderr rather than silently dropping
    /// records — the trail matters most exactly when writes fail.
    private static func reportFailure(url: URL, reason: String) {
        FileHandle.standardError.write(
            Data("sqlite3: AUDIT WRITE FAILED for \(url.path): \(reason)\n".utf8))
    }
}

private struct AuditWriteError: Error, CustomStringConvertible {
    let message: String
    var description: String { message }
}
