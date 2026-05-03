import ArgumentParser

struct StashCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "stash",
        abstract: "Stash the changes in a dirty working directory away.",
        subcommands: [
            StashPush.self,
            StashList.self,
            StashApply.self,
            StashPop.self,
            StashDrop.self,
            StashClear.self,
            StashShow.self,
            StashBranch.self,
        ],
        // Real git: `git stash` with no subcommand is shorthand for
        // `git stash push`. Match that.
        defaultSubcommand: StashPush.self
    )
}

/// Parse a stash reference written as either a bare integer (`0`,
/// `1`, …) or in real-git form (`stash@{0}`). Returns `0` when the
/// caller passed `nil` — matches `git stash apply`/`pop` defaults.
func parseStashIndex(_ raw: String?) throws -> Int {
    guard let raw, !raw.isEmpty else { return 0 }
    if let n = Int(raw), n >= 0 { return n }
    let pattern = #/^stash@\{(\d+)\}$/#
    if let match = raw.wholeMatch(of: pattern), let n = Int(match.output.1) {
        return n
    }
    throw CLIError.stderr(
        "fatal: invalid stash reference: \(raw)", exitCode: 128)
}
