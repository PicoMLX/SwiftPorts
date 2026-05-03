import ArgumentParser

struct PrCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "pr",
        abstract: "Manage pull requests.",
        subcommands: [
            PrList.self,
            PrView.self,
            PrCreate.self,
            PrEdit.self,
            PrCheckout.self,
            PrMerge.self,
            PrClose.self,
            PrReopen.self,
            PrReady.self,
            PrLock.self,
            PrUnlock.self,
            PrCommentCommand.self,
            PrDiff.self,
            PrUpdateBranch.self,
            PrChecks.self,
        ]
    )
}
