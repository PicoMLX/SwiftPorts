import ArgumentParser
import Foundation
import GitHub
import ForgeKit

struct PrChecks: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "checks",
        abstract: "Show CI/check-run status for a pull request."
    )

    @Option(name: [.short, .long],
            help: "Repository as OWNER/REPO. Defaults to the current directory's git remote.")
    var repo: RepositoryReference?

    @Argument(help: "PR number.")
    var number: Int

    @Flag(name: .long, help: "Print as JSON array.")
    var json: Bool = false

    func run() async throws {
        let target = try await RepositoryResolver.resolve(flag: repo)
        let client = try await CommandContext.apiClient()
        let pr: PullRequest = try await client.get("repos/\(target.slug)/pulls/\(number)")
        let envelope: CheckRunList = try await client.get(
            "repos/\(target.slug)/commits/\(pr.head.sha)/check-runs")

        if json {
            print(try CodableOutput.prettyJSON(envelope.checkRuns))
            return
        }
        if envelope.checkRuns.isEmpty {
            print("No check runs for #\(number).")
            return
        }
        for c in envelope.checkRuns {
            let outcome = c.conclusion ?? c.status
            let glyph: String
            switch outcome {
            case "success": glyph = ANSI.green("✓")
            case "failure", "cancelled", "timed_out", "action_required":
                glyph = ANSI.red("✗")
            case "skipped", "neutral", "stale": glyph = ANSI.dim("-")
            case "in_progress", "queued", "pending", "waiting":
                glyph = ANSI.yellow("…")
            default: glyph = "?"
            }
            print("\(glyph) \(c.name)\t\(outcome)")
        }
    }
}
