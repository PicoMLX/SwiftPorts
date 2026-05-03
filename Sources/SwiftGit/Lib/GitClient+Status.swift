import Foundation
import ForgeKit
import libgit2

/// One entry in a `git status` report. We preserve both the index-side
/// state (HEAD ↔ index) and the workdir-side state (index ↔ working
/// tree) because real git's short format prints them as the two
/// columns `XY <path>`.
public struct StatusEntry: Sendable, Equatable {
    /// Repo-relative path. For renames this is the new path; the old
    /// path is in `oldPath`.
    public let path: String
    public let oldPath: String?

    public let indexState: ChangeKind
    public let workdirState: ChangeKind
    public let isUntracked: Bool
    public let isIgnored: Bool
    public let isConflicted: Bool

    public enum ChangeKind: Sendable, Equatable {
        case unchanged
        case newFile
        case modified
        case deleted
        case renamed
        case typeChange

        /// Real-git's single-letter column code for short / porcelain output.
        public var letter: Character {
            switch self {
            case .unchanged: return " "
            case .newFile: return "A"
            case .modified: return "M"
            case .deleted: return "D"
            case .renamed: return "R"
            case .typeChange: return "T"
            }
        }

        /// Real-git's verbose label (`new file:`, `modified:`, …).
        public var verboseLabel: String {
            switch self {
            case .unchanged: return ""
            case .newFile: return "new file"
            case .modified: return "modified"
            case .deleted: return "deleted"
            case .renamed: return "renamed"
            case .typeChange: return "typechange"
            }
        }
    }
}

/// Result of `Libgit2GitClient.status()`. The CLI bins these into the
/// real-git sections (Changes to be committed / Changes not staged /
/// Untracked / Unmerged) when formatting verbose output.
public struct StatusReport: Sendable {
    /// `main`, `feature/x`, …, or nil for detached HEAD.
    public let branchName: String?
    /// True when the repo has no commits yet (HEAD points at an
    /// unborn ref). Real git's verbose output adds "No commits yet".
    public let isUnborn: Bool
    public let entries: [StatusEntry]

    public var stagedEntries:  [StatusEntry] { entries.filter { $0.indexState != .unchanged && !$0.isConflicted } }
    public var unstagedEntries:[StatusEntry] { entries.filter { $0.workdirState != .unchanged && !$0.isUntracked && !$0.isConflicted } }
    public var untrackedEntries:[StatusEntry] { entries.filter { $0.isUntracked } }
    public var conflictedEntries:[StatusEntry] { entries.filter { $0.isConflicted } }
    public var isClean: Bool { entries.isEmpty }
}

extension GitClient {

    /// Produce a `git status` snapshot for the working tree. Includes
    /// untracked files; ignored files are skipped (real git's default).
    public func status() async throws -> StatusReport {
        try withRepository { repo in
            // Build options: include untracked + recurse into untracked dirs,
            // but skip ignored entries.
            var opts = git_status_options()
            try check(git_status_options_init(&opts, UInt32(GIT_STATUS_OPTIONS_VERSION)))
            opts.show = GIT_STATUS_SHOW_INDEX_AND_WORKDIR
            opts.flags =
                GIT_STATUS_OPT_INCLUDE_UNTRACKED.rawValue
                | GIT_STATUS_OPT_RECURSE_UNTRACKED_DIRS.rawValue
                | GIT_STATUS_OPT_RENAMES_HEAD_TO_INDEX.rawValue
                | GIT_STATUS_OPT_RENAMES_INDEX_TO_WORKDIR.rawValue

            var list: OpaquePointer?
            try check(git_status_list_new(&list, repo, &opts))
            defer { git_status_list_free(list) }

            var entries: [StatusEntry] = []
            let count = Int(git_status_list_entrycount(list))
            for i in 0..<count {
                guard let raw = git_status_byindex(list, i)?.pointee
                else { continue }
                if let e = makeEntry(raw) {
                    entries.append(e)
                }
            }

            // Branch + unborn-ness — match `git status`'s header logic.
            var head: OpaquePointer?
            let headRC = git_repository_head(&head, repo)
            var branchName: String? = nil
            var isUnborn = false
            if headRC == 0 {
                defer { git_reference_free(head) }
                if let cstr = git_reference_shorthand(head) {
                    let s = String(cString: cstr)
                    if s != "HEAD" { branchName = s }
                }
            } else if headRC == GIT_EUNBORNBRANCH.rawValue {
                isUnborn = true
                // Pull the planned branch name out of `HEAD` directly.
                var symbolic: OpaquePointer?
                if git_reference_lookup(&symbolic, repo, "HEAD") == 0 {
                    defer { git_reference_free(symbolic) }
                    if let cstr = git_reference_symbolic_target(symbolic) {
                        let target = String(cString: cstr)
                        let prefix = "refs/heads/"
                        if target.hasPrefix(prefix) {
                            branchName = String(target.dropFirst(prefix.count))
                        }
                    }
                }
            } else {
                try check(headRC)
            }

            return StatusReport(
                branchName: branchName, isUnborn: isUnborn, entries: entries)
        }
    }

    /// Translate one `git_status_entry` into our `StatusEntry`.
    private func makeEntry(_ raw: git_status_entry) -> StatusEntry? {
        // Rename info lives in the diff_delta payloads. Prefer the
        // workdir delta's path if present (renames + later edits).
        let primaryDelta = raw.index_to_workdir ?? raw.head_to_index
        guard let dPtr = primaryDelta else { return nil }
        let delta = dPtr.pointee
        let newPath = String(cString: delta.new_file.path
            ?? delta.old_file.path)
        let oldPath: String? = {
            guard delta.status == GIT_DELTA_RENAMED else { return nil }
            return delta.old_file.path.map { String(cString: $0) }
        }()

        let s = raw.status.rawValue
        let conflicted = (s & GIT_STATUS_CONFLICTED.rawValue) != 0
        let ignored = (s & GIT_STATUS_IGNORED.rawValue) != 0
        let untracked = (s & GIT_STATUS_WT_NEW.rawValue) != 0
            && (s & UInt32(0x7F)) == 0   // no index-side changes

        // Map the libgit2 status bitmask to our two column states.
        var index: StatusEntry.ChangeKind = .unchanged
        if      (s & GIT_STATUS_INDEX_NEW.rawValue) != 0       { index = .newFile }
        else if (s & GIT_STATUS_INDEX_MODIFIED.rawValue) != 0  { index = .modified }
        else if (s & GIT_STATUS_INDEX_DELETED.rawValue) != 0   { index = .deleted }
        else if (s & GIT_STATUS_INDEX_RENAMED.rawValue) != 0   { index = .renamed }
        else if (s & GIT_STATUS_INDEX_TYPECHANGE.rawValue) != 0{ index = .typeChange }

        var workdir: StatusEntry.ChangeKind = .unchanged
        if      (s & GIT_STATUS_WT_NEW.rawValue) != 0          { workdir = .newFile }
        if      (s & GIT_STATUS_WT_MODIFIED.rawValue) != 0     { workdir = .modified }
        else if (s & GIT_STATUS_WT_DELETED.rawValue) != 0      { workdir = .deleted }
        else if (s & GIT_STATUS_WT_RENAMED.rawValue) != 0      { workdir = .renamed }
        else if (s & GIT_STATUS_WT_TYPECHANGE.rawValue) != 0   { workdir = .typeChange }

        return StatusEntry(
            path: newPath, oldPath: oldPath,
            indexState: index, workdirState: workdir,
            isUntracked: untracked, isIgnored: ignored,
            isConflicted: conflicted)
    }
}

// MARK: Formatting

extension StatusReport {

    /// Real-git's `--short` / `--porcelain` format: `XY <path>` per
    /// entry. With `branchHeader: true`, prepend a `## <branch>` line.
    public func shortFormat(branchHeader: Bool = false) -> String {
        var out = ""
        if branchHeader {
            if isUnborn {
                out += "## No commits yet on \(branchName ?? "HEAD")\n"
            } else {
                out += "## \(branchName ?? "HEAD (no branch)")\n"
            }
        }
        for e in entries {
            let x: Character
            let y: Character
            if e.isUntracked {
                x = "?"; y = "?"
            } else if e.isConflicted {
                x = "U"; y = "U"
            } else {
                x = e.indexState.letter
                y = e.workdirState.letter
            }
            out += "\(x)\(y) \(e.path)\n"
        }
        return out
    }

    /// Real-git's verbose `git status` format, including branch line,
    /// per-section headers + hint blocks, and the closing `nothing to
    /// commit` line when applicable.
    public func verboseFormat() -> String {
        var out = "On branch \(branchName ?? "HEAD")\n"
        if isUnborn {
            // Real git: blank line on either side of `No commits yet`.
            out += "\nNo commits yet\n\n"
        }

        let staged = stagedEntries
        let unstaged = unstagedEntries
        let untracked = untrackedEntries
        let conflicts = conflictedEntries

        // Real git separates each non-empty section with one blank
        // line before its header, then ends with one trailing blank
        // line. We just emit `\n` before each section's body.

        if !staged.isEmpty {
            out += "Changes to be committed:\n"
            out += "  (use \"git restore --staged <file>...\" to unstage)\n"
            for e in staged {
                let label = e.indexState.verboseLabel
                if e.indexState == .renamed, let oldPath = e.oldPath {
                    out += "\t\(label):   \(oldPath) -> \(e.path)\n"
                } else {
                    out += "\t\(label):   \(e.path)\n"
                }
            }
            out += "\n"
        }

        if !unstaged.isEmpty {
            out += "Changes not staged for commit:\n"
            out += "  (use \"git add <file>...\" to update what will be committed)\n"
            out += "  (use \"git restore <file>...\" to discard changes in working directory)\n"
            for e in unstaged {
                let label = e.workdirState.verboseLabel
                out += "\t\(label):   \(e.path)\n"
            }
            out += "\n"
        }

        if !conflicts.isEmpty {
            out += "Unmerged paths:\n"
            out += "  (use \"git add <file>...\" to mark resolution)\n"
            for e in conflicts {
                out += "\tboth modified:   \(e.path)\n"
            }
            out += "\n"
        }

        if !untracked.isEmpty {
            out += "Untracked files:\n"
            out += "  (use \"git add <file>...\" to include in what will be committed)\n"
            for e in untracked {
                out += "\t\(e.path)\n"
            }
            out += "\n"
        }

        if isClean {
            if isUnborn {
                out += "\nnothing to commit (create/copy files and use \"git add\" to track)\n"
            } else {
                out += "nothing to commit, working tree clean\n"
            }
        } else if staged.isEmpty && unstaged.isEmpty && conflicts.isEmpty {
            // Untracked-only scenario.
            out += "nothing added to commit but untracked files present (use \"git add\" to track)\n"
        }
        return out
    }
}
