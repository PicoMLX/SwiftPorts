import ArgumentParser

struct SearchCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "search",
        abstract: "Search GitHub.",
        subcommands: [
            SearchRepos.self,
            SearchCode.self,
            SearchCommits.self,
            SearchIssuesCommand.self,
            SearchPrsCommand.self,
        ]
    )
}
