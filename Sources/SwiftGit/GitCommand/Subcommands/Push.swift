import ArgumentParser

struct Push: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "push",
        abstract: "Update remote refs along with associated objects."
    )

    @Flag(name: [.customShort("u"), .customLong("set-upstream")],
          help: "Set the upstream tracking reference for the pushed branch.")
    var setUpstream: Bool = false

    @Option(name: [.customShort("r"), .long],
            help: "Remote name to push to.")
    var remote: String = "origin"

    @Argument(help: "Refspec to push (e.g. `main` or `HEAD:refs/heads/main`).")
    var refspec: String

    func run() async throws {
        try await CommandContext.gitClient().push(
            remote: remote, refspec: refspec, setUpstream: setUpstream)
        // Silent on success — matches `git push -q`. The transport's
        // `Writing objects:` progress + `To <url>\n   <oldsha>..<newsha>`
        // summary that real git emits aren't wired (no callbacks).
    }
}
