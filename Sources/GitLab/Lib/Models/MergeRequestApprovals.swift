import Foundation

/// `GET /projects/:id/merge_requests/:iid/approvals` response. Used by
/// `glab mr approve` to show how many approvals the MR has, and by
/// `glab mr view --json` if the user opts into a richer dump.
public struct MergeRequestApprovals: Codable, Sendable {
    public let id: Int?
    public let iid: Int?
    public let projectId: Int?
    public let title: String?
    public let description: String?
    public let state: String?
    public let mergeStatus: String?
    public let approvalsRequired: Int?
    public let approvalsLeft: Int?
    public let approved: Bool?
    public let approvedBy: [ApprovedByEntry]?
    public let userHasApproved: Bool?
    public let userCanApprove: Bool?

    public struct ApprovedByEntry: Codable, Sendable {
        public let user: User?
    }
}
