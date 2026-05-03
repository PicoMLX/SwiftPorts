import ArgumentParser

struct VersionCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "version",
        abstract: "Print the version."
    )

    func run() async throws {
        print("glab 0.1.0-dev (SwiftPorts)")
    }
}
