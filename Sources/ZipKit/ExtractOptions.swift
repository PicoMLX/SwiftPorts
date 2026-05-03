import Foundation

public struct ExtractOptions: Sendable {
    /// Where files land. Created if missing.
    public var destination: URL
    /// What to do when a target file already exists.
    public var overwrite: OverwriteMode
    /// `unzip -j` — drop entry path components, extract everything flat.
    public var junkPaths: Bool
    /// Glob patterns to require (empty = all entries).
    public var includes: [String]
    /// Glob patterns to skip.
    public var excludes: [String]
    /// `unzip -C` — case-insensitive matching for includes / excludes.
    public var caseInsensitive: Bool
    /// `unzip -q` — suppress per-file progress output.
    public var quiet: Bool

    public enum OverwriteMode: Sendable {
        case yes      // unzip -o
        case no       // unzip -n
        case error    // throw on collision
    }

    public init(
        destination: URL,
        overwrite: OverwriteMode = .yes,
        junkPaths: Bool = false,
        includes: [String] = [],
        excludes: [String] = [],
        caseInsensitive: Bool = false,
        quiet: Bool = false
    ) {
        self.destination = destination
        self.overwrite = overwrite
        self.junkPaths = junkPaths
        self.includes = includes
        self.excludes = excludes
        self.caseInsensitive = caseInsensitive
        self.quiet = quiet
    }
}
