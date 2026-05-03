import ArgumentParser

struct VariableCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "variable",
        abstract: "Manage project-scoped CI/CD variables.",
        subcommands: [
            VariableList.self,
            VariableSet.self,
            VariableUnset.self,
        ]
    )
}
