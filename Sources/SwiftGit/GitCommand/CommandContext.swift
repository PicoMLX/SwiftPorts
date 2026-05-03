import Foundation
import ForgeKit
import SwiftGit

/// Per-process defaults: builds a `SwiftGit.GitClient` rooted in the
/// caller's working directory, with credentials resolved from common
/// env vars when available.
enum CommandContext {
    /// Working directory used by every subcommand.
    static var currentDirectory: URL {
        URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    }

    /// libgit2-backed client with env-driven credential lookup.
    static func gitClient() -> SwiftGit.GitClient {
        SwiftGit.GitClient(
            workingDirectory: currentDirectory,
            credentials: envCredentialProvider())
    }

    /// `GH_TOKEN` / `GITHUB_TOKEN` for github.com, `GITLAB_TOKEN` for
    /// gitlab.com, otherwise the userpass-shaped fallback `GIT_USERNAME`
    /// + `GIT_PASSWORD`. Returns `nil` for non-userpass challenges so
    /// libgit2 surfaces a clean auth error instead of looping.
    static func envCredentialProvider() -> CredentialProvider? {
        let env = ProcessInfo.processInfo.environment
        return { url, _, allowed in
            guard allowed.contains(.userPassword) else { return nil }

            switch url.host {
            case "github.com":
                if let token = env["GH_TOKEN"] ?? env["GITHUB_TOKEN"], !token.isEmpty {
                    return .token(token)
                }
            case "gitlab.com":
                if let token = env["GITLAB_TOKEN"], !token.isEmpty {
                    return .token(token, username: "oauth2")
                }
            default:
                break
            }

            if let user = env["GIT_USERNAME"], let pass = env["GIT_PASSWORD"],
               !user.isEmpty, !pass.isEmpty {
                return .userPassword(username: user, password: pass)
            }
            return nil
        }
    }
}
