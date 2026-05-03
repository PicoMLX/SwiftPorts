import Foundation
import ForgeKit
import GitLab

/// Hand any subcommand a `--repo` value (or nothing) and an optional
/// positional, get back a concrete `RepositoryReference` or a clear
/// error if neither was provided and the cwd has no usable origin.
enum RepositoryResolver {
    static func resolve(
        flag: RepositoryReference? = nil,
        positional: RepositoryReference? = nil,
        gitClient: any GitClient = ProcessGitClient()
    ) async throws -> RepositoryReference {
        if let positional {
            return await attachInferredHost(positional, gitClient: gitClient)
        }
        if let flag {
            return await attachInferredHost(flag, gitClient: gitClient)
        }
        if let inferred = try await gitClient.currentRepository() {
            return inferred
        }
        throw RepositoryResolverError.noRepositoryAvailable
    }

    /// If `ref` has no host but the cwd's git remote does, graft that
    /// host on. Lets `-R group/repo` "just work" inside a clone of a
    /// self-hosted GitLab without `--hostname` or `GITLAB_HOST`.
    private static func attachInferredHost(
        _ ref: RepositoryReference,
        gitClient: any GitClient
    ) async -> RepositoryReference {
        guard ref.host == nil,
              let cwdRef = try? await gitClient.currentRepository(),
              let host = cwdRef.host
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
