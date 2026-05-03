import Foundation

/// GitLab issue states. Note GitLab uses `opened`/`closed`, not the
/// `open`/`closed` GitHub uses.
public enum IssueState: String, Codable, Sendable, CaseIterable {
    case opened
    case closed
    case locked
}
