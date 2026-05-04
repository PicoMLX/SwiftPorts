import Foundation

public enum GzipKitError: Error, LocalizedError, Sendable, Equatable {
    case compressionFailed(String)
    case decompressionFailed(String)
    case cannotInferOutputName(URL)

    public var errorDescription: String? {
        switch self {
        case .compressionFailed(let m):
            return "gzip: compression failed: \(m)"
        case .decompressionFailed(let m):
            return "gzip: decompression failed: \(m)"
        case .cannotInferOutputName(let u):
            return "gzip: cannot infer output name from '\(u.path)' (no .gz/.tgz/.taz suffix)"
        }
    }
}
