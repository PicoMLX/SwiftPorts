import ArgumentParser

struct MrCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "mr",
        abstract: "Work with GitLab merge requests.",
        subcommands: [
            MrList.self,
            MrView.self,
            MrCreate.self,
            MrUpdate.self,
            MrClose.self,
            MrReopen.self,
            MrMerge.self,
            MrApprove.self,
            MrUnapprove.self,
            MrNote.self,
            MrSubscribe.self,
            MrUnsubscribe.self,
            MrCheckout.self,
            MrDiff.self,
            MrDelete.self,
        ]
    )
}
