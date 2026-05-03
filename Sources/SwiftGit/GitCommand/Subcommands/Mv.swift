import ArgumentParser
import Foundation
import SwiftGit

struct Mv: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "mv",
        abstract: "Move or rename a file, directory, or symlink."
    )

    @Argument(help: "Source path.")
    var source: String

    @Argument(help: "Destination path.")
    var destination: String

    func run() async throws {
        try await CommandContext.gitClient().move(
            from: source, to: destination)
        // Real git is silent on success.
    }
}
