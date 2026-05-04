import Foundation

/// A single entry in a tar archive (file, directory, or symlink).
public struct Entry: Sendable, Equatable {
    public let path: String
    public let kind: Kind
    public let size: Int64
    public let modificationDate: Date?
    public let mode: UInt16

    public enum Kind: Sendable, Equatable {
        case file
        case directory
        case symlink
    }

    public init(
        path: String,
        kind: Kind,
        size: Int64,
        modificationDate: Date?,
        mode: UInt16
    ) {
        self.path = path
        self.kind = kind
        self.size = size
        self.modificationDate = modificationDate
        self.mode = mode
    }
}
