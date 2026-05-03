import Foundation

/// Body for `PATCH /repos/{o}/{r}/issues/{n}`.
public struct IssueUpdateRequest: Codable, Sendable {
    public var title: String?
    public var body: String?
    public var state: IssueState?
    public var stateReason: String?
    public var labels: [String]?
    public var assignees: [String]?
    public var milestone: Int?

    public init(
        title: String? = nil,
        body: String? = nil,
        state: IssueState? = nil,
        stateReason: String? = nil,
        labels: [String]? = nil,
        assignees: [String]? = nil,
        milestone: Int? = nil
    ) {
        self.title = title
        self.body = body
        self.state = state
        self.stateReason = stateReason
        self.labels = labels
        self.assignees = assignees
        self.milestone = milestone
    }
}

/// Body for `PUT /repos/{o}/{r}/issues/{n}/lock` and the equivalent
/// PR endpoint. `lock_reason` ∈ {off-topic, too heated, resolved, spam}.
public struct LockRequest: Codable, Sendable {
    public var lockReason: String?
    public init(lockReason: String? = nil) { self.lockReason = lockReason }
}

/// Body for `PATCH /repos/{o}/{r}/pulls/{n}`.
public struct PullRequestUpdateRequest: Codable, Sendable {
    public var title: String?
    public var body: String?
    public var state: PullRequestState?
    public var base: String?
    public var maintainerCanModify: Bool?

    public init(
        title: String? = nil,
        body: String? = nil,
        state: PullRequestState? = nil,
        base: String? = nil,
        maintainerCanModify: Bool? = nil
    ) {
        self.title = title
        self.body = body
        self.state = state
        self.base = base
        self.maintainerCanModify = maintainerCanModify
    }
}
