import ArgumentParser
import SwiftGit

struct Branch: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "branch",
        abstract: "List branches or query the current/upstream ref."
    )

    @Flag(name: .customLong("show-current"),
          help: "Print the current branch name and exit.")
    var showCurrent: Bool = false

    @Option(name: .customLong("upstream"),
            help: "Print the upstream tracking branch of LOCAL_BRANCH (extension; not a real git flag).",
            transform: { $0 })
    var upstream: String?

    func run() async throws {
        let client = CommandContext.gitClient()

        if let local = upstream {
            if let upstream = try await client.upstreamBranch(of: local) {
                print(upstream)
            }
            return
        }

        if showCurrent {
            if let current = try await client.currentBranch() {
                print(current)
            }
            return
        }

        // Bare `git branch`: list local branches with the current one
        // marked by `*`. Two-space indent for non-current branches
        // matches real git's output exactly.
        let current = try await client.currentBranch()
        let names = (try? client.localBranches()) ?? []
        let sorted = names.sorted()
        for name in sorted {
            if name == current {
                print("* \(name)")
            } else {
                print("  \(name)")
            }
        }
    }
}
