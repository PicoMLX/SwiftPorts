import ArgumentParser
import Foundation
import SwiftGHCore

struct AuthLogout: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "logout",
        abstract: "Forget the stored token for a host."
    )

    @Option(name: [.short, .customLong("hostname")],
            help: "Host to log out of. Defaults to github.com.")
    var hostname: String = Configuration.defaultHost

    func run() async throws {
        let resolver = ConfigurationResolver()
        try await resolver.remove(host: hostname)
        print("✓ Removed stored token for \(hostname).")
    }
}
