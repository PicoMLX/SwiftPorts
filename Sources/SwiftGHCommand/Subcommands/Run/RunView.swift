import ArgumentParser
import Foundation
import SwiftGHCore

struct RunView: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "view",
        abstract: "View a workflow run."
    )

    @Option(name: [.short, .long],
            help: "Repository as OWNER/REPO. Defaults to the current directory's git remote.")
    var repo: RepositoryReference?

    @Argument(help: "Run ID.")
    var id: Int

    @Flag(name: .long, help: "Print the JSON response body.")
    var json: Bool = false

    func run() async throws {
        let target = try await RepositoryResolver.resolve(flag: repo)
        let client = try await CommandContext.apiClient()
        let run: WorkflowRun = try await client.get(
            "repos/\(target.slug)/actions/runs/\(id)")

        if json {
            print(try CodableOutput.prettyJSON(run))
            return
        }
        print("Run #\(run.runNumber): \(run.displayTitle ?? run.name ?? "?")")
        print("status: \(run.status ?? "-")")
        print("conclusion: \(run.conclusion ?? "-")")
        print("event: \(run.event)  branch: \(run.headBranch ?? "-")  sha: \(String(run.headSha.prefix(7)))")
        if let actor = run.actor { print("actor: @\(actor.login)") }
        print("url: \(run.htmlUrl.absoluteString)")
    }
}
