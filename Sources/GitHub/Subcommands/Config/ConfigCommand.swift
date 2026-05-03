import ArgumentParser

struct ConfigCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "config",
        abstract: "Manage gh configuration in ~/.config/gh/config.yml.",
        subcommands: [ConfigGet.self, ConfigSet.self, ConfigList.self]
    )
}
