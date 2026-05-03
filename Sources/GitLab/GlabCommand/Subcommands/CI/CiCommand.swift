import ArgumentParser

struct CiCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "ci",
        abstract: "Work with GitLab CI/CD pipelines and jobs.",
        subcommands: [
            CiList.self,
            CiView.self,
            CiTrace.self,
            CiStatus.self,
            CiRetry.self,
            CiCancel.self,
            CiRun.self,
            CiLint.self,
        ]
    )
}
