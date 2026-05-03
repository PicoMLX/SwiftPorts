import Foundation
import ForgeKit
import GitHub
import SwiftGit

/// Per-process defaults for command runtime: a shared resolver, the
/// default secret store, etc. Centralised here so individual
/// subcommands have one line of boilerplate.
enum CommandContext {
    static let resolver = ConfigurationResolver()

    static func resolveConfig(host: String? = nil) async throws -> Configuration {
        try await resolver.resolve(host: host)
    }

    static func apiClient(host: String? = nil) async throws -> APIClient {
        let config = try await resolveConfig(host: host)
        return APIClient(configuration: config)
    }

    static func graphQLClient(host: String? = nil) async throws -> GraphQLClient {
        let config = try await resolveConfig(host: host)
        return GraphQLClient(configuration: config)
    }

    /// libgit2-backed git client rooted in the caller's working
    /// directory. HTTPS authentication routes through gh's existing
    /// token resolution (env vars → Keychain → `~/.config/gh/hosts.yml`)
    /// per-host, so `gh repo clone`, `gh repo fork`, `gh pr checkout`
    /// etc. don't need a `git` binary on PATH.
    ///
    /// Returns the protocol-typed value so callers stay compatible
    /// with `NoGitClient` injection in tests / sandboxed embedders.
    static func gitClient(
        workingDirectory: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    ) -> any ForgeKit.GitClient {
        SwiftGit.GitClient(
            workingDirectory: workingDirectory,
            credentials: tokenResolvingProvider())
    }

    /// Per-host token lookup matching gh's other auth paths. We resolve
    /// `Configuration` for the URL's host on every challenge — that
    /// hits the in-memory cache for repeats, so the cost is fine.
    private static func tokenResolvingProvider() -> CredentialProvider {
        return { url, _, allowed in
            guard allowed.contains(.userPassword) else { return nil }
            guard let host = url.host else { return nil }

            // The libgit2 callback fires on a worker thread it owns,
            // so it's safe to block here. We bridge into our async
            // resolver via a semaphore.
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
            // GitHub accepts the token as the username with empty
            // password OR as `x-access-token:<token>`. The latter is
            // what the GitHub docs recommend for app installations.
            return .token(token, username: "x-access-token")
        }
    }
}
