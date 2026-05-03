import ArgumentParser
import Foundation
import SwiftGHCore

struct SearchCode: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "code",
        abstract: "Search for code in repositories.",
        discussion: """
        Requires authentication. The query syntax matches GitHub's
        web UI (e.g. 'foo language:swift repo:cli/cli').
        """
    )

    @Argument(parsing: .remaining, help: "Free-form query terms.")
    var query: [String] = []

    @Option(name: [.short, .customLong("limit")], help: "Maximum results.")
    var limit: Int = 30

    @Flag(name: .long, help: "Print as JSON array.")
    var json: Bool = false

    func run() async throws {
        guard !query.isEmpty else {
            throw ValidationError("Provide a search query.")
        }
        let client = try await CommandContext.apiClient()
        let q = query.joined(separator: " ")
        let result: SearchResult<CodeSearchItem> = try await client.get(
            "search/code",
            query: [
                URLQueryItem(name: "q", value: q),
                URLQueryItem(name: "per_page", value: String(min(limit, 100))),
            ])
        let trimmed = Array(result.items.prefix(limit))

        if json {
            print(try CodableOutput.prettyJSON(trimmed))
            return
        }
        if trimmed.isEmpty {
            print("No code matches.")
            return
        }
        print("Showing \(trimmed.count) of \(result.totalCount) results.")
        for item in trimmed {
            print("\(item.repository.fullName)\t\(item.path)\t\(item.htmlUrl.absoluteString)")
        }
    }
}
