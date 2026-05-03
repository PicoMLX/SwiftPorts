import ArgumentParser

struct IssueCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "issue",
        abstract: "Work with GitLab issues.",
        subcommands: [
            IssueList.self,
            IssueView.self,
            IssueCreate.self,
            IssueUpdate.self,
            IssueClose.self,
            IssueReopen.self,
            IssueNote.self,
            IssueSubscribe.self,
            IssueUnsubscribe.self,
            IssueDelete.self,
            IssueBoard.self,
        ]
    )
}
