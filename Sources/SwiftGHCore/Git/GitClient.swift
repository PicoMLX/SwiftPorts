import Foundation

/// Read-only access to the surrounding git repository.
///
/// Implementations exist to figure out OWNER/REPO from `git remote
/// get-url origin` so users don't need to type `-R owner/name` on
/// every command. Other consumers (e.g. `gh pr create` for default
/// head branch) will land more methods here later.
///
/// Default impl `ProcessGitClient` shells out to `git`. Tests inject
/// a stub. Embedders without a usable `git` binary inject a
/// `NoGitClient` and force `-R` everywhere.
public protocol GitClient: Sendable {
    /// Resolve a remote name (typically `origin`) to a URL.
    /// `nil` if the remote doesn't exist.
    func remoteURL(named: String) async throws -> URL?

    /// Best-effort current branch name. `nil` if detached HEAD or
    /// not in a repo.
    func currentBranch() async throws -> String?
}

extension GitClient {
    /// Convenience: parse `remoteURL(named:)` into a
    /// `RepositoryReference`. Returns `nil` if the remote doesn't
    /// resolve to a `host:owner/name`-style URL.
    public func currentRepository(remote: String = "origin") async throws -> RepositoryReference? {
        guard let url = try await remoteURL(named: remote) else { return nil }
        return RepositoryReference(parsingRemoteURL: url)
    }
}

/// Used by embedders without a usable `git` binary (sandboxed iOS,
/// Playgrounds, server contexts). Every method returns `nil`,
/// forcing callers to provide the repo via `--repo`.
public struct NoGitClient: GitClient {
    public init() {}
    public func remoteURL(named: String) async throws -> URL? { nil }
    public func currentBranch() async throws -> String? { nil }
}
