import ArgumentParser
import ShellKit
import Foundation
import GitHub

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

    func run() async throws {
        let target = try await RepositoryResolver.resolve(flag: repo)
        let client = try await CommandContext.apiClient()
        let workflow: Workflow = try await client.get(
            "repos/\(target.slug)/actions/workflows/\(workflow)")

        Shell.print("\(workflow.name)  (#\(workflow.id))")
        Shell.print("state: \(workflow.state.rawValue)")
        Shell.print("path: \(workflow.path)")
        Shell.print("url: \(workflow.htmlUrl.absoluteString)")
    }
}
