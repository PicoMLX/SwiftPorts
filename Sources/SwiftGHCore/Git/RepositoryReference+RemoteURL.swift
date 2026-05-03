import Foundation

extension RepositoryReference {
    /// Parse a git remote URL (https or ssh) into an OWNER/NAME ref.
    ///
    /// Recognised forms:
    ///   - `https://github.com/owner/name.git`
    ///   - `https://github.com/owner/name`
    ///   - `git@github.com:owner/name.git`
    ///   - `ssh://git@github.com/owner/name.git`
    ///   - `git://github.com/owner/name.git`
    ///
    /// Returns `nil` for anything that doesn't have a clear
    /// `host:owner/name` shape (e.g. local paths, malformed URLs).
    public init?(parsingRemoteURL url: URL) {
        let absolute = url.absoluteString

        // SCP-style: `git@host:owner/name(.git)`
        if absolute.contains("@"), absolute.contains(":"), !absolute.contains("://") {
            // Pull "owner/name" out from the part after the colon.
            guard let colon = absolute.firstIndex(of: ":") else { return nil }
            let path = absolute[absolute.index(after: colon)...]
            let parts = path.split(separator: "/")
            guard parts.count == 2 else { return nil }
            self.init(
                owner: String(parts[0]),
                name: String(parts[1].trimmingSuffix(".git"))
            )
            return
        }

        // URL-style (https:// / ssh:// / git://) — use URLComponents.
        let allowedSchemes: Set<String> = ["http", "https", "git", "ssh"]
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let scheme = components.scheme?.lowercased(),
              allowedSchemes.contains(scheme),
              let host = components.host, !host.isEmpty else {
            return nil
        }
        let path = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let parts = path.split(separator: "/")
        guard parts.count == 2 else { return nil }
        self.init(
            owner: String(parts[0]),
            name: String(parts[1].trimmingSuffix(".git"))
        )
    }
}

private extension StringProtocol {
    func trimmingSuffix(_ suffix: String) -> String {
        guard hasSuffix(suffix) else { return String(self) }
        return String(self.dropLast(suffix.count))
    }
}
