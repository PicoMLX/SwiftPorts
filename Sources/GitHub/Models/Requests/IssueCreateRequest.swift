import Foundation

/// Body for `POST /repos/{o}/{r}/issues`. snake_case via the shared
/// `JSONEncoder.gitHub()` (`convertToSnakeCase`).
public struct IssueCreateRequest: Codable, Sendable {
    public var title: String
    public var body: String?
    public var assignees: [String]?
    public var labels: [String]?
    public var milestone: Int?

    public init(
        title: String,
        body: String? = nil,
        assignees: [String]? = nil,
        labels: [String]? = nil,
        milestone: Int? = nil
    ) {
        self.title = title
        self.body = body
        self.assignees = assignees
        self.labels = labels
        self.milestone = milestone
    }
}
