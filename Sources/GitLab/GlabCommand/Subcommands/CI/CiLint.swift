import ArgumentParser
import Foundation
import GitLab

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
            content = String(decoding: FileHandle.standardInput.availableData,
                             as: UTF8.self)
        } else {
            content = try String(contentsOf: URL(fileURLWithPath: path),
                                 encoding: .utf8)
        }

        let result: Response = try await client.send(
            method: .post,
            path: "projects/\(target.encodedPath)/ci/lint",
            body: Body(content: content))

        if result.valid {
            print("OK — config is valid.")
            for w in result.warnings { print("warning: \(w)") }
            return
        }
        for e in result.errors { print("error: \(e)") }
        for w in result.warnings { print("warning: \(w)") }
        throw ExitCode(1)
    }
}
