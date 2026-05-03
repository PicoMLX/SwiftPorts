import Foundation
import Testing
@testable import SwiftGHCore

@Suite struct ConfigFileTests {
    private func tempPath() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("swiftgh-config-\(UUID().uuidString).yml")
    }

    @Test func roundTripsScalarKeys() throws {
        let path = tempPath()
        defer { try? FileManager.default.removeItem(at: path) }
        let store = ConfigFileStore(path: path)

        var file = ConfigFile()
        file["git_protocol"] = "https"
        file["editor"] = "vim"
        file["pager"] = "less"
        try store.write(file)

        let loaded = try store.read()
        #expect(loaded["git_protocol"] == "https")
        #expect(loaded["editor"] == "vim")
        #expect(loaded["pager"] == "less")
    }

    @Test func emptyOnFirstRead() throws {
        let store = ConfigFileStore(path: tempPath())
        let file = try store.read()
        #expect(file.values.isEmpty)
    }

    @Test func interopWithUpstreamGhConfigShape() throws {
        // Mirror upstream gh's actual config.yml shape — top-level
        // scalar keys.
        let path = tempPath()
        defer { try? FileManager.default.removeItem(at: path) }
        try """
            git_protocol: ssh
            editor: code
            prompt: enabled
            """.write(to: path, atomically: true, encoding: .utf8)

        let store = ConfigFileStore(path: path)
        let file = try store.read()
        #expect(file["git_protocol"] == "ssh")
        #expect(file["editor"] == "code")
        #expect(file["prompt"] == "enabled")
    }
}

@Suite struct HostsFileTests {
    private func tempPath() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("swiftgh-hosts-\(UUID().uuidString).yml")
    }

    @Test func decodesUpstreamShape() throws {
        let path = tempPath()
        defer { try? FileManager.default.removeItem(at: path) }
        try """
            github.com:
                user: octocat
                git_protocol: https
                oauth_token: ghp_xxx
            ghe.example.com:
                user: alice
                git_protocol: ssh
            """.write(to: path, atomically: true, encoding: .utf8)

        let store = HostsFileStore(path: path)
        let file = try store.read()
        #expect(file["github.com"]?.user == "octocat")
        #expect(file["github.com"]?.gitProtocol == "https")
        #expect(file["github.com"]?.oauthToken == "ghp_xxx")
        #expect(file["ghe.example.com"]?.user == "alice")
        #expect(file["ghe.example.com"]?.oauthToken == nil)
    }

    @Test func writeAndReadBack() throws {
        let path = tempPath()
        defer { try? FileManager.default.removeItem(at: path) }
        let store = HostsFileStore(path: path)

        var file = HostsFile()
        file["github.com"] = HostEntry(
            user: "test", gitProtocol: "https", oauthToken: nil)
        try store.write(file)

        let loaded = try store.read()
        #expect(loaded["github.com"]?.user == "test")
        #expect(loaded["github.com"]?.gitProtocol == "https")
    }

    @Test func emptyOnMissingFile() throws {
        let store = HostsFileStore(path: tempPath())
        let file = try store.read()
        #expect(file.hosts.isEmpty)
    }

    @Test func tokenSourceDetectsHostsFile() {
        let source = TokenSource.detect(
            env: [:], configToken: "from-hosts-file", hostsToken: "from-hosts-file")
        #expect(source == .hostsFile)
    }

    @Test func tokenSourceStillDetectsKeychainWhenHostsTokenMissing() {
        let source = TokenSource.detect(
            env: [:], configToken: "from-keychain", hostsToken: nil)
        #expect(source == .secretStore)
    }
}
