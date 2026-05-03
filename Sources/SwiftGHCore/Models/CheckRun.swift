import Foundation

/// `GET /repos/{o}/{r}/commits/{sha}/check-runs`.
public struct CheckRunList: Codable, Sendable {
    public let totalCount: Int
    public let checkRuns: [CheckRun]
}

public struct CheckRun: Codable, Sendable, Identifiable {
    public let id: Int
    public let nodeId: String
    public let name: String
    public let headSha: String
    public let status: String           // queued | in_progress | completed | waiting
    public let conclusion: String?      // success | failure | neutral | cancelled | …
    public let url: URL
    public let htmlUrl: URL?
    public let startedAt: Date?
    public let completedAt: Date?
    public let app: CheckRunApp?
}

public struct CheckRunApp: Codable, Sendable {
    public let id: Int
    public let name: String
    public let slug: String?
}
