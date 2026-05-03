import Foundation

public struct IssueComment: Codable, Sendable, Identifiable {
    public let id: Int
    public let nodeId: String
    public let url: URL
    public let htmlUrl: URL
    public let body: String?
    public let user: User
    public let createdAt: Date
    public let updatedAt: Date
    public let authorAssociation: AuthorAssociation
}
