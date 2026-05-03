import ArgumentParser
import Foundation
import GitHub

struct RepoView: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "view",
        abstract: "View a repository."
    )

    @Argument(help: "Repository as OWNER/REPO. Omit to use the current directory's git remote.")
    var repository: RepositoryReference?

    @Flag(name: .long, help: "Print the JSON response body.")
    var json: Bool = false

    func run() async throws {
        let target = try await RepositoryResolver.resolve(positional: repository)
        let client = try await CommandContext.apiClient()
        let repo: Repository = try await client.get("repos/\(target.slug)")

        if json {
            print(try CodableOutput.prettyJSON(repo))
            return
        }

        print("\(repo.fullName)")
        if let desc = repo.description, !desc.isEmpty {
            print(desc)
        }
        print("")
        let stats = [
            "★ \(repo.stargazersCount)",
            "⑂ \(repo.forksCount)",
            "issues \(repo.openIssuesCount)",
            "language \(repo.language ?? "—")",
            "license \(repo.license?.spdxId ?? "—")",
        ].joined(separator: "  ")
        print(stats)
        print("default branch: \(repo.defaultBranch)")
        print("html: \(repo.htmlUrl.absoluteString)")
        if let topics = repo.topics, !topics.isEmpty {
            print("topics: \(topics.joined(separator: ", "))")
        }
    }
}
