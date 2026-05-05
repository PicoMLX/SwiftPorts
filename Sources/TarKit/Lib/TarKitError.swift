import Foundation

public enum TarKitError: Error, LocalizedError, Sendable, Equatable {
    case archiveOpenFailed(String)
    case writeFailed(URL, underlying: String)
    case readFailed(URL, underlying: String)
    /// Archive entry contains a path that would escape the destination
    /// (absolute, drive-letter, or `..`-traversing). Refusing to extract
    /// is the only safe response for untrusted tarballs.
    case unsafeEntryPath(String)

    public var errorDescription: String? {
        switch self {
        case .archiveOpenFailed(let path):
            return "tar: cannot open archive '\(path)'"
        case .writeFailed(let url, let underlying):
            return "tar: cannot write '\(url.path)': \(underlying)"
        case .readFailed(let url, let underlying):
            return "tar: cannot read '\(url.path)': \(underlying)"
        case .unsafeEntryPath(let path):
            return "tar: refusing to extract unsafe entry path '\(path)'"
        }
    }
}
