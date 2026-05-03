import Foundation

/// `GET /repos/{o}/{r}/actions/workflows`.
public struct Workflow: Codable, Sendable, Identifiable {
    public let id: Int
    public let nodeId: String
    public let name: String
    public let path: String
    public let state: WorkflowState
    public let createdAt: Date
    public let updatedAt: Date
    public let url: URL
    public let htmlUrl: URL
    public let badgeUrl: URL
}

public enum WorkflowState: String, Codable, Sendable {
    case active
    case deleted
    case disabledFork = "disabled_fork"
    case disabledInactivity = "disabled_inactivity"
    case disabledManually = "disabled_manually"
}

/// `GET /repos/{o}/{r}/actions/workflows` envelope.
public struct WorkflowList: Codable, Sendable {
    public let totalCount: Int
    public let workflows: [Workflow]
}
