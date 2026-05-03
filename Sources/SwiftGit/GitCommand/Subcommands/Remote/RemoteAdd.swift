import ArgumentParser
import Foundation

struct RemoteAdd: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "add",
        abstract: "Add a remote named NAME for the repository at URL."
    )

    @Argument(help: "Name of the new remote (e.g. `origin`).")
    var name: String

    @Argument(help: "URL of the remote.")
    var url: String

    func run() async throws {
        guard let parsed = URL(string: url) else {
            throw CLIError.stderr("fatal: '\(url)' is not a valid URL", exitCode: 128)
        }

        let client = CommandContext.gitClient()
        if (try? await client.remoteExists(named: name)) == true {
            throw CLIError.stderr(
                "error: remote \(name) already exists.", exitCode: 3)
        }

        try await client.addRemote(name: name, url: parsed)
        // Silent on success — matches real git.
    }
}
