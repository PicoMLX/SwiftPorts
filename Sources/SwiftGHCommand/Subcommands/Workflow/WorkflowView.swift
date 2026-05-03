import ArgumentParser
import Foundation
import SwiftGHCore

struct WorkflowView: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "view",
        abstract: "View a workflow."
    )

    @Option(name: [.short, .long],
            help: "Repository as OWNER/REPO. Defaults to the current directory's git remote.")
    var repo: RepositoryReference?

    @Argument(help: "Workflow ID, or filename (e.g. ci.yml).")
    var workflow: String

    @Flag(name: .long, help: "Print the JSON response body.")
    var json: Bool = false

    func run() async throws {
        let target = try await RepositoryResolver.resolve(flag: repo)
        let client = try await CommandContext.apiClient()
        let workflow: Workflow = try await client.get(
            "repos/\(target.slug)/actions/workflows/\(workflow)")

        if json {
            print(try CodableOutput.prettyJSON(workflow))
            return
        }
        print("\(workflow.name)  (#\(workflow.id))")
        print("state: \(workflow.state.rawValue)")
        print("path: \(workflow.path)")
        print("url: \(workflow.htmlUrl.absoluteString)")
    }
}
