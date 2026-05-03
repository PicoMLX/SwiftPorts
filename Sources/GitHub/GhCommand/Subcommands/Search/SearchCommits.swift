import ArgumentParser
import Foundation
import GitHub

struct SearchCommits: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "commits",
        abstract: "Search for commits."
    )

    @Argument(parsing: .remaining, help: "Free-form query terms.")
    var query: [String] = []

    @Option(name: [.short, .customLong("limit")], help: "Maximum results.")
    var limit: Int = 30

    @Option(name: .long, help: "Sort: author-date, committer-date, best-match (default).")
    var sort: String?

    @Option(name: .long, help: "Order: asc or desc.")
    var order: String = "desc"

    @Flag(name: .long, help: "Print as JSON array.")
    var json: Bool = false

    func run() async throws {
        guard !query.isEmpty else {
            throw ValidationError("Provide a search query.")
        }
        let client = try await CommandContext.apiClient()
        let q = query.joined(separator: " ")
        var items: [URLQueryItem] = [
            URLQueryItem(name: "q", value: q),
            URLQueryItem(name: "per_page", value: String(min(limit, 100))),
            URLQueryItem(name: "order", value: order),
        ]
        if let sort { items.append(URLQueryItem(name: "sort", value: sort)) }

        let result: SearchResult<CommitSearchItem> = try await client.get(
            "search/commits", query: items)
        let trimmed = Array(result.items.prefix(limit))

        if json {
            print(try CodableOutput.prettyJSON(trimmed))
            return
        }
        if trimmed.isEmpty {
            print("No commit matches.")
            return
        }
        print("Showing \(trimmed.count) of \(result.totalCount) results.")
        for item in trimmed {
            let firstLine = item.commit.message.split(
                whereSeparator: \.isNewline).first.map(String.init) ?? ""
            let shortSha = String(item.sha.prefix(7))
            print("\(item.repository.fullName)\t\(shortSha)\t\(item.commit.author.name)\t\(firstLine)")
        }
    }
}
