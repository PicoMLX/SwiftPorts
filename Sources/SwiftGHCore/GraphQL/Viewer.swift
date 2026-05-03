import Foundation

/// `viewer { login }`-style probe used by `gh auth status` to verify
/// the configured token. Tiny, but a useful smoke test for the whole
/// GraphQL pipeline.
public struct Viewer: Decodable, Sendable {
    public let login: String
    public let name: String?
    public let url: URL
}

public struct ViewerQuery: Decodable, Sendable {
    public let viewer: Viewer

    public static let query = """
        query {
          viewer {
            login
            name
            url
          }
        }
        """
}
