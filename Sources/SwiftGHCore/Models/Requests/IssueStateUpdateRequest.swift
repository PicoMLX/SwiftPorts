import Foundation

/// Body for `PATCH /repos/{o}/{r}/issues/{n}` when toggling state.
public struct IssueStateUpdateRequest: Codable, Sendable {
    public var state: IssueState
    public var stateReason: String?

    public init(state: IssueState, stateReason: String? = nil) {
        self.state = state
        self.stateReason = stateReason
    }

    public static func close(reason: String? = nil) -> Self {
        Self(state: .closed, stateReason: reason)
    }
    public static func reopen() -> Self {
        Self(state: .open, stateReason: nil)
    }
}
