import ArgumentParser
import ShellKit

struct VersionCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "version",
        abstract: "Print the version of SwiftGH."
    )

    func run() async throws {
        Shell.print("gh (SwiftGH port) 0.1.0-dev")
        Shell.print("https://github.com/cocoanetics/SwiftGH")
    }
}
