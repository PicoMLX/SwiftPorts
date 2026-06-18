import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

/// An `AuditSink` that appends one JSON object per event (JSON Lines) to a host
/// file outside the database. On Darwin/Glibc the append uses a raw
/// `O_NOFOLLOW` open so a symlink swapped into the log's final path component
/// after it was authorized can't redirect the write outside the sandbox.
///
/// Deliberate limitation: `O_NOFOLLOW` guards only the leaf — a *parent
/// directory* swapped to a symlink after authorization is still followed.
/// Closing that race needs `openat`-style walking from a trusted root fd, which
/// is out of scope for this shell-layer trail. On platforms without those POSIX
/// headers (e.g. Windows) a Foundation append is used, without the leaf guard.
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
            throw NSError(domain: "SwiftPortsSQLiteAudit", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: message])
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
