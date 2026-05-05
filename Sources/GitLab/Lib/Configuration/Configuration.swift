import Foundation
import Sandbox

/// Static config for a GitLab API session: host, token, user agent.
///
/// Read once at command start, then read-only.
public struct Configuration: Sendable {
    public var host: String
    public var token: String?
    public var userAgent: String

    public init(
        host: String = Configuration.defaultHost,
        token: String? = nil,
        userAgent: String = Configuration.defaultUserAgent
    ) {
        self.host = host
        self.token = token
        self.userAgent = userAgent
    }

    public static let defaultHost = "gitlab.com"
    public static let defaultUserAgent =
        "SwiftPorts-glab/0.1 (+https://github.com/Cocoanetics/SwiftPorts)"

    /// Build from the active sandbox's environment, or the real
    /// process environment when no sandbox is set.
    public static func live() -> Configuration {
        fromEnvironment(Sandbox.environment)
    }

    /// Test-friendly: build from a dict of env-style keys. Honours the
    /// same precedence as upstream `glab`:
    ///   - host: `GITLAB_HOST` > `GITLAB_URI` > `GL_HOST` > default
    ///   - token: `GITLAB_TOKEN` > `GITLAB_ACCESS_TOKEN` > `OAUTH_TOKEN`
    public static func fromEnvironment(_ env: [String: String]) -> Configuration {
        let host = env["GITLAB_HOST"]?.nilIfEmpty
            ?? env["GITLAB_URI"]?.nilIfEmpty
            ?? env["GL_HOST"]?.nilIfEmpty
            ?? defaultHost
        let token = env["GITLAB_TOKEN"]?.nilIfEmpty
            ?? env["GITLAB_ACCESS_TOKEN"]?.nilIfEmpty
            ?? env["OAUTH_TOKEN"]?.nilIfEmpty
        return Configuration(host: stripScheme(host), token: token)
    }

    /// `gitlab.com` → `https://gitlab.com/api/v4/`
    /// `self-hosted.example.com` → `https://self-hosted.example.com/api/v4/`
    /// Subfolders (`example.com/gitlab`) are preserved.
    public var apiRoot: URL {
        URL(string: "https://\(host)/api/v4/")!
    }

    public var graphQLURL: URL {
        URL(string: "https://\(host)/api/graphql")!
    }

    /// Web UI base for building user-facing URLs (`view --web`).
    public var webRoot: URL {
        URL(string: "https://\(host)")!
    }

    private static func stripScheme(_ host: String) -> String {
        var h = host
        for scheme in ["https://", "http://"] {
            if h.lowercased().hasPrefix(scheme) {
                h = String(h.dropFirst(scheme.count))
                break
            }
        }
        return h.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
