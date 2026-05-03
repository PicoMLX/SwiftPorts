import ArgumentParser

struct StashClear: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "clear",
        abstract: "Remove all the stash entries."
    )

    func run() async throws {
        try await CommandContext.gitClient().stashClear()
        // Silent on success — matches real git.
    }
}
