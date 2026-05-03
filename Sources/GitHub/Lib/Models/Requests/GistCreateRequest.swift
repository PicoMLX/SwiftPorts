import Foundation

/// Body for `POST /gists`.
public struct GistCreateRequest: Codable, Sendable {
    public var description: String?
    public var `public`: Bool
    public var files: [String: GistFileContent]

    public init(description: String?, public isPublic: Bool, files: [String: GistFileContent]) {
        self.description = description
        self.public = isPublic
        self.files = files
    }
}

public struct GistFileContent: Codable, Sendable {
    public var content: String
    public init(content: String) { self.content = content }
}
