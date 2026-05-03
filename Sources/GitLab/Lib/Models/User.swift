import Foundation

/// Minimal user shape used as nested values in issue / MR responses.
public struct User: Codable, Sendable, Hashable {
    public let id: Int
    public let username: String
    public let name: String?
    public let state: String?
    public let avatarUrl: URL?
    public let webUrl: URL?
}
