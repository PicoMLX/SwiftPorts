import ArgumentParser
import Foundation
import GitLab
import ShellKit

struct CiLint: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "lint",
        abstract: "Validate a `.gitlab-ci.yml` against the project's CI lint endpoint."
    )

    @Option(name: [.customShort("R"), .long],
            help: "Repository as OWNER/REPO or GROUP/NAMESPACE/REPO.")
    var repo: RepositoryReference?

    @Argument(help: "Path to the CI config file. `-` reads stdin. Defaults to `.gitlab-ci.yml`.")
    var path: String = ".gitlab-ci.yml"

    private struct Body: Encodable {
        let content: String
    }
    private struct Response: Decodable {
        let valid: Bool
        let errors: [String]
        let warnings: [String]
        let mergedYaml: String?
    }

    func run() async throws {
        let target = try await CommandContext.resolveRepo(flag: repo)
        let client = try await CommandContext.apiClient(host: target.host)

        let content: String
        if path == "-" {
            content = String(decoding: await Shell.current.stdin.readAllData(),
                             as: UTF8.self)
        } else {
            let url = Shell.resolve(path)
            try await Shell.authorize(url)
            content = try String(contentsOf: url, encoding: .utf8)
        }

        let result: Response = try await client.send(
            method: .post,
            path: "projects/\(target.encodedPath)/ci/lint",
            body: Body(content: content))

        if result.valid {
            Shell.print("OK — config is valid.")
            for w in result.warnings { Shell.print("warning: \(w)") }
            return
        }
        for e in result.errors { Shell.print("error: \(e)") }
        for w in result.warnings { Shell.print("warning: \(w)") }
        throw ExitCode(1)
    }
}
