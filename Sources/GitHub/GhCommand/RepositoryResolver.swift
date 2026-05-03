import Foundation
import GitHub
import ForgeKit

/// Hand any subcommand a `--repo` value (or nothing) and an optional
/// positional, get back a concrete `RepositoryReference` or a clear
/// error if neither was provided and the cwd has no usable origin.
enum RepositoryResolver {
    static func resolve(
        flag: RepositoryReference? = nil,
        positional: RepositoryReference? = nil,
        gitClient: any GitClient = CommandContext.gitClient()
    ) async throws -> RepositoryReference {
        if let positional { return positional }
        if let flag { return flag }
        if let inferred = try await gitClient.currentRepository() {
            return inferred
        }
        throw RepositoryResolverError.noRepositoryAvailable
    }
}

enum RepositoryResolverError: Error, LocalizedError {
    case noRepositoryAvailable

    var errorDescription: String? {
        "No repository specified and the current directory has no GitHub remote. " +
        "Use --repo OWNER/NAME or run from inside a clone of a GitHub repo."
    }
}
