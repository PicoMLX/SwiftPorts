import Foundation

/// `GET /repos/{o}/{r}/actions/runs`.
public struct WorkflowRun: Codable, Sendable, Identifiable {
    public let id: Int
    public let nodeId: String
    public let name: String?
    public let headBranch: String?
    public let headSha: String
    public let runNumber: Int
    public let event: String
    public let status: String?
    public let conclusion: String?
    public let workflowId: Int
    public let url: URL
    public let htmlUrl: URL
    public let createdAt: Date
    public let updatedAt: Date
    public let runStartedAt: Date?
    public let displayTitle: String?
    public let runAttempt: Int?
    public let actor: User?
}

/// `GET /repos/{o}/{r}/actions/runs` envelope.
public struct WorkflowRunList: Codable, Sendable {
    public let totalCount: Int
    public let workflowRuns: [WorkflowRun]
}
