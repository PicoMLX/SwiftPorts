import Foundation

/// A single entry in a PKZIP archive (file, directory, or symlink).
public struct Entry: Sendable {
    public let path: String
    public let kind: Kind
    public let uncompressedSize: Int64
    public let compressedSize: Int64
    public let compressionMethod: CompressionMethod
    public let crc32: UInt32
    public let modificationDate: Date?

    public enum Kind: Sendable, Equatable {
        case file
        case directory
        case symlink
    }

    public init(
        path: String,
        kind: Kind,
        uncompressedSize: Int64,
        compressedSize: Int64,
        compressionMethod: CompressionMethod,
        crc32: UInt32,
        modificationDate: Date?
    ) {
        self.path = path
        self.kind = kind
        self.uncompressedSize = uncompressedSize
        self.compressedSize = compressedSize
        self.compressionMethod = compressionMethod
        self.crc32 = crc32
        self.modificationDate = modificationDate
    }
}

public enum CompressionMethod: Sendable, Equatable {
    case store
    case deflate
}
