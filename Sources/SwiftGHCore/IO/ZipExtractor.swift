import Foundation
import ZIPFoundation

/// In-process ZIP entry walker built on `ZIPFoundation` (which uses
/// Apple's `Compression` framework on Apple platforms and the system
/// zlib elsewhere). Used by `gh run view --log` to render the per-job
/// log files GitHub packs into `/actions/runs/{id}/logs`.
///
/// Cross-platform: works wherever ZIPFoundation works, which is the
/// same target matrix SwiftGH already declares (no `Process`, no
/// shellout to `unzip`). Sandboxed iOS / Playgrounds / server contexts
/// all work without entitlements.
public enum ZipExtractor {
    /// Walks every regular-file entry in `zipData` (sorted by path)
    /// and writes its bytes to stdout, prefixed with a
    /// `=== <path> ===` header. Used to render run-log archives.
    public static func printConcatenatedTextEntries(zipData: Data) async throws {
        let archive = try Archive(data: zipData, accessMode: .read)
        let entries = archive
            .filter { $0.type == .file }
            .sorted { $0.path < $1.path }
        for entry in entries {
            FileHandle.standardOutput.write(Data(
                "\n=== \(entry.path) ===\n".utf8))
            _ = try archive.extract(entry) { chunk in
                FileHandle.standardOutput.write(chunk)
            }
        }
    }

    /// Extract every entry in `zipData` into `destination` (created if
    /// missing). Available for callers that want a directory of files
    /// rather than concatenated stdout output — e.g. a future
    /// `gh run download --extract`.
    public static func extract(
        zipData: Data, into destination: URL
    ) async throws {
        try FileManager.default.createDirectory(
            at: destination, withIntermediateDirectories: true)
        let archive = try Archive(data: zipData, accessMode: .read)
        for entry in archive {
            let target = destination.appendingPathComponent(entry.path)
            switch entry.type {
            case .directory:
                try FileManager.default.createDirectory(
                    at: target, withIntermediateDirectories: true)
            case .file:
                try FileManager.default.createDirectory(
                    at: target.deletingLastPathComponent(),
                    withIntermediateDirectories: true)
                _ = try archive.extract(entry, to: target)
            case .symlink:
                _ = try archive.extract(entry, to: target)
            }
        }
    }
}
