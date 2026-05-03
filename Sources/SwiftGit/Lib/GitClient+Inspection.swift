import Foundation
import libgit2

/// Rich result returned by ``GitClient/commitDetailed(message:author:allowEmpty:)``.
/// The CLI uses this to format `git commit`'s `[branch sha] message` line
/// plus the `<n> file(s) changed, <i> insertion(s)(+), <d> deletion(s)(-)`
/// summary and the per-file `create mode` / `delete mode` lines.
public struct Libgit2CommitDetails: Sendable {
    public let sha: String
    public let shortSHA: String
    public let branchName: String?
    public let isRoot: Bool
    public let filesChanged: Int
    public let insertions: Int
    public let deletions: Int
    public let addedFiles: [FileChange]
    public let deletedFiles: [FileChange]

    public struct FileChange: Sendable {
        public let path: String
        public let mode: UInt32
    }
}

extension GitClient {
    /// Whether `path` (relative to the repo workdir) is currently
    /// matched by a `.gitignore` rule. Throws on libgit2 failure;
    /// `false` if the path doesn't exist or isn't ignored.
    public func isIgnored(_ path: String) throws -> Bool {
        Libgit2.ensureInitialized()
        var repo: OpaquePointer?
        try check(git_repository_open_ext(&repo, workingDirectory.path, 0, nil))
        defer { git_repository_free(repo) }

        var ignored: Int32 = 0
        try check(git_ignore_path_is_ignored(&ignored, repo, path))
        return ignored != 0
    }

    /// Local branch names in the repo. Order matches libgit2's iterator
    /// (typically refdb order — alphabetical for refs/heads/*).
    public func localBranches() throws -> [String] {
        Libgit2.ensureInitialized()
        var repo: OpaquePointer?
        try check(git_repository_open_ext(&repo, workingDirectory.path, 0, nil))
        defer { git_repository_free(repo) }

        var iter: OpaquePointer?
        try check(git_branch_iterator_new(&iter, repo, GIT_BRANCH_LOCAL))
        defer { git_branch_iterator_free(iter) }

        var names: [String] = []
        while true {
            var ref: OpaquePointer?
            var branchType = GIT_BRANCH_LOCAL
            let rc = git_branch_next(&ref, &branchType, iter)
            if rc == GIT_ITEROVER.rawValue { break }
            try check(rc)
            defer { git_reference_free(ref) }
            if let cstr = git_branch_name_cstr(ref) {
                names.append(String(cString: cstr))
            }
        }
        return names
    }
}

/// Helper: libgit2's `git_branch_name` writes into a buffer, but the
/// shorthand is simpler. We use `git_reference_shorthand` since for
/// `refs/heads/X` it returns `X`.
private func git_branch_name_cstr(_ ref: OpaquePointer?) -> UnsafePointer<CChar>? {
    git_reference_shorthand(ref)
}

extension GitClient {
    /// True when a remote with `name` is already configured. Mirrors
    /// `git config remote.<name>.url` existence; used by `git remote add`
    /// to fail fast with the same error wording git uses.
    public func remoteExists(named name: String) async throws -> Bool {
        Libgit2.ensureInitialized()
        var repo: OpaquePointer?
        try check(git_repository_open_ext(&repo, workingDirectory.path, 0, nil))
        defer { git_repository_free(repo) }

        var remote: OpaquePointer?
        let rc = git_remote_lookup(&remote, repo, name)
        if rc == 0 {
            git_remote_free(remote)
            return true
        }
        if rc == GIT_ENOTFOUND.rawValue { return false }
        try check(rc)
        return false
    }
}
