import ShellKit

/// The shellkit-installable face of SwiftPorts' `sqlite3` shell port — the
/// "shellkit version" that sits alongside the standalone `sqlite3` executable
/// (the "macOS CLI version", `Sqlite3Command` + the `sqlite3` target).
///
/// It bridges ``Sqlite3Executable`` (the ArgumentParser-free argv parser /
/// dot-command / REPL driver) to ShellKit's ``Command`` protocol. Because it
/// carries no ArgumentParser dependency it builds and runs on every platform
/// — Android included, where the ArgumentParser-based command surface is
/// dropped — so an embedder can install a working `sqlite3` everywhere.
///
/// Its only dependencies are ShellKit (the ``Command`` base + ``Shell/current``
/// IO) and the in-package ``Sqlite3Executable`` engine. It does **not** depend
/// on any shell host (e.g. SwiftBash); a host merely installs it. The driver
/// reads / writes through ``Shell/current`` and resolves + authorizes
/// database / `.read` / `.backup` paths through the host sandbox, so the
/// command participates fully in pipes / redirection / `$(...)` capture.
public struct Sqlite3Builtin: Command {

    /// The trusted security policy, bound by the embedder. `nil` means
    /// "automatic": harden when the host shell is sandboxed (see `run`). The
    /// command line cannot weaken whatever is resolved here — see ``SQLitePolicy``.
    private let policy: SQLitePolicy?

    public init(policy: SQLitePolicy? = nil) {
        self.policy = policy
    }

    public let name = "sqlite3"

    public func run(_ argv: [String]) async throws -> ExitStatus {
        // `Sqlite3Executable` expects argv WITHOUT the command name, per the
        // `execve` convention — the same handoff the standalone executable
        // makes. SQLite's single-dash long-option parsing, `--version` /
        // `--help`, dot-command dispatch, and the REPL all happen there.
        //
        // The security policy, by contrast, is resolved HERE (the trusted
        // registration site), never from argv: an embedder-supplied policy is
        // used as-is, otherwise we harden automatically whenever the host shell
        // has a sandbox bound — because then the SQL is agent-driven and
        // untrusted, and no command-line flag should be able to opt out.
        let resolved = policy ?? Self.automaticPolicy()
        let code = try await Sqlite3Executable.run(
            argv: Array(argv.dropFirst()),
            policy: resolved,
            stdin: Shell.current.stdin,
            stdout: Shell.current.stdout,
            stderr: Shell.current.stderr)
        return ExitStatus(code)
    }

    /// Secure default: hardened when a sandbox is active, permissive otherwise
    /// (e.g. a developer's own un-sandboxed shell, where parity with real
    /// sqlite3 is wanted).
    private static func automaticPolicy() -> SQLitePolicy {
        Shell.current.sandbox != nil ? .hardened() : .permissive
    }
}
