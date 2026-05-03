import ArgumentParser
import Foundation
import SwiftGHCore

struct AuthStatus: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "status",
        abstract: "View authentication status."
    )

    @Option(name: [.short, .customLong("hostname")],
            help: "Check a specific hostname (default: github.com or $GH_HOST).")
    var hostname: String?

    @Flag(name: [.short, .customLong("show-token")],
          help: "Print the token in the output. Skipped by default.")
    var showToken: Bool = false

    func run() async throws {
        var config = Configuration.live()
        if let hostname { config.host = hostname }

        print("\(config.host)")

        guard let token = config.token else {
            print("  X Not logged in. Set GH_TOKEN or GITHUB_TOKEN.")
            throw ExitCode(1)
        }

        let source = ProcessInfo.processInfo.environment["GH_TOKEN"]?.isEmpty == false
            ? "GH_TOKEN"
            : "GITHUB_TOKEN"

        // Probe via GraphQL viewer{} — a single round-trip that returns
        // login + url and works for fine-grained PATs that may not have
        // /user REST permission.
        let client = GraphQLClient(configuration: config)
        do {
            let result: ViewerQuery = try await client.query(ViewerQuery.query)
            print("  ✓ Logged in to \(config.host) as \(result.viewer.login) (token from \(source))")
            print("    URL: \(result.viewer.url.absoluteString)")
            if showToken {
                print("    Token: \(token)")
            } else {
                print("    Token: \(redact(token))")
            }
        } catch let APIError.unauthenticated(url) {
            print("  X Token rejected by \(url.absoluteString) (HTTP 401).")
            print("    Source: \(source)")
            throw ExitCode(1)
        } catch {
            print("  X Auth probe failed: \(error.localizedDescription)")
            throw ExitCode(1)
        }
    }

    private func redact(_ token: String) -> String {
        guard token.count > 8 else { return String(repeating: "*", count: token.count) }
        let prefix = token.prefix(4)
        return "\(prefix)" + String(repeating: "*", count: token.count - 4)
    }
}
