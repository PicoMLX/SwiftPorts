import Foundation

/// Element of `GET /search/code`. Trimmed shape — the API returns
/// many more fields (text matches, score, repository.owner stats)
/// that we don't currently surface.
public struct CodeSearchItem: Codable, Sendable, Identifiable {
    public let name: String
    public let path: String
    public let sha: String
    public let url: URL
    public let htmlUrl: URL
    public let repository: MinimalRepository
    public let score: Double?

    public var id: String { "\(repository.fullName)#\(path)@\(sha)" }
}
