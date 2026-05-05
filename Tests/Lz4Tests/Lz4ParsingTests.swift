#if canImport(Compression) || os(Linux) || os(Windows)
import Foundation
import Testing
@testable import Lz4Command

@Suite struct Lz4ParsingTests {
    @Test func lz4ParsesCommonFlags() throws {
        let cmd = try Lz4.parse(["-9", "-k", "-c", "file.txt"])
        #expect(cmd.level9)
        #expect(cmd.keep)
        #expect(cmd.stdout)
        #expect(!cmd.decompress)
        #expect(cmd.files == ["file.txt"])
    }

    @Test func lz4DecompressFlag() throws {
        let cmd = try Lz4.parse(["-d", "data.lz4"])
        #expect(cmd.decompress)
        #expect(cmd.files == ["data.lz4"])
    }

    @Test func unlz4DefaultsToDecompress() throws {
        let cmd = try Unlz4.parse(["-c", "data.lz4"])
        #expect(cmd.stdout)
        #expect(cmd.files == ["data.lz4"])
    }

    @Test func lz4catParsesFiles() throws {
        let cmd = try Lz4cat.parse(["a.lz4", "b.lz4"])
        #expect(cmd.files == ["a.lz4", "b.lz4"])
    }

    @Test func lz4AcceptsStdinSentinel() throws {
        let cmd = try Lz4.parse(["-c", "-"])
        #expect(cmd.files == ["-"])
    }
}
#endif
