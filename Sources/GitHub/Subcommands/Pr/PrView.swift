import ArgumentParser
import Foundation
import GitHub

struct PrView: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "view",
        abstract: "View a pull request."
    )

    @Option(name: [.short, .long],
            help: "Repository as OWNER/REPO. Defaults to the current directory's git remote.")
    var repo: RepositoryReference?

    @Argument(help: "PR number.")
    var number: Int

    @Flag(name: .long, help: "Print the JSON response body.")
    var json: Bool = false

    func run() async throws {
        let target = try await RepositoryResolver.resolve(flag: repo)
        let client = try await CommandContext.apiClient()
        let pr: PullRequest = try await client.get(
            "repos/\(target.slug)/pulls/\(number)")

        if json {
            print(try CodableOutput.prettyJSON(pr))
            return
        }
        print("\(ANSI.bold("#\(pr.number)"))  \(ANSI.bold(pr.title))")
        let stateColor: String
        if pr.merged == true { stateColor = ANSI.magenta("merged") }
        else if pr.state == .open { stateColor = ANSI.green("open") }
        else { stateColor = ANSI.red("closed") }
        let draftSuffix = pr.draft == true ? ANSI.dim(" (draft)") : ""
        print("state: \(stateColor)\(draftSuffix)  author: @\(pr.user.login)")
        print("\(pr.head.ref) → \(pr.base.ref)")
        print("created: \(ISO8601DateFormatter().string(from: pr.createdAt))")
        if let merged = pr.merged, merged, let when = pr.mergedAt {
            print("merged: \(ISO8601DateFormatter().string(from: when))")
        }
        if !pr.labels.isEmpty {
            print("labels: \(pr.labels.map(\.name).joined(separator: ", "))")
        }
        print("url: \(pr.htmlUrl.absoluteString)")
        if let body = pr.body, !body.isEmpty {
            print("\n--\n\(body)")
        }
    }
}
