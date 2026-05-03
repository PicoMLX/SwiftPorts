import ArgumentParser
import Foundation
import SwiftGHCore

struct AuthToken: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "token",
        abstract: "Print the auth token gh is configured to use.",
        discussion: """
        Useful for piping the token into other tools:

          GH_TOKEN=$(gh auth token) some-other-tool
        """
    )

    @Option(name: [.short, .customLong("hostname")],
            help: "Get the token for a specific hostname.")
    var hostname: String?

    func run() async throws {
        var config = Configuration.live()
        if let hostname { config.host = hostname }
        guard let token = config.token else {
            FileHandle.standardError.write(Data("no token configured\n".utf8))
            throw ExitCode(1)
        }
        print(token)
    }
}
