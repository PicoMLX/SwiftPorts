import ArgumentParser

struct AuthCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "auth",
        abstract: "Authenticate gh and git with GitHub.",
        subcommands: [AuthLogin.self, AuthLogout.self, AuthStatus.self, AuthToken.self]
    )
}
