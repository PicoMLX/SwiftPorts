import ArgumentParser

struct IssueCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "issue",
        abstract: "Manage issues.",
        subcommands: [
            IssueList.self,
            IssueView.self,
            IssueCreate.self,
            IssueCommentCommand.self,
            IssueClose.self,
            IssueReopen.self,
        ]
    )
}
