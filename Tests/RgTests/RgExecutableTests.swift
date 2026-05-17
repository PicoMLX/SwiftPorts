import Foundation
import ShellKit
import Testing
@testable import RgCommand
@testable import RipgrepKit

@Suite struct RgExecutableTests {

    /// Run the executable inside a fresh `Shell` bound to a temp
    /// working directory. Captures stdout/stderr.
    private func run(_ argv: [String],
                     in tree: [String: String] = [:],
                     stdin input: String = "")
    async throws -> (stdout: String, stderr: String, exit: Int32, root: URL) {
        let root = try makeTree(tree)
        let env = Environment(
            variables: ProcessInfo.processInfo.environment,
            workingDirectory: root.path)
        var shell = Shell(environment: env)
        shell.stdin = .string(input)
        let stdoutSink = OutputSink()
        let stderrSink = OutputSink()
        shell.stdout = stdoutSink
        shell.stderr = stderrSink
        let exit = try await Shell.$current.withValue(shell) {
            try await RgExecutable.run(
                argv: argv,
                stdin: shell.stdin,
                stdout: stdoutSink,
                stderr: stderrSink)
        }
        stdoutSink.finish()
        stderrSink.finish()
        let outString = await stdoutSink.readAllString()
        let errString = await stderrSink.readAllString()
        return (outString, errString, exit, root)
    }

    private func makeTree(_ tree: [String: String]) throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("rg-cli-\(UUID().uuidString)",
                                    isDirectory: true)
        try FileManager.default.createDirectory(at: root,
                                                withIntermediateDirectories: true)
        for (path, content) in tree {
            let url = root.appendingPathComponent(path)
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true)
            try Data(content.utf8).write(to: url)
        }
        return root
    }

    @Test func matchesPlainPattern() async throws {
        let r = try await run(["beta", "."], in: [
            "a.txt": "alpha\nbeta\ngamma\n",
        ])
        defer { try? FileManager.default.removeItem(at: r.root) }
        #expect(r.exit == 0)
        #expect(r.stdout.contains("beta"))
        #expect(r.stdout.contains("a.txt"))
    }

    @Test func exit1OnNoMatch() async throws {
        let r = try await run(["nothere", "."], in: [
            "a.txt": "alpha\n",
        ])
        defer { try? FileManager.default.removeItem(at: r.root) }
        #expect(r.exit == 1)
    }

    @Test func ignoreCase() async throws {
        let r = try await run(["-i", "BETA", "."], in: [
            "a.txt": "beta line\n",
        ])
        defer { try? FileManager.default.removeItem(at: r.root) }
        #expect(r.exit == 0)
        #expect(r.stdout.contains("beta line"))
    }

    @Test func fixedStringsEscape() async throws {
        let r = try await run(["-F", "a.c", "."], in: [
            "x.txt": "a.c\nabc\n",
        ])
        defer { try? FileManager.default.removeItem(at: r.root) }
        #expect(r.exit == 0)
        // 'abc' shouldn't appear in output — only the literal 'a.c'.
        #expect(r.stdout.contains("a.c"))
        #expect(!r.stdout.contains("abc"))
    }

    @Test func lineNumberShortForm() async throws {
        let r = try await run(["-n", "beta", "."], in: [
            "x.txt": "alpha\nbeta\ngamma\n",
        ])
        defer { try? FileManager.default.removeItem(at: r.root) }
        #expect(r.stdout.contains(":2:"))
    }

    @Test func globIncludesOnlyMatchingFiles() async throws {
        let r = try await run(["-g", "*.txt", "beta", "."], in: [
            "a.txt": "beta\n",
            "b.md":  "beta\n",
        ])
        defer { try? FileManager.default.removeItem(at: r.root) }
        #expect(r.stdout.contains("a.txt"))
        #expect(!r.stdout.contains("b.md"))
    }

    @Test func gitignoreRespectedByDefault() async throws {
        let r = try await run(["beta", "."], in: [
            ".gitignore": "*.log\n",
            "a.log":      "beta\n",
            "a.txt":      "beta\n",
        ])
        defer { try? FileManager.default.removeItem(at: r.root) }
        #expect(r.stdout.contains("a.txt"))
        #expect(!r.stdout.contains("a.log"))
    }

    @Test func noIgnoreOverridesGitignore() async throws {
        let r = try await run(["--no-ignore", "beta", "."], in: [
            ".gitignore": "*.log\n",
            "a.log":      "beta\n",
        ])
        defer { try? FileManager.default.removeItem(at: r.root) }
        #expect(r.stdout.contains("a.log"))
    }

    @Test func hiddenFlag() async throws {
        let r = try await run(["--hidden", "secret", "."], in: [
            ".hidden": "secret\n",
        ])
        defer { try? FileManager.default.removeItem(at: r.root) }
        #expect(r.stdout.contains(".hidden"))
    }

    @Test func countMode() async throws {
        let r = try await run(["-c", "x", "."], in: [
            "a.txt": "x\nx\ny\n",
        ])
        defer { try? FileManager.default.removeItem(at: r.root) }
        #expect(r.stdout.contains("a.txt:2"))
    }

    @Test func filesWithMatchesMode() async throws {
        let r = try await run(["-l", "x", "."], in: [
            "a.txt": "x\n",
            "b.txt": "y\n",
        ])
        defer { try? FileManager.default.removeItem(at: r.root) }
        #expect(r.stdout.contains("a.txt"))
        #expect(!r.stdout.contains("b.txt"))
    }

    @Test func contextLines() async throws {
        let r = try await run(["-C1", "beta", "."], in: [
            "a.txt": "alpha\nbeta\ngamma\n",
        ])
        defer { try? FileManager.default.removeItem(at: r.root) }
        #expect(r.stdout.contains("alpha"))
        #expect(r.stdout.contains("beta"))
        #expect(r.stdout.contains("gamma"))
    }

    @Test func jsonModeEmitsValidJSONLines() async throws {
        let r = try await run(["--json", "beta", "."], in: [
            "a.txt": "beta line\n",
        ])
        defer { try? FileManager.default.removeItem(at: r.root) }
        #expect(r.exit == 0)
        let lines = r.stdout
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map(String.init)
        #expect(!lines.isEmpty)
        // Every line should decode as a JSON object.
        for line in lines {
            let data = Data(line.utf8)
            _ = try JSONSerialization.jsonObject(with: data)
        }
        // First event is "begin", last is "summary".
        let firstObj = try JSONSerialization.jsonObject(
            with: Data(lines[0].utf8)) as? [String: Any]
        #expect(firstObj?["type"] as? String == "begin")
        let lastObj = try JSONSerialization.jsonObject(
            with: Data(lines.last!.utf8)) as? [String: Any]
        #expect(lastObj?["type"] as? String == "summary")
    }

    @Test func stdinSearch() async throws {
        let r = try await run(["beta"], stdin: "alpha\nbeta\ngamma\n")
        defer { try? FileManager.default.removeItem(at: r.root) }
        #expect(r.exit == 0)
        #expect(r.stdout.contains("beta"))
    }

    @Test func filesMode() async throws {
        let r = try await run(["--files", "."], in: [
            "a.txt": "x",
            "sub/b.txt": "y",
        ])
        defer { try? FileManager.default.removeItem(at: r.root) }
        #expect(r.stdout.contains("a.txt"))
        #expect(r.stdout.contains("sub/b.txt"))
    }

    @Test func typeListPrintsKnownType() async throws {
        let r = try await run(["--type-list"])
        defer { try? FileManager.default.removeItem(at: r.root) }
        #expect(r.stdout.contains("swift: *.swift"))
    }

    @Test func quietExitOnlyNoOutput() async throws {
        let r = try await run(["-q", "beta", "."], in: [
            "a.txt": "beta\n",
        ])
        defer { try? FileManager.default.removeItem(at: r.root) }
        #expect(r.exit == 0)
        #expect(r.stdout.isEmpty)
    }

    @Test func parsesRgViaArgumentParser() throws {
        let cmd = try Rg.parse(["-i", "pat", "."])
        #expect(cmd.rawArgv == ["-i", "pat", "."])
    }
}
