import ArgumentParser
import Foundation
import GitHub

struct RunList: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List recent workflow runs."
    )

    @Option(name: [.short, .long],
            help: "Repository as OWNER/REPO. Defaults to the current directory's git remote.")
    var repo: RepositoryReference?

    @Option(name: [.short, .customLong("limit")], help: "Maximum runs to fetch.")
    var limit: Int = 30

    @Option(name: .customLong("workflow"),
            help: "Filter by workflow ID or filename.")
    var workflow: String?

    @Option(name: .customLong("branch"),
            help: "Filter by branch.")
    var branch: String?

    @Option(name: .customLong("status"),
            help: "Filter by status (queued, in_progress, completed).")
    var status: String?

    @Option(name: .customLong("event"),
            help: "Filter by event (push, pull_request, etc).")
    var event: String?

    @Flag(name: .long, help: "Print as JSON array.")
    var json: Bool = false

    func run() async throws {
        let target = try await RepositoryResolver.resolve(flag: repo)
        let client = try await CommandContext.apiClient()

        let path: String
        if let workflow {
            path = "repos/\(target.slug)/actions/workflows/\(workflow)/runs"
        } else {
            path = "repos/\(target.slug)/actions/runs"
        }

        var query: [URLQueryItem] = [
            URLQueryItem(name: "per_page", value: String(min(limit, 100))),
        ]
        if let branch { query.append(URLQueryItem(name: "branch", value: branch)) }
        if let status { query.append(URLQueryItem(name: "status", value: status)) }
        if let event { query.append(URLQueryItem(name: "event", value: event)) }

        let envelope: WorkflowRunList = try await client.get(path, query: query)
        let trimmed = Array(envelope.workflowRuns.prefix(limit))

        if json {
            print(try CodableOutput.prettyJSON(trimmed))
            return
        }
        if trimmed.isEmpty {
            print("No runs match.")
            return
        }
        for run in trimmed {
            let status = run.conclusion ?? run.status ?? "?"
            let title = run.displayTitle ?? run.name ?? "?"
            let when = ISO8601DateFormatter().string(from: run.createdAt)
            print("\(run.id)\t\(status)\t\(run.event)\t\(title)\t\(run.headBranch ?? "-")\t\(when)")
        }
    }
}
