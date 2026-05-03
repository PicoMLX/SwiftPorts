import ArgumentParser

struct ProjectCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "project",
        abstract: "Work with GitHub Projects (V2).",
        subcommands: [ProjectList.self, ProjectView.self, ProjectItemList.self]
    )
}
