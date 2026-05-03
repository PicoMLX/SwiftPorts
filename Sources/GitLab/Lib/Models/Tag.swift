import Foundation

/// One git tag exposed via GitLab's `/projects/:id/repository/tags`
/// endpoint. Lightweight tags carry just `name + commit`; annotated
/// tags also have `message` + `target` (the tag object SHA).
public struct Tag: Codable, Sendable, Equatable {
    public let name: String
    public let message: String?
    public let target: String?
    public let commit: TagCommit?
}

public struct TagCommit: Codable, Sendable, Equatable {
    public let id: String
    public let shortId: String?
    public let title: String?
    public let createdAt: Date?
}
