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

    /// The output cap must also bound data-bearing dot-commands (`.dump`,
    /// `.schema`, `.print`), not just SQL result sets — otherwise an untrusted
    /// script could exfiltrate unbounded output through a dot-command.
    @Test func hardenedCapsDotCommandOutput() async throws {
        let policy = SQLitePolicy(hardened: true, maxResultBytes: 16)
        let long = String(repeating: "A", count: 500)
        let r = try await run([":memory:"], policy: policy, input: ".print \(long)\n")
        #expect(r.stdout.contains("-- output truncated"))
        #expect(!r.stdout.contains(long))
    }

    /// Hardened mode does not lexically refuse `PRAGMA temp_store=FILE;` (that
    /// guard proved unsound — see Sqlite3Executable.runStatement). Instead temp
    /// confinement holds by *re-pinning* temp_store=MEMORY before every
    /// statement: even after a statement sets it to FILE, the next read sees
    /// MEMORY (2). So later sorts/temp tables still can't spill across a
    /// statement boundary.
    @Test func hardenedRepinsTempStoreAcrossStatements() async throws {
        let r = try await run([":memory:"], policy: .hardened(),
                              input: "PRAGMA temp_store=FILE;\nPRAGMA temp_store;\n")
        #expect(r.exit == 0)                       // not refused — the set runs
        #expect(r.stdout.contains("2"))            // re-pinned to MEMORY on read
    }

    /// Audit is a trusted control recorded before execution: if its
    /// destination is unwritable, the run must fail closed rather than execute
    /// unaudited SQL. (Here the audit path is a directory, so the open fails.)
    @Test func hardenedFailsClosedWhenAuditUnwritable() async throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("sqlite-audit-dir-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let policy = SQLitePolicy(hardened: true, auditURL: dir)
        let r = try await run([":memory:", "SELECT 1;"], policy: policy)
        #expect(r.exit == 1)
        #expect(!r.stdout.contains("1"))   // SQL never ran
        #expect(r.stderr.contains("audit log"))
    }

    /// A forced read-only policy blocks `.backup` (which would create/write a
    /// database file in-band despite the policy).
    @Test func readOnlyPolicyBlocksBackup() async throws {
        let policy = SQLitePolicy(hardened: true, forceReadOnly: true)
        let r = try await run([":memory:"], policy: policy, input: ".backup out.db\n")
        #expect(r.exit == 1)
        #expect(r.stderr.contains("read-only policy"))
    }

    /// A file-touching dot-command may not target the audit log itself, or an
    /// in-band `.output <auditURL>` could overwrite the trusted trail.
    @Test func auditLogPathIsReservedFromDotCommands() async throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("sqlite-audit-reserve-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let auditURL = dir.appendingPathComponent("trail.jsonl")

        let policy = SQLitePolicy(hardened: true, auditURL: auditURL)
        let r = try await run([":memory:"], policy: policy,
                              input: ".output \(auditURL.path)\nSELECT 1;\n")
        #expect(r.stderr.contains("audit log"))
    }

    /// `VACUUM INTO` writes a database file directly (bypassing the sandbox);
    /// it must be refused under a hardened policy.
    @Test func hardenedBlocksVacuumInto() async throws {
        let r = try await run([":memory:"], policy: .hardened(),
                              input: "VACUUM INTO 'out.db';\n")
        #expect(r.exit == 1)
        #expect(r.stderr.contains("VACUUM INTO"))
    }

    /// The VACUUM-INTO guard must catch every quoted-schema form SQLite accepts
    /// — bracketed, back-quoted, and double-quoted — *including* the no-space
    /// adjacent forms (`VACUUM[main]INTO`), since a quoted identifier is
    /// self-delimiting. All of these write a file directly and must be refused.
    @Test func hardenedBlocksQuotedSchemaVacuumInto() async throws {
        let forms = [
            "VACUUM [main] INTO 'out.db';",
            "VACUUM `main` INTO 'out.db';",
            "VACUUM \"main\" INTO 'out.db';",
            "VACUUM[main]INTO 'out.db';",          // no spaces around [main]
            "VACUUM`main`INTO 'out.db';",          // no spaces around `main`
        ]
        for sql in forms {
            let r = try await run([":memory:"], policy: .hardened(), input: sql + "\n")
            #expect(r.exit == 1, "should refuse: \(sql)")
            #expect(r.stderr.contains("VACUUM INTO"), "should report VACUUM INTO: \(sql)")
        }
    }

    /// The VACUUM-INTO guard must not refuse a *string literal* that merely
    /// mentions the keywords — that's ordinary SQL, and hardened mode preserves
    /// the SQL feature surface.
    @Test func hardenedAllowsVacuumIntoInsideStringLiteral() async throws {
        let r = try await run([":memory:", "SELECT 'vacuum into' AS x;"], policy: .hardened())
        #expect(r.exit == 0)
        #expect(r.stdout.contains("vacuum into"))
    }

    /// A read-only policy (even without hardened mode) blocks ATTACH, which
    /// would otherwise open a writable auxiliary database in-band.
    @Test func readOnlyPolicyBlocksAttach() async throws {
        let policy = SQLitePolicy(hardened: false, forceReadOnly: true)
        let r = try await run([":memory:", "ATTACH ':memory:' AS aux;"], policy: policy)
        #expect(r.exit != 0)
        #expect(!r.stderr.isEmpty)
    }

    /// The statement-anchored guards must not false-positive on policy keywords
    /// (or a fake `;`) that appear inside a string *value* rather than as a
    /// leading statement keyword.
    @Test func hardenedAllowsGuardKeywordsInsideStringValues() async throws {
        let r = try await run(
            [":memory:", "SELECT 'x; PRAGMA temp_store=FILE; VACUUM INTO y' AS k;"],
            policy: .hardened())
        #expect(r.exit == 0)
        #expect(r.stdout.contains("PRAGMA temp_store=FILE"))
    }

    /// A read-only policy (even without hardened mode) must also block `.limit`
    /// raises — otherwise `.limit attached 1` would undo the ATTACH lockout.
    @Test func readOnlyPolicyBlocksLimitRaise() async throws {
        let policy = SQLitePolicy(hardened: false, forceReadOnly: true)
        let r = try await run([":memory:"], policy: policy, input: ".limit attached 1\n")
        #expect(r.exit == 1)
        #expect(r.stderr.contains("cannot raise limit"))
    }

    /// The hardened output cap covers stderr too, so a script can't exfiltrate
    /// unbounded bytes via error/caret output.
    @Test func hardenedCapsStderrOutput() async throws {
        let policy = SQLitePolicy(hardened: true, maxResultBytes: 8)
        let r = try await run([":memory:"], policy: policy,
                              input: ".nope a fairly long unknown dot-command line\n")
        #expect(r.stderr.contains("-- output truncated"))
    }

    /// The initial database path may not be the audit log either (not just
    /// dot-command targets).
    @Test func databasePathMayNotBeAuditLog() async throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("sqlite-audit-dbpath-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let auditURL = dir.appendingPathComponent("trail.jsonl")

        let policy = SQLitePolicy(hardened: true, auditURL: auditURL)
        let r = try await run([auditURL.path, "SELECT 1;"], policy: policy)
        #expect(r.exit == 1)
        #expect(r.stderr.contains("audit log"))
    }

    /// An argv parse failure happens *before* the `Session` (and its capped
    /// `emit`) exists, so the early stderr write must honor the output cap too —
    /// otherwise an untrusted `sqlite3 -<many bytes>`, whose "unknown option"
    /// error echoes the oversized argv, streams an uncapped error back despite
    /// the hardened cap. (Codex review P2, PR #1.)
    @Test func hardenedCapsPreSessionParseError() async throws {
        let policy = SQLitePolicy(hardened: true, maxResultBytes: 8)
        let huge = "-" + String(repeating: "z", count: 4096)   // unknown long option
        let r = try await run([huge, ":memory:"], policy: policy)
        #expect(r.exit == 1)
        #expect(r.stderr.contains("-- output truncated"))
        // The oversized argv is not echoed back uncapped.
        #expect(r.stderr.utf8.count < 200)
        #expect(!r.stderr.contains(String(repeating: "z", count: 64)))
    }

    /// `maxResultBytes` is public config: a negative value must not trap the
    /// pre-`Session` cap (it's clamped to 0). The run returning at all proves no
    /// `prefix(_:)` trap, and the oversized argv is still not echoed back.
    /// (Codex review P3, PR #1.)
    @Test func hardenedNegativeCapDoesNotTrapPreSessionError() async throws {
        let policy = SQLitePolicy(hardened: true, maxResultBytes: -1)
        let huge = "-" + String(repeating: "z", count: 4096)
        let r = try await run([huge, ":memory:"], policy: policy)
        #expect(r.exit == 1)
        #expect(!r.stderr.contains(String(repeating: "z", count: 64)))
    }
}
