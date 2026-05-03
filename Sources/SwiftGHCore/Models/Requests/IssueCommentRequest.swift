import Foundation

/// Body for `POST /repos/{o}/{r}/issues/{n}/comments`.
public struct IssueCommentRequest: Codable, Sendable {
    public var body: String
    public init(body: String) { self.body = body }
}
