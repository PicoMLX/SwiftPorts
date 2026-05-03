import Foundation

/// Async resolver that builds a ``Configuration`` by layering env
/// vars (sync, via `Configuration.live()`) with the configured
/// ``SecretStore`` (async).
///
/// Precedence for the token, mirroring upstream `gh`:
///   1. `GH_TOKEN` env var
///   2. `GITHUB_TOKEN` env var
///   3. SecretStore[service: "com.swiftgh.gh", account: <host>]
///   4. nil
///
/// Hostname order: `--hostname` flag > `GH_HOST` env > "github.com".
public struct ConfigurationResolver: Sendable {
    public let secretStore: any SecretStore
    public let service: String

    public static let defaultService = "com.swiftgh.gh"

    public init(
        secretStore: any SecretStore = DefaultSecretStore.make(),
        service: String = Self.defaultService
    ) {
        self.secretStore = secretStore
        self.service = service
    }

    /// Build the effective `Configuration`. `host` overrides `GH_HOST`
    /// when non-nil.
    public func resolve(host: String? = nil) async throws -> Configuration {
        var config = Configuration.live()
        if let host { config.host = host }
        if config.token == nil {
            config.token = try await secretStore.get(
                service: service, account: config.host)
        }
        return config
    }

    /// Stash a token into the configured secret store.
    public func store(token: String, host: String) async throws {
        try await secretStore.set(
            service: service, account: host, secret: token)
    }

    /// Drop the stored token (if any) for `host`.
    public func remove(host: String) async throws {
        try await secretStore.delete(service: service, account: host)
    }
}

/// Where the resolved token came from. Used by `gh auth status` to
/// be honest about the source.
public enum TokenSource: Sendable {
    case ghTokenEnv
    case githubTokenEnv
    case secretStore
    case none

    public static func detect(
        env: [String: String] = ProcessInfo.processInfo.environment,
        configToken: String?
    ) -> TokenSource {
        if let v = env["GH_TOKEN"], !v.isEmpty, configToken == v {
            return .ghTokenEnv
        }
        if let v = env["GITHUB_TOKEN"], !v.isEmpty, configToken == v {
            return .githubTokenEnv
        }
        if configToken != nil { return .secretStore }
        return .none
    }

    public var humanReadable: String {
        switch self {
        case .ghTokenEnv: return "GH_TOKEN env var"
        case .githubTokenEnv: return "GITHUB_TOKEN env var"
        case .secretStore: return "secret store (e.g. Keychain)"
        case .none: return "(none)"
        }
    }
}
