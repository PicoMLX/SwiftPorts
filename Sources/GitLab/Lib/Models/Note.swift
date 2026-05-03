import Foundation

/// A GitLab note (= comment) on an issue or MR.
public struct Note: Codable, Sendable, Identifiable {
    public let id: Int
    public let body: String
    public let author: User
    public let createdAt: Date?
    public let updatedAt: Date?
    public let system: Bool
    public let noteableId: Int?
    public let noteableType: String?
    public let noteableIid: Int?
    public let resolvable: Bool?
    public let confidential: Bool?
    public let internalNote: Bool?

    enum CodingKeys: String, CodingKey {
        case id, body, author
        case createdAt, updatedAt
        case system
        case noteableId, noteableType, noteableIid
        case resolvable
        case confidential
        case internalNote = "internal"
    }
}
