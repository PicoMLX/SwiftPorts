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
        // On failure just return false — the caller (recording before execution)
        // fails closed and reports through the shell's own stderr sink. We
        // deliberately don't write here: a process-global stderr write would
        // bypass the embedder's virtual stderr/pipeline and leak the host path.
        appendBytes(Data((event.jsonLine + "\n").utf8)) == nil
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
            // Durability: record()'s contract only permits the action once the
            // event is on disk, so flush before returning success — a bare write(2)
            // leaves the JSONL in the page cache, which a crash after the
            // subsequent SQL commit would lose. (Codex review P2, PR #1.)
            if failure == nil, fsync(fd) != 0 {
                failure = String(cString: strerror(errno))
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
                try handle.synchronize()   // flush before success (Codex review P2, PR #1)
            }
            return nil
        } catch {
            // Sanitize: Foundation file errors (createDirectory/FileHandle) embed
            // NSFilePath/NSURL in their description, which `run` would echo to the
            // untrusted command's stderr — leaking the embedder-set audit path
            // despite the POSIX branch's path-free errno text. Surface only the
            // error domain/code (never the raw description). (Codex review P2, PR #1.)
            let ns = error as NSError
            return "audit log unavailable (\(ns.domain) \(ns.code))"
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
    /// (mode 0600); O_NOFOLLOW rejects a leaf swapped to a symlink; O_NONBLOCK
    /// makes an O_WRONLY open of a reader-less FIFO fail fast with ENXIO instead
    /// of blocking preflight indefinitely (the fstat below then rejects any FIFO
    /// that does open). O_NONBLOCK has no effect on writes to the regular file we
    /// require, so the append path is unchanged.
    private func openLogPOSIX() -> Int32 {
        let path = url.path
        var fd = path.withCString {
            open($0, O_WRONLY | O_CREAT | O_APPEND | O_NOFOLLOW | O_NONBLOCK, mode_t(0o600))
        }
        if fd < 0 && errno == ENOENT {
            try? ensureDirectory()
            fd = path.withCString {
                open($0, O_WRONLY | O_CREAT | O_APPEND | O_NOFOLLOW | O_NONBLOCK, mode_t(0o600))
            }
        }
        guard fd >= 0 else { return fd }
        // O_NOFOLLOW rejects a leaf *symlink*, but an existing FIFO, device, or
        // socket at the path is still opened — writing the trail into one would
        // lose records (or block). Require a regular file; otherwise fail the
        // open so the audit fails closed rather than writing to a non-file.
        var info = stat()
        if fstat(fd, &info) != 0 || (info.st_mode & mode_t(S_IFMT)) != mode_t(S_IFREG) {
            close(fd)
            errno = EINVAL
            return -1
        }
        return fd
    }
#endif
}
