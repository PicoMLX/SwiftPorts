import Foundation

public struct CreateOptions: Sendable {
    /// `zip -r` — descend into directory inputs.
    public var recursive: Bool
    /// `zip -j` — record only the last path component for each entry.
    public var junkPaths: Bool
    /// `.store` (`zip -0`) keeps bytes as-is; `.deflate` (`zip -1..-9`)
    /// compresses. We don't expose level tuning — Apple's
    /// `Compression` framework + zlib pick a reasonable default.
    public var compressionMethod: CompressionMethod
    /// `zip -q` — suppress per-file progress output.
    public var quiet: Bool
    /// `zip -i` — only include entries matching a pattern.
    public var includes: [String]
    /// `zip -x` — skip entries matching a pattern.
    public var excludes: [String]
    /// Default true (Info-ZIP follows symlinks unless `-y`); set false
    /// to mirror `zip -y` and store the link target instead.
    public var followSymlinks: Bool
    /// `zip -D` — set false to omit explicit directory entries.
    public var includeDirectories: Bool

    public init(
        recursive: Bool = false,
        junkPaths: Bool = false,
        compressionMethod: CompressionMethod = .deflate,
        quiet: Bool = false,
        includes: [String] = [],
        excludes: [String] = [],
        followSymlinks: Bool = true,
        includeDirectories: Bool = true
    ) {
        self.recursive = recursive
        self.junkPaths = junkPaths
        self.compressionMethod = compressionMethod
        self.quiet = quiet
        self.includes = includes
        self.excludes = excludes
        self.followSymlinks = followSymlinks
        self.includeDirectories = includeDirectories
    }
}
