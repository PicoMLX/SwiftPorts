import Foundation

public enum TarKitError: Error, LocalizedError, Sendable, Equatable {
    case archiveOpenFailed(String)
    case writeFailed(URL, underlying: String)
    case readFailed(URL, underlying: String)

    public var errorDescription: String? {
        switch self {
        case .archiveOpenFailed(let path):
            return "tar: cannot open archive '\(path)'"
        case .writeFailed(let url, let underlying):
            return "tar: cannot write '\(url.path)': \(underlying)"
        case .readFailed(let url, let underlying):
            return "tar: cannot read '\(url.path)': \(underlying)"
        }
    }
}
