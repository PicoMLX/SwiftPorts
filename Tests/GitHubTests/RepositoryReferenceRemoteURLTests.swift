import Foundation
import Testing
@testable import GitHub

@Suite struct RepositoryReferenceRemoteURLTests {
    @Test func parsesHTTPSURLWithGitSuffix() throws {
        let ref = try #require(
            RepositoryReference(parsingRemoteURL: URL(string: "https://github.com/cli/cli.git")!))
        #expect(ref.owner == "cli")
        #expect(ref.name == "cli")
    }

    @Test func parsesHTTPSURLWithoutGitSuffix() throws {
        let ref = try #require(
            RepositoryReference(parsingRemoteURL: URL(string: "https://github.com/Cocoanetics/SwiftPorts")!))
        #expect(ref.owner == "Cocoanetics")
        #expect(ref.name == "SwiftPorts")
    }

    @Test func parsesSCPStyleSSH() throws {
        let ref = try #require(
            RepositoryReference(parsingRemoteURL: URL(string: "git@github.com:cli/cli.git")!))
        #expect(ref.owner == "cli")
        #expect(ref.name == "cli")
    }

    @Test func parsesSSHURL() throws {
        let ref = try #require(
            RepositoryReference(parsingRemoteURL: URL(string: "ssh://git@github.com/cli/cli.git")!))
        #expect(ref.owner == "cli")
        #expect(ref.name == "cli")
    }

    @Test func parsesGitProtocol() throws {
        let ref = try #require(
            RepositoryReference(parsingRemoteURL: URL(string: "git://github.com/cli/cli.git")!))
        #expect(ref.owner == "cli")
        #expect(ref.name == "cli")
    }

    @Test func returnsNilForUnsupportedShape() {
        // Local path
        #expect(RepositoryReference(parsingRemoteURL: URL(string: "file:///tmp/repo")!) == nil)
        // Multi-segment path doesn't fit OWNER/NAME
        #expect(RepositoryReference(parsingRemoteURL: URL(string: "https://example.com/a/b/c")!) == nil)
    }
}
