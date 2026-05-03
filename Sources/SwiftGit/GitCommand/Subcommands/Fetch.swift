import ArgumentParser

struct Fetch: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "fetch",
        abstract: "Download objects and refs from a remote."
    )

    @Option(name: [.customShort("r"), .long],
            help: "Remote name to fetch from.")
    var remote: String = "origin"

    @Argument(help: "Refspec to fetch (e.g. `main` or `+refs/heads/*:refs/remotes/origin/*`).")
    var refspec: String

    func run() async throws {
        try await CommandContext.gitClient().fetch(remote: remote, refspec: refspec)
        // Silent on success — matches `git fetch -q`. We don't wire the
        // libgit2 progress callbacks, so the per-ref `From <url>\n   <oldsha>..<newsha>`
        // lines real git prints aren't available here.
    }
}
