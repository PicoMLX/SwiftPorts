import ArgumentParser
import Foundation
import ForgeKit
import GitLab

struct RepoView: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "view",
        abstract: "Display a project's metadata.",
        aliases: ["show"]
    )

    @Option(name: [.customShort("R"), .long],
            help: "Repository as OWNER/REPO or GROUP/NAMESPACE/REPO.")
    var repo: RepositoryReference?

    @Argument(help: "Optional positional override for the repo (same syntax as -R).")
    var positional: RepositoryReference?

    @Flag(name: [.customShort("w"), .long],
          help: "Open the project in your browser.")
    var web: Bool = false

    @Flag(name: .long, help: "Print as JSON.")
    var json: Bool = false

    func run() async throws {
        let target = try await CommandContext.resolveRepo(
            flag: repo, positional: positional)
        let client = try await CommandContext.apiClient(host: target.host)
        let project: Project = try await client.get(
            "projects/\(target.encodedPath)")

        if web {
            try await Browser.open(project.webUrl)
            print("Opening \(project.webUrl.absoluteString) in your browser.")
            return
        }
        if json {
            print(try CodableOutput.prettyJSON(project))
            return
        }

        print("\(ANSI.bold(project.pathWithNamespace))  \(ANSI.dim("(#\(project.id))"))")
        print("name: \(project.name)")
        if let d = project.description, !d.isEmpty { print("description: \(d)") }
        print("visibility: \(project.visibility)")
        if let archived = project.archived, archived {
            print("\(ANSI.yellow("⚠")) archived")
        }
        if let branch = project.defaultBranch { print("default branch: \(branch)") }
        if let stars = project.starCount { print("stars: \(stars)") }
        if let forks = project.forksCount { print("forks: \(forks)") }
        if let open = project.openIssuesCount { print("open issues: \(open)") }
        print("urls:")
        print("  web:  \(project.webUrl.absoluteString)")
        if let http = project.httpUrlToRepo { print("  http: \(http.absoluteString)") }
        if let ssh = project.sshUrlToRepo { print("  ssh:  \(ssh.absoluteString)") }
    }
}
