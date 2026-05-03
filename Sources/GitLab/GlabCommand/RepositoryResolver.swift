import Foundation
import ForgeKit
import GitLab

/// Hand any subcommand a `--repo` value (or nothing) and an optional
/// positional, get back a concrete `RepositoryReference` or a clear
/// error if neither was provided and the cwd has no usable origin.
enum RepositoryResolver {
    /// Resolve a `RepositoryReference` from CLI inputs.
    ///
    /// `hasCredentialsForHost` gates the host-grafting convenience: a
    /// flag-only `-R group/repo` only inherits the cwd remote's host
    /// when the caller confirms credentials exist for that host. The
    /// default trusts every host (suits library callers / tests). The
    /// `glab` CLI passes a closure that consults env vars + Keychain
    /// so a github.com checkout doesn't accidentally re-route a
    /// `glab` query meant for gitlab.com.
    static func resolve(
        flag: RepositoryReference? = nil,
        positional: RepositoryReference? = nil,
        gitClient: any GitClient = ProcessGitClient(),
        hasCredentialsForHost: (String) async -> Bool = { _ in true }
    ) async throws -> RepositoryReference {
        if let positional {
            return await attachInferredHost(
                positional, gitClient: gitClient,
                hasCredentialsForHost: hasCredentialsForHost)
        }
        if let flag {
            return await attachInferredHost(
                flag, gitClient: gitClient,
                hasCredentialsForHost: hasCredentialsForHost)
        }
        if let inferred = try await gitClient.currentRepository() {
            return inferred
        }
        throw RepositoryResolverError.noRepositoryAvailable
    }

    /// If `ref` has no host but the cwd's git remote does *and* the
    /// caller says we have credentials for that host, graft it on.
    /// Lets `-R group/repo` "just work" inside a clone of a
    /// self-hosted GitLab without `--hostname` or `GITLAB_HOST`.
    private static func attachInferredHost(
        _ ref: RepositoryReference,
        gitClient: any GitClient,
        hasCredentialsForHost: (String) async -> Bool
    ) async -> RepositoryReference {
        guard ref.host == nil,
              let cwdRef = try? await gitClient.currentRepository(),
              let host = cwdRef.host,
              await hasCredentialsForHost(host)
        else { return ref }
        return RepositoryReference(host: host, pathSegments: ref.pathSegments)
    }
}

enum RepositoryResolverError: Error, LocalizedError {
    case noRepositoryAvailable

    var errorDescription: String? {
        "No repository specified and the current directory has no GitLab remote. " +
        "Use --repo OWNER/REPO (or GROUP/NAMESPACE/REPO) or run from inside a clone of a GitLab repo."
    }
}
