import ArgumentParser

struct AuthCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "auth",
        abstract: "Authenticate glab and your GitLab instance.",
        subcommands: [
            AuthStatus.self,
            AuthLogin.self,
            AuthLogout.self,
            AuthToken.self,
        ]
    )
}
