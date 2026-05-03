import ArgumentParser

struct RemoteCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "remote",
        abstract: "Manage remote tracking repositories.",
        subcommands: [
            RemoteAdd.self,
            RemoteGetURL.self,
        ]
    )
}
