import ArgumentParser

struct TagCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "tag",
        abstract: "Manage GitLab repository tags.",
        subcommands: [
            TagList.self,
            TagCreate.self,
            TagDelete.self,
        ]
    )
}
