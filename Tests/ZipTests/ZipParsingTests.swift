import ArgumentParser
import Foundation
import Testing
@testable import Zip

@Suite struct ZipParsingTests {
    @Test func parsesArchiveAndInputs() throws {
        let cmd = try ZipCommand.parse(["out.zip", "a.txt", "b.txt"])
        #expect(cmd.archive == "out.zip")
        #expect(cmd.inputs == ["a.txt", "b.txt"])
        #expect(cmd.recursive == false)
        #expect(cmd.junkPaths == false)
        #expect(cmd.store == false)
    }

    @Test func parsesRecursiveStoreJunk() throws {
        let cmd = try ZipCommand.parse([
            "out.zip", "src/", "-r", "-j", "-0", "-q",
        ])
        #expect(cmd.recursive)
        #expect(cmd.junkPaths)
        #expect(cmd.store)
        #expect(cmd.quiet)
    }

    @Test func parsesExcludeAndInclude() throws {
        let cmd = try ZipCommand.parse([
            "out.zip", "src/", "-r",
            "-x", "*.tmp", "-x", "*.bak",
            "-i", "*.swift",
        ])
        #expect(cmd.recursive)
        #expect(cmd.inputs == ["src/"])
        #expect(cmd.excludePatterns == ["*.tmp", "*.bak"])
        #expect(cmd.includePatterns == ["*.swift"])
    }
}
