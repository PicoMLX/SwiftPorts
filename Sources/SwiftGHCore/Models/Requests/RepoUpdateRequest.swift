import Foundation

/// Body for `PATCH /repos/{o}/{r}`.
public struct RepoUpdateRequest: Codable, Sendable {
    public var name: String?
    public var description: String?
    public var homepage: String?
    public var `private`: Bool?
    public var visibility: Visibility?
    public var hasIssues: Bool?
    public var hasProjects: Bool?
    public var hasWiki: Bool?
    public var defaultBranch: String?
    public var allowSquashMerge: Bool?
    public var allowMergeCommit: Bool?
    public var allowRebaseMerge: Bool?
    public var allowAutoMerge: Bool?
    public var deleteBranchOnMerge: Bool?
    public var archived: Bool?

    public init(
        name: String? = nil,
        description: String? = nil,
        homepage: String? = nil,
        private isPrivate: Bool? = nil,
        visibility: Visibility? = nil,
        hasIssues: Bool? = nil,
        hasProjects: Bool? = nil,
        hasWiki: Bool? = nil,
        defaultBranch: String? = nil,
        allowSquashMerge: Bool? = nil,
        allowMergeCommit: Bool? = nil,
        allowRebaseMerge: Bool? = nil,
        allowAutoMerge: Bool? = nil,
        deleteBranchOnMerge: Bool? = nil,
        archived: Bool? = nil
    ) {
        self.name = name
        self.description = description
        self.homepage = homepage
        self.private = isPrivate
        self.visibility = visibility
        self.hasIssues = hasIssues
        self.hasProjects = hasProjects
        self.hasWiki = hasWiki
        self.defaultBranch = defaultBranch
        self.allowSquashMerge = allowSquashMerge
        self.allowMergeCommit = allowMergeCommit
        self.allowRebaseMerge = allowRebaseMerge
        self.allowAutoMerge = allowAutoMerge
        self.deleteBranchOnMerge = deleteBranchOnMerge
        self.archived = archived
    }
}
