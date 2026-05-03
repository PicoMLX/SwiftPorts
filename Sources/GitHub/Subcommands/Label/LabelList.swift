import ArgumentParser
import Foundation
import GitHub

struct LabelList: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List the labels in a repository."
    )

    @Option(name: [.short, .long],
            help: "Repository as OWNER/REPO. Defaults to the current directory's git remote.")
    var repo: RepositoryReference?

    @Option(name: [.short, .customLong("limit")], help: "Maximum labels to fetch.")
    var limit: Int = 100

    @Flag(name: .long, help: "Print as JSON array.")
    var json: Bool = false

    func run() async throws {
        let target = try await RepositoryResolver.resolve(flag: repo)
        let client = try await CommandContext.apiClient()
        let labels: [Label] = try await client.get(
            "repos/\(target.slug)/labels",
            query: [URLQueryItem(name: "per_page", value: String(min(limit, 100)))])
        let trimmed = Array(labels.prefix(limit))

        if json {
            print(try CodableOutput.prettyJSON(trimmed))
            return
        }
        if trimmed.isEmpty {
            print("No labels in \(target.slug).")
            return
        }
        for l in trimmed {
            let desc = l.description ?? ""
            print("\(l.name)\t#\(l.color)\t\(desc)")
        }
    }
}
