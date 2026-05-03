import ArgumentParser

struct WorkflowCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "workflow",
        abstract: "View GitHub Actions workflows.",
        subcommands: [WorkflowList.self, WorkflowView.self]
    )
}
