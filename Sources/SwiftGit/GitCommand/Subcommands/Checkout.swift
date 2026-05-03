import ArgumentParser

struct Checkout: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "checkout",
        abstract: "Switch branches or restore working-tree files."
    )

    @Argument(help: "Branch name, tag, or commit-ish to check out.")
    var ref: String

    func run() async throws {
        let client = CommandContext.gitClient()
        let priorBranch = try await client.currentBranch()

        if priorBranch == ref {
            print("Already on '\(ref)'")
            return
        }

        try await client.checkout(ref: ref)

        // Real git distinguishes "Switched to branch 'X'" (ref is a
        // local branch) from "Note: switching to '<sha>'" (detached).
        // We approximate by checking whether the post-switch HEAD
        // matches our ref name.
        if let after = try? await client.currentBranch(), after == ref {
            print("Switched to branch '\(ref)'")
        } else {
            print("Note: switching to '\(ref)'.")
        }
    }
}
