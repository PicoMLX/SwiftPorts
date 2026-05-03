import Foundation

/// A GitLab group (== a namespace that can hold subgroups + projects).
/// We only need the `id` for `repo create -g <group>` namespace
/// lookups, but expose the rest for completeness.
public struct Group: Codable, Sendable, Identifiable {
    public let id: Int
    public let name: String
    public let path: String
    public let fullPath: String
    public let description: String?
    public let visibility: String?
    public let webUrl: URL
}
