import ArgumentParser
import ShellKit
import Foundation
import GitHub

struct RepoView: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "view",
        abstract: "View a repository."
    )

    @Argument(help: "Repository as OWNER/REPO. Omit to use the current directory's git remote.")
    var repository: RepositoryReference?

    @Option(name: .long,
            help: "Output JSON with the specified fields (comma-separated).")
    var json: String?

    func run() async throws {
        let target = try await RepositoryResolver.resolve(positional: repository)

        if let json {
            let fields = try JSONFieldSelector.parse(raw: json, fieldMap: RepoFields.map)
            let gql = try await CommandContext.graphQLClient()
            let response: RepositoryViewResponse = try await gql.query(
                RepositoryViewQueries.view,
                variables: [
                    "owner": .string(target.owner),
                    "name":  .string(target.name),
                ])
            guard let repo = response.repository else {
                throw ValidationError("No repo \(target.slug).")
            }
            Shell.print(try JSONFieldSelector.render(item: repo, fields: fields, fieldMap: RepoFields.map))
            return
        }

        let client = try await CommandContext.apiClient()
        let repo: Repository = try await client.get("repos/\(target.slug)")

        Shell.print("\(repo.fullName)")
        if let desc = repo.description, !desc.isEmpty {
            Shell.print(desc)
        }
        Shell.print("")
        let stats = [
            "★ \(repo.stargazersCount)",
            "⑂ \(repo.forksCount)",
            "issues \(repo.openIssuesCount)",
            "language \(repo.language ?? "—")",
            "license \(repo.license?.spdxId ?? "—")",
        ].joined(separator: "  ")
        Shell.print(stats)
        Shell.print("default branch: \(repo.defaultBranch)")
        Shell.print("html: \(repo.htmlUrl.absoluteString)")
        if let topics = repo.topics, !topics.isEmpty {
            Shell.print("topics: \(topics.joined(separator: ", "))")
        }
    }
}
