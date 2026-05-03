import Foundation

/// GitLab CI/CD job — a single instance of running a `.gitlab-ci.yml`
/// step. `id` is a globally unique job ID (across all projects).
public struct Job: Codable, Sendable, Identifiable {
    public let id: Int
    public let name: String
    public let stage: String
    public let status: PipelineStatus
    public let ref: String?
    public let tag: Bool?
    public let allowFailure: Bool?
    public let createdAt: Date?
    public let startedAt: Date?
    public let finishedAt: Date?
    public let erasedAt: Date?
    public let duration: Double?
    public let queuedDuration: Double?
    public let coverage: Double?
    public let webUrl: URL
    public let user: User?
    public let failureReason: String?
    public let pipeline: PipelineRef?
    public let runner: Runner?
    public let tagList: [String]?
}

/// Compact pipeline reference embedded inside a job response.
public struct PipelineRef: Codable, Sendable, Identifiable {
    public let id: Int
    public let projectId: Int?
    public let ref: String?
    public let sha: String?
    public let status: PipelineStatus?
    public let webUrl: URL?
}

/// Compact runner reference embedded inside a job response.
public struct Runner: Codable, Sendable, Identifiable {
    public let id: Int
    public let description: String?
    public let active: Bool?
    public let isShared: Bool?
    public let runnerType: String?
    public let name: String?
    public let online: Bool?
    public let status: String?
}
