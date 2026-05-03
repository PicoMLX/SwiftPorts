import Foundation

/// GitLab CI/CD pipeline. The `id` is a project-scoped pipeline ID
/// (the number in `https://host/path/-/pipelines/<id>` URLs).
public struct Pipeline: Codable, Sendable, Identifiable {
    public let id: Int
    public let iid: Int?
    public let projectId: Int
    public let sha: String
    public let ref: String?
    public let status: PipelineStatus
    public let source: String?
    public let webUrl: URL
    public let createdAt: Date?
    public let updatedAt: Date?
    public let startedAt: Date?
    public let finishedAt: Date?
    public let committedAt: Date?
    public let duration: Double?
    public let queuedDuration: Double?
    public let user: User?
}
