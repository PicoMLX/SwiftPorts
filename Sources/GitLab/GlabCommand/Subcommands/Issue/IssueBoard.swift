import ArgumentParser
import Foundation
import ForgeKit
import GitLab

struct IssueBoard: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "board",
        abstract: "Open the project's issue board in a browser.",
        discussion: """
            The terminal kanban interface from upstream glab is not
            implemented in this port. `--view`/`view` opens the board
            page in your browser, which gives you the full kanban UI.
            """,
        subcommands: [IssueBoardView.self],
        defaultSubcommand: IssueBoardView.self
    )
}

struct IssueBoardView: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "view",
        abstract: "Open the issue board in your browser."
    )

    @Option(name: [.customShort("R"), .long],
            help: "Repository as OWNER/REPO or GROUP/NAMESPACE/REPO.")
    var repo: RepositoryReference?

    func run() async throws {
        let target = try await RepositoryResolver.resolve(flag: repo)
        let host = target.host ?? Configuration.defaultHost
        guard let url = URL(string: "https://\(host)/\(target.fullPath)/-/boards") else {
            throw BoardError.invalidURL
        }
        try await Browser.open(url)
        print("Opening \(url.absoluteString) in your browser.")
    }
}

private enum BoardError: Error, LocalizedError {
    case invalidURL
    var errorDescription: String? { "Could not build a board URL for the resolved repo." }
}
