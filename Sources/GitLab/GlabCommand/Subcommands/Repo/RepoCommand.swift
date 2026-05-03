import ArgumentParser

struct RepoCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "repo",
        abstract: "Work with GitLab projects (repositories).",
        subcommands: [
            RepoView.self,
            RepoList.self,
            RepoCreate.self,
            RepoClone.self,
            RepoFork.self,
            RepoArchive.self,
            RepoUnarchive.self,
            RepoEdit.self,
            RepoDelete.self,
        ]
    )
}
