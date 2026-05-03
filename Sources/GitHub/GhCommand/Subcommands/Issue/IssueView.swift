import ArgumentParser
import Foundation
import GitHub
import ForgeKit

struct IssueView: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "view",
        abstract: "View an issue."
    )

    @Option(name: [.short, .long],
            help: "Repository as OWNER/REPO. Defaults to the current directory's git remote.")
    var repo: RepositoryReference?

    @Argument(help: "Issue number.")
    var number: Int

    @Flag(name: .long, help: "Print the JSON response body.")
    var json: Bool = false

    func run() async throws {
        let target = try await RepositoryResolver.resolve(flag: repo)
        let client = try await CommandContext.apiClient()
        let issue: Issue = try await client.get(
            "repos/\(target.slug)/issues/\(number)")

        if json {
            print(try CodableOutput.prettyJSON(issue))
            return
        }
        print("\(ANSI.bold("#\(issue.number)"))  \(ANSI.bold(issue.title))")
        let stateColor: String = issue.state == .open ? ANSI.green("open") : ANSI.magenta("closed")
        print("state: \(stateColor)  author: @\(issue.user.login)")
        print("created: \(ISO8601DateFormatter().string(from: issue.createdAt))")
        if !issue.labels.isEmpty {
            print("labels: \(issue.labels.map(\.name).joined(separator: ", "))")
        }
        print("url: \(issue.htmlUrl.absoluteString)")
        if let body = issue.body, !body.isEmpty {
            print("\n--\n\(body)")
        }
    }
}
