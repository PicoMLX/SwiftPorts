import ArgumentParser
import Foundation
import SwiftGHCore

struct WorkflowList: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List the workflows in a repository."
    )

    @Option(name: [.short, .long],
            help: "Repository as OWNER/REPO. Defaults to the current directory's git remote.")
    var repo: RepositoryReference?

    @Option(name: [.short, .customLong("limit")], help: "Maximum workflows to fetch.")
    var limit: Int = 50

    @Flag(name: .long, help: "Print as JSON array.")
    var json: Bool = false

    func run() async throws {
        let target = try await RepositoryResolver.resolve(flag: repo)
        let client = try await CommandContext.apiClient()
        let envelope: WorkflowList_API = try await client.get(
            "repos/\(target.slug)/actions/workflows",
            query: [URLQueryItem(name: "per_page", value: String(min(limit, 100)))])

        let trimmed = Array(envelope.workflows.prefix(limit))
        if json {
            print(try CodableOutput.prettyJSON(trimmed))
            return
        }
        if trimmed.isEmpty {
            print("No workflows in \(target.slug).")
            return
        }
        for w in trimmed {
            print("\(w.id)\t\(w.state.rawValue)\t\(w.name)\t\(w.path)")
        }
    }
}

// `WorkflowList` (the command) collides with the `WorkflowList`
// envelope type in SwiftGHCore. Aliased here to keep both the type
// and the subcommand readable.
private typealias WorkflowList_API = SwiftGHCore.WorkflowList
