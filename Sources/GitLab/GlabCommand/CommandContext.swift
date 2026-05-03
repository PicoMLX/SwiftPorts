import Foundation
import ForgeKit
import GitLab
import SwiftGit

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

    /// libgit2-backed git client. Mirrors gh's `CommandContext.gitClient()`
    /// so glab subcommands stop shelling out to /usr/bin/git for repo
    /// inference and clone/fetch/push. HTTPS auth routes through glab's
    /// existing token resolution.
    static func gitClient(
        workingDirectory: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    ) -> any ForgeKit.GitClient {
        SwiftGit.GitClient(
            workingDirectory: workingDirectory,
            credentials: tokenResolvingProvider())
    }

    /// Per-host token lookup. GitLab accepts the token as the password
    /// with `oauth2` as the magic username for HTTPS basic auth.
    private static func tokenResolvingProvider() -> CredentialProvider {
        return { url, _, allowed in
            guard allowed.contains(.userPassword) else { return nil }
            guard let host = url.host else { return nil }

            let semaphore = DispatchSemaphore(value: 0)
            nonisolated(unsafe) var token: String? = nil
            Task.detached {
                if let config = try? await resolver.resolve(host: host),
                   let t = config.token, !t.isEmpty {
                    token = t
                }
                semaphore.signal()
            }
            semaphore.wait()
            guard let token else { return nil }
            return .token(token, username: "oauth2")
        }
    }

    /// Repo resolution wired with the credential-check closure that
    /// only allows host grafting from the cwd remote when we actually
    /// have a token for that host. Prevents a github.com checkout
    /// from accidentally routing a gitlab.com-bound `glab issue list
    /// -R group/repo` to github.com.
    static func resolveRepo(
        flag: RepositoryReference? = nil,
        positional: RepositoryReference? = nil,
        gitClient: any ForgeKit.GitClient = CommandContext.gitClient()
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
