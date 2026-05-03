import Foundation

/// A GitLab project (= repository in GitHub parlance). The
/// `pathWithNamespace` is the slash-joined identifier the rest of the
/// CLI uses (`group/sub/repo`).
public struct Project: Codable, Sendable, Identifiable {
    public let id: Int
    public let name: String
    public let path: String
    public let pathWithNamespace: String
    public let description: String?
    public let defaultBranch: String?
    public let visibility: String
    public let archived: Bool?
    public let webUrl: URL
    public let httpUrlToRepo: URL?
    public let sshUrlToRepo: URL?
    public let createdAt: Date?
    public let lastActivityAt: Date?
    public let starCount: Int?
    public let forksCount: Int?
    public let openIssuesCount: Int?
    public let issuesEnabled: Bool?
    public let mergeRequestsEnabled: Bool?
    public let wikiEnabled: Bool?
    public let snippetsEnabled: Bool?
    public let emptyRepo: Bool?
    public let namespace: Namespace?

    public struct Namespace: Codable, Sendable {
        public let id: Int
        public let name: String
        public let path: String
        public let kind: String
        public let fullPath: String
        public let webUrl: URL?
    }
}
