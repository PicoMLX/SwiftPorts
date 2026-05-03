import ArgumentParser

struct LabelCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "label",
        abstract: "Manage labels.",
        subcommands: [LabelList.self]
    )
}
