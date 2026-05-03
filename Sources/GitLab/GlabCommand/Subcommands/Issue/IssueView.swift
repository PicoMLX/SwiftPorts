import ArgumentParser
import Foundation
import ForgeKit
import GitLab

struct IssueView: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "view",
        abstract: "Display an issue.",
        aliases: ["show"]
    )

    @Option(name: [.customShort("R"), .long],
            help: "Repository as OWNER/REPO or GROUP/NAMESPACE/REPO.")
    var repo: RepositoryReference?

    @Argument(help: "Issue IID, `#IID`, or full issue URL.")
    var issue: String

    @Flag(name: [.customShort("w"), .long],
          help: "Open the issue in the default browser.")
    var web: Bool = false

    @Flag(name: [.customShort("c"), .long],
          help: "Show comments and activity.")
    var comments: Bool = false

    @Flag(name: .long, help: "Print as JSON.")
    var json: Bool = false

    func run() async throws {
        let parsed = try IssueArgument.parse(issue)
        let target: RepositoryReference
        if let fromURL = parsed.repoFromURL {
            target = fromURL
        } else {
            target = try await CommandContext.resolveRepo(flag: repo)
        }

        let client = try await CommandContext.apiClient(host: target.host)
        let issue: Issue = try await client.get(
            "projects/\(target.encodedPath)/issues/\(parsed.iid)")

        if web {
            try await Browser.open(issue.webUrl)
            print("Opening \(issue.webUrl.absoluteString) in your browser.")
            return
        }

        if json {
            print(try CodableOutput.prettyJSON(issue))
            return
        }

        let stateLabel: String = issue.state == .opened
            ? ANSI.green("opened")
            : ANSI.red(issue.state.rawValue)
        print("\(ANSI.bold("#\(issue.iid)"))  \(ANSI.bold(issue.title))")
        let authorBit = issue.author.map { "@\($0.username)" } ?? "—"
        print("state: \(stateLabel)  author: \(authorBit)")
        if let createdAt = issue.createdAt {
            print("created: \(ISO8601DateFormatter().string(from: createdAt))")
        }
        if !issue.labels.isEmpty {
            print("labels: \(issue.labels.joined(separator: ", "))")
        }
        if let milestone = issue.milestone {
            print("milestone: \(milestone.title)")
        }
        print("url: \(issue.webUrl.absoluteString)")
        if let body = issue.description, !body.isEmpty {
            print("\n--\n\(body)")
        }

        if comments {
            let notes: [Note] = try await client.get(
                "projects/\(target.encodedPath)/issues/\(parsed.iid)/notes",
                query: [URLQueryItem(name: "sort", value: "asc")])
            // Drop system notes by default — they are noise
            // ("changed milestone to ...") unless the user asked.
            let userNotes = notes.filter { !$0.system }
            guard !userNotes.isEmpty else {
                print("\n(no comments)")
                return
            }
            print("\n--- comments ---")
            for note in userNotes {
                let when = note.createdAt.map(ISO8601DateFormatter().string(from:)) ?? "?"
                print("\n@\(note.author.username)  \(ANSI.dim(when))")
                print(note.body)
            }
        }
    }
}
