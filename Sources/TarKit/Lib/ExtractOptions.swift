import Foundation

public struct ExtractOptions: Sendable {
    /// Where files land. Created if missing.
    public var destination: URL
    /// Replace existing files with archive contents. When false,
    /// existing files are kept and the archive entry is skipped.
    public var overwrite: Bool
    /// `--strip-components=N`: drop N leading path components on
    /// extract. Useful for unwrapping `repo-1.2.3/` style tarballs
    /// without their top-level directory.
    public var stripComponents: Int

    public init(
        destination: URL,
        overwrite: Bool = true,
        stripComponents: Int = 0
    ) {
        self.destination = destination
        self.overwrite = overwrite
        self.stripComponents = stripComponents
    }
}
