import Foundation

/// Body for `POST /repos/{o}/{r}/releases`.
public struct ReleaseCreateRequest: Codable, Sendable {
    public var tagName: String
    public var name: String?
    public var body: String?
    public var draft: Bool?
    public var prerelease: Bool?
    public var targetCommitish: String?
    public var generateReleaseNotes: Bool?
    public var makeLatest: String?  // "true" / "false" / "legacy"

    public init(
        tagName: String,
        name: String? = nil,
        body: String? = nil,
        draft: Bool? = nil,
        prerelease: Bool? = nil,
        targetCommitish: String? = nil,
        generateReleaseNotes: Bool? = nil,
        makeLatest: String? = nil
    ) {
        self.tagName = tagName
        self.name = name
        self.body = body
        self.draft = draft
        self.prerelease = prerelease
        self.targetCommitish = targetCommitish
        self.generateReleaseNotes = generateReleaseNotes
        self.makeLatest = makeLatest
    }
}
