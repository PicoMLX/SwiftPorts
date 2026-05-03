import Foundation

public enum ZipKitError: Error, LocalizedError, Sendable {
    case archiveOpenFailed(String)
    case crcMismatch(entry: String, expected: UInt32, actual: UInt32)
    case entryNotFound(String)
    case destinationExists(URL)
    case writeFailed(URL, underlying: String)

    public var errorDescription: String? {
        switch self {
        case .archiveOpenFailed(let reason):
            return "Couldn't open archive: \(reason)"
        case .crcMismatch(let entry, let expected, let actual):
            return "CRC mismatch on \(entry): expected \(String(expected, radix: 16)), got \(String(actual, radix: 16))"
        case .entryNotFound(let name):
            return "No such entry in archive: \(name)"
        case .destinationExists(let url):
            return "Destination already exists: \(url.path) (use --overwrite or --never-overwrite to choose)"
        case .writeFailed(let url, let underlying):
            return "Couldn't write \(url.path): \(underlying)"
        }
    }
}
