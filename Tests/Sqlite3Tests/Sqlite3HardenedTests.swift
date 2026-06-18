import Foundation
import ShellKit
import Testing
@testable import Sqlite3Shell
@testable import SQLiteKit

/// Tests for the embedder-bound hardened policy (`SQLitePolicy`) — the
/// security controls that, unlike argv flags, an LLM-written command line
/// cannot relax.
@Suite struct Sqlite3HardenedTests {

    /// Drive the executable with an explicit policy (the builtin/embedder seam).
    private func run(_ argv: [String],
                     policy: SQLitePolicy = .permissive,
                     input: String = "") async throws
        -> (stdout: String, stderr: String, exit: Int32) {
        let stdoutSink = OutputSink()
        let stderrSink = OutputSink()
        let exit = try await Sqlite3Executable.run(
            argv: argv,
            policy: policy,
            stdin: .string(input),
            stdout: stdoutSink,
            stderr: stderrSink)
        stdoutSink.finish()
        stderrSink.finish()
        return (await stdoutSink.readAllString(), await stderrSink.readAllString(), exit)
    }

    // MARK: Parity

    /// Hardening must not change ordinary output: a small result renders
    /// identically under the hardened policy and the permissive default.
    @Test func hardenedOutputMatchesPermissiveForSmallResults() async throws {
        let q = ["-csv", "-header", ":memory:", "SELECT 1 AS a, 'x' AS b;"]
        let permissive = try await run(q)
        let hardened = try await run(q, policy: .hardened())
        #expect(hardened.stdout == permissive.stdout)
        #expect(hardened.exit == permissive.exit)
    }

    // MARK: Feature preservation

    /// Hardened mode gates the escape/DoS boundary, not the SQL feature
    /// surface: ordinary DDL/DML and PRAGMA still work (so vec0/FTS5 — which
    /// are CREATE VIRTUAL TABLE + functions — are not blocked).
    @Test func hardenedKeepsSQLFeatureSurface() async throws {
        let script = """
        CREATE TABLE t(a, b);
        INSERT INTO t VALUES (1, 'x');
        PRAGMA table_info(t);
        SELECT a, b FROM t;
        """
        let r = try await run([":memory:"], policy: .hardened(), input: script)
        #expect(r.exit == 0)
        #expect(r.stdout.contains("1|x"))
    }

    // MARK: Control surface — argv / dot-commands cannot relax the policy

    /// `.limit` is an in-band, LLM-controlled channel: under a hardened policy
    /// it may show or lower a limit, but a raise is refused — otherwise
    /// `.limit attached N` would undo SQLITE_LIMIT_ATTACHED=0.
    @Test func hardenedRefusesLimitRaise() async throws {
        let r = try await run([":memory:"], policy: .hardened(),
                              input: ".limit attached 9\n.limit attached\n")
        #expect(r.exit == 1)
        #expect(r.stderr.contains("cannot raise limit \"attached\""))
        // The shown value is the policy's 0, not the attempted 9.
        #expect(r.stdout.contains("attached 0"))
    }

    /// `.open` must re-apply the full policy to the new handle, not just safe
    /// mode — so an LLM can't shed the hardened limits by reconnecting.
    @Test func hardenedReappliesPolicyAfterOpen() async throws {
        let r = try await run([":memory:"], policy: .hardened(),
                              input: ".open :memory:\n.limit attached 9\n")
        #expect(r.exit == 1)
        #expect(r.stderr.contains("cannot raise limit \"attached\""))
    }

    /// The argv `-hardened` flag can only *tighten*: starting from a permissive
    /// policy it turns hardening on (and there is deliberately no flag to turn
    /// a bound policy off).
    @Test func argvHardenedTightensOnly() async throws {
        let r = try await run(["-hardened", ":memory:"], input: ".limit attached 9\n")
        #expect(r.exit == 1)
        #expect(r.stderr.contains("cannot raise limit \"attached\""))
    }

    // MARK: DoS bound — output cap

    /// A hardened result-byte cap bounds what flows back to the caller and
    /// emits a truncation notice instead of the full (large) result.
    @Test func hardenedOutputCapTruncates() async throws {
        let policy = SQLitePolicy(hardened: true, maxResultBytes: 16)
        let r = try await run(
            [":memory:"],
            policy: policy,
            input: "WITH RECURSIVE c(x) AS (SELECT 1 UNION ALL SELECT x+1 FROM c LIMIT 500) SELECT x FROM c;\n")
        #expect(r.stdout.contains("-- output truncated"))
        #expect(!r.stdout.contains("500"))
    }

    // MARK: Audit — attempted trail, written outside the DB

    /// With an embedder-set audit destination, each attempted statement is
    /// appended (JSON Lines) to a file outside the database.
    @Test func attemptedAuditTrailIsWritten() async throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("sqlite-audit-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let auditURL = dir.appendingPathComponent("trail.jsonl")

        let policy = SQLitePolicy(hardened: true, auditURL: auditURL)
        let r = try await run([":memory:", "SELECT 1;"], policy: policy)
        #expect(r.exit == 0)

        let trail = try String(contentsOf: auditURL, encoding: .utf8)
        #expect(trail.contains("\"event\":\"attempted\""))
        #expect(trail.contains("SELECT 1"))
    }
}
