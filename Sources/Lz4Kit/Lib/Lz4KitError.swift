import Foundation

public enum Lz4KitError: Error, LocalizedError, Sendable, Equatable {
    case compressionFailed(String)
    case decompressionFailed(String)
    case cannotInferOutputName(URL)

    public var errorDescription: String? {
        switch self {
        case .compressionFailed(let m):
            return "lz4: compression failed: \(m)"
        case .decompressionFailed(let m):
            return "lz4: decompression failed: \(m)"
        case .cannotInferOutputName(let u):
            return "lz4: cannot infer output name from '\(u.path)' (no .lz4/.tlz4 suffix)"
        }
    }
}
