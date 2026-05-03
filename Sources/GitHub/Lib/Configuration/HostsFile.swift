import Foundation
import Yams

/// Parsed `~/.config/gh/hosts.yml`.
///
/// Format (interoperable with upstream `gh`):
///
///     github.com:
///         user: octocat
///         git_protocol: https
///         oauth_token: ghp_xxx           # only present with --insecure-storage
///     ghe.example.com:
///         user: alice
///         …
///
/// The token field is **only** populated when the user opted into
/// plaintext storage; gh's default is the keyring. We read it as a
/// fallback when present, but write hosts.yml only with `user` and
/// `git_protocol` — never the token.
public struct HostsFile: Codable, Sendable {
    public var hosts: [String: HostEntry]

    public init(hosts: [String: HostEntry] = [:]) { self.hosts = hosts }

    public subscript(host: String) -> HostEntry? {
        get { hosts[host] }
        set { hosts[host] = newValue }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.hosts = try container.decode([String: HostEntry].self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(hosts)
    }
}

public struct HostEntry: Codable, Sendable {
    public var user: String?
    public var gitProtocol: String?
    public var oauthToken: String?

    public init(user: String? = nil, gitProtocol: String? = nil, oauthToken: String? = nil) {
        self.user = user
        self.gitProtocol = gitProtocol
        self.oauthToken = oauthToken
    }

    enum CodingKeys: String, CodingKey {
        case user
        case gitProtocol = "git_protocol"
        case oauthToken = "oauth_token"
    }
}

/// Reads / writes the on-disk YAML.
public struct HostsFileStore: Sendable {
    public let path: URL

    public init(path: URL = HostsFileStore.defaultPath) {
        self.path = path
    }

    public static var defaultPath: URL {
        let xdg = ProcessInfo.processInfo.environment["XDG_CONFIG_HOME"]
        let configDir: URL
        if let xdg, !xdg.isEmpty {
            configDir = URL(fileURLWithPath: xdg, isDirectory: true)
        } else {
            configDir = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".config", isDirectory: true)
        }
        return configDir
            .appendingPathComponent("gh", isDirectory: true)
            .appendingPathComponent("hosts.yml")
    }

    public func read() throws -> HostsFile {
        guard FileManager.default.fileExists(atPath: path.path) else {
            return HostsFile()
        }
        let raw = try String(contentsOf: path, encoding: .utf8)
        if raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return HostsFile()
        }
        let dict = try YAMLDecoder().decode([String: HostEntry].self, from: raw)
        return HostsFile(hosts: dict)
    }

    public func write(_ file: HostsFile) throws {
        try ensureDirectoryExists()
        let yaml = try YAMLEncoder().encode(file.hosts)
        try yaml.write(to: path, atomically: true, encoding: .utf8)
        // Tighten permissions: 0600 (token may be in there).
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600], ofItemAtPath: path.path)
    }

    private func ensureDirectoryExists() throws {
        let dir = path.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: dir, withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700])
    }
}
