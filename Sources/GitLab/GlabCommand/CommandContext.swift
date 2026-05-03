import Foundation
import ForgeKit
import GitLab

/// Per-process defaults for command runtime: a shared resolver, the
/// default secret store, repo resolution helper. Centralised so
/// individual subcommands have one line of boilerplate.
enum CommandContext {
    static let resolver = ConfigurationResolver()

    static func resolveConfig(host: String? = nil) async throws -> Configuration {
        try await resolver.resolve(host: host)
    }

    static func apiClient(host: String? = nil) async throws -> APIClient {
        let config = try await resolveConfig(host: host)
        return APIClient(configuration: config)
    }

    /// Repo resolution wired with the credential-check closure that
    /// only allows host grafting from the cwd remote when we actually
    /// have a token for that host. Prevents a github.com checkout
    /// from accidentally routing a gitlab.com-bound `glab issue list
    /// -R group/repo` to github.com.
    static func resolveRepo(
        flag: RepositoryReference? = nil,
        positional: RepositoryReference? = nil,
        gitClient: any GitClient = ProcessGitClient()
    ) async throws -> RepositoryReference {
        try await RepositoryResolver.resolve(
            flag: flag,
            positional: positional,
            gitClient: gitClient,
            hasCredentialsForHost: hasCredentials)
    }

    /// True when `host` has a resolvable token (env var or Keychain).
    private static func hasCredentials(for host: String) async -> Bool {
        guard let config = try? await resolver.resolve(host: host),
              let token = config.token, !token.isEmpty
        else { return false }
        return true
    }
}
