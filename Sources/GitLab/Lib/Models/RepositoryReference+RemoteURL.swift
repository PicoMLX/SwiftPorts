import Foundation
import ForgeKit

extension GitClient {
    /// Convenience: parse `remoteURL(named:)` into a GitLab
    /// `RepositoryReference`. Returns `nil` if the remote doesn't
    /// resolve to a `host:group/.../repo`-style URL.
    public func currentRepository(remote: String = "origin") async throws -> RepositoryReference? {
        guard let url = try await remoteURL(named: remote) else { return nil }
        return RepositoryReference(parsingRemoteURL: url)
    }
}

extension RepositoryReference {
    /// Parse a git remote URL (https or ssh) into a `RepositoryReference`.
    ///
    /// Recognised forms:
    ///   - `https://gitlab.com/group/subgroup/repo.git`
    ///   - `https://gitlab.com/group/subgroup/repo`
    ///   - `git@gitlab.com:group/subgroup/repo.git`
    ///   - `ssh://git@gitlab.com/group/subgroup/repo.git`
    ///
    /// Returns `nil` for inputs without a clear `host:path/to/repo` shape.
    public init?(parsingRemoteURL url: URL) {
        let absolute = url.absoluteString

        // SCP-style: `git@host:path/to/repo(.git)`
        if absolute.contains("@"), absolute.contains(":"), !absolute.contains("://") {
            guard let at = absolute.firstIndex(of: "@"),
                  let colon = absolute.firstIndex(of: ":") else { return nil }
            let host = String(absolute[absolute.index(after: at)..<colon])
            let path = absolute[absolute.index(after: colon)...]
            let segments = path
                .split(separator: "/")
                .map(String.init)
                .map { Self.trimmingDotGit($0) }
            guard segments.count >= 2,
                  segments.allSatisfy({ !$0.isEmpty })
            else { return nil }
            self.init(host: host, pathSegments: segments)
            return
        }

        // URL-style.
        let allowedSchemes: Set<String> = ["http", "https", "git", "ssh"]
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let scheme = components.scheme?.lowercased(),
              allowedSchemes.contains(scheme),
              let host = components.host, !host.isEmpty
        else { return nil }
        let segments = components.path
            .split(separator: "/")
            .map(String.init)
            .map { Self.trimmingDotGit($0) }
        guard segments.count >= 2,
              segments.allSatisfy({ !$0.isEmpty })
        else { return nil }
        self.init(host: host, pathSegments: segments)
    }

    private static func trimmingDotGit(_ s: String) -> String {
        s.hasSuffix(".git") ? String(s.dropLast(4)) : s
    }
}
