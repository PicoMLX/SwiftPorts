import ArgumentParser

struct GistCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "gist",
        abstract: "Manage gists.",
        subcommands: [
            GistList.self,
            GistView.self,
            GistCreate.self,
            GistDelete.self,
        ]
    )
}
