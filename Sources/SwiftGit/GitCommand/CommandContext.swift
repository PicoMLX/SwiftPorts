import Foundation
import ForgeKit
import Sandbox
import SwiftGit

/// Per-process defaults: builds a `SwiftGit.GitClient` rooted in the
/// caller's working directory, with credentials resolved from common
/// env vars when available.
enum CommandContext {
    /// Working directory used by every subcommand. Reads from the
    /// active sandbox's PWD when set, else process CWD.
    static var currentDirectory: URL {
        Sandbox.currentDirectory
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
        return { url, _, allowed in
            guard allowed.contains(.userPassword) else { return nil }

            switch url.host {
            case "github.com":
                if let token = Sandbox.env("GH_TOKEN") ?? Sandbox.env("GITHUB_TOKEN"),
                   !token.isEmpty {
                    return .token(token)
                }
            case "gitlab.com":
                if let token = Sandbox.env("GITLAB_TOKEN"), !token.isEmpty {
                    return .token(token, username: "oauth2")
                }
            default:
                break
            }

            if let user = Sandbox.env("GIT_USERNAME"),
               let pass = Sandbox.env("GIT_PASSWORD"),
               !user.isEmpty, !pass.isEmpty {
                return .userPassword(username: user, password: pass)
            }
            return nil
        }
    }
}
