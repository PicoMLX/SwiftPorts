import Foundation

/// `ProjectV2Item` — one row in a project, polymorphic via the
/// `content` union (Issue / PullRequest / DraftIssue / nothing).
public struct ProjectV2Item: Codable, Sendable, Identifiable {
    public let id: String
    public let type: ProjectV2ItemType
    public let createdAt: Date
    public let updatedAt: Date
    public let content: ProjectV2ItemContent?
}

public enum ProjectV2ItemType: String, Codable, Sendable {
    case issue = "ISSUE"
    case pullRequest = "PULL_REQUEST"
    case draftIssue = "DRAFT_ISSUE"
    case redacted = "REDACTED"
}

/// Discriminated by GraphQL's `__typename`. Carries only the few
/// fields we surface in `gh project view`; richer queries can decode
/// into more specific types directly.
public enum ProjectV2ItemContent: Codable, Sendable {
    case issue(IssueRef)
    case pullRequest(PullRequestRefShort)
    case draftIssue(DraftIssue)
    case unknown

    public struct IssueRef: Codable, Sendable {
        public let number: Int
        public let title: String
        public let state: String
        public let url: URL
    }

    public struct PullRequestRefShort: Codable, Sendable {
        public let number: Int
        public let title: String
        public let state: String
        public let url: URL
    }

    public struct DraftIssue: Codable, Sendable {
        public let title: String
        public let body: String?
    }

    enum CodingKeys: String, CodingKey {
        case typename = "__typename"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typename = try container.decode(String.self, forKey: .typename)
        let single = try decoder.singleValueContainer()
        switch typename {
        case "Issue":
            self = .issue(try single.decode(IssueRef.self))
        case "PullRequest":
            self = .pullRequest(try single.decode(PullRequestRefShort.self))
        case "DraftIssue":
            self = .draftIssue(try single.decode(DraftIssue.self))
        default:
            self = .unknown
        }
    }

    public func encode(to encoder: Encoder) throws {
        // Round-tripping content payloads isn't a use case we have.
        // Encode as a tag string so accidental encodes don't crash.
        var container = encoder.singleValueContainer()
        try container.encode(tagString)
    }

    private var tagString: String {
        switch self {
        case .issue: return "Issue"
        case .pullRequest: return "PullRequest"
        case .draftIssue: return "DraftIssue"
        case .unknown: return "Unknown"
        }
    }
}
