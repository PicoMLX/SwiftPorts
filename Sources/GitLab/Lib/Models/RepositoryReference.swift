import Foundation

/// A GitLab project reference. Unlike GitHub's flat `owner/name`, GitLab
/// projects live under a path of one or more groups (e.g.
/// `gitlab-org/cli`, `group/subgroup/sub-subgroup/project`). The host
/// is optional — `nil` means "use the configured default host".
///
/// `pathSegments` is the project path as ordered components (always at
/// least two). `fullPath` is the URL-encoded form used in REST routes.
public struct RepositoryReference: Sendable, Hashable, Codable {
    public let host: String?
    public let pathSegments: [String]

    public init(host: String? = nil, pathSegments: [String]) {
        self.host = host
        self.pathSegments = pathSegments
    }

    /// Project name = the last segment.
    public var name: String { pathSegments.last ?? "" }

    /// Owner / namespace = everything except the last segment, joined
    /// with `/`. Includes nested subgroups when present.
    public var namespace: String {
        pathSegments.dropLast().joined(separator: "/")
    }

    /// Top-level group (only meaningful when there are 3+ segments —
    /// `group/subgroup/repo`). For a flat `owner/repo` this is the
    /// owner. Empty when no path.
    public var topLevelGroup: String {
        pathSegments.first ?? ""
    }

    /// Slash-joined full path: `group/subgroup/repo`. Used in CLI
    /// display.
    public var fullPath: String {
        pathSegments.joined(separator: "/")
    }

    /// Percent-encoded full path for use in REST URL paths
    /// (`projects/group%2Fsubgroup%2Frepo`). GitLab's REST API needs
    /// the project path encoded this way: only the `/` separator is
    /// percent-encoded; other URL-safe characters pass through.
    public var encodedPath: String {
        pathSegments
            .map { segment in
                segment.addingPercentEncoding(
                    withAllowedCharacters: .urlPathAllowed) ?? segment
            }
            .joined(separator: "%2F")
    }

    /// Parse a repo reference from one of:
    ///   - `OWNER/REPO`
    ///   - `GROUP/NAMESPACE/REPO` (and deeper subgroup chains)
    ///   - `HOST/OWNER/REPO` or `HOST/GROUP/.../REPO` — the first
    ///     segment is treated as a host iff it contains a `.`
    ///     (gitlab.com, self-hosted instances).
    ///
    /// `defaultHost` parameter recognises that, e.g. `gitlab.example.com`
    /// is a host even if it isn't `gitlab.com`. Passing it lets a user
    /// type just `group/repo` without the host.
    public init(parsing input: String, defaultHost: String? = nil) throws {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            throw RepositoryReferenceParseError.malformed(input)
        }

        var parts = trimmed.split(separator: "/").map(String.init)
        guard parts.count >= 2 else {
            throw RepositoryReferenceParseError.malformed(input)
        }

        var host: String? = nil
        // First segment is treated as a host if it looks like one (has
        // a dot) and there are 3+ segments — otherwise it's the
        // top-level group of a `group/subgroup/repo`-style path.
        if parts.count >= 3, let first = parts.first,
           first.contains(".") || first == defaultHost {
            host = first
            parts.removeFirst()
        }

        guard parts.allSatisfy({ !$0.isEmpty }) else {
            throw RepositoryReferenceParseError.malformed(input)
        }

        self.host = host
        self.pathSegments = parts
    }
}

public enum RepositoryReferenceParseError: Error, LocalizedError, Sendable {
    case malformed(String)

    public var errorDescription: String? {
        switch self {
        case .malformed(let s):
            return "Expected OWNER/NAME or GROUP/NAMESPACE/REPO, got \"\(s)\"."
        }
    }
}
