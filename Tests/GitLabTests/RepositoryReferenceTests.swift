import Foundation
import Testing
@testable import GitLab

@Suite struct RepositoryReferenceTests {
    @Test func parsesOwnerRepo() throws {
        let ref = try RepositoryReference(parsing: "gitlab-org/cli")
        #expect(ref.host == nil)
        #expect(ref.pathSegments == ["gitlab-org", "cli"])
        #expect(ref.fullPath == "gitlab-org/cli")
        #expect(ref.namespace == "gitlab-org")
        #expect(ref.name == "cli")
    }

    @Test func parsesGroupSubgroupRepo() throws {
        let ref = try RepositoryReference(parsing: "group/sub/project")
        #expect(ref.host == nil)
        #expect(ref.pathSegments == ["group", "sub", "project"])
        #expect(ref.namespace == "group/sub")
        #expect(ref.topLevelGroup == "group")
        #expect(ref.name == "project")
    }

    @Test func parsesHostPrefix() throws {
        let ref = try RepositoryReference(parsing: "gitlab.com/group/sub/repo")
        #expect(ref.host == "gitlab.com")
        #expect(ref.pathSegments == ["group", "sub", "repo"])
    }

    @Test func emptyRejected() {
        #expect(throws: RepositoryReferenceParseError.self) {
            _ = try RepositoryReference(parsing: "")
        }
    }

    @Test func singleSegmentRejected() {
        #expect(throws: RepositoryReferenceParseError.self) {
            _ = try RepositoryReference(parsing: "owner")
        }
    }

    @Test func encodedPathPercentEncodesSlash() throws {
        let ref = try RepositoryReference(parsing: "group/sub/repo")
        #expect(ref.encodedPath == "group%2Fsub%2Frepo")
    }

    @Test func encodedPathPreservesSafeChars() throws {
        let ref = try RepositoryReference(parsing: "gitlab-org/cli")
        #expect(ref.encodedPath == "gitlab-org%2Fcli")
    }

    @Test func parsesHTTPSRemoteURL() throws {
        let url = URL(string: "https://gitlab.com/group/sub/repo.git")!
        let ref = try #require(RepositoryReference(parsingRemoteURL: url))
        #expect(ref.host == "gitlab.com")
        #expect(ref.pathSegments == ["group", "sub", "repo"])
    }

    @Test func parsesSCPStyleSSHURL() throws {
        let url = URL(string: "git@gitlab.com:group/sub/repo.git")!
        let ref = try #require(RepositoryReference(parsingRemoteURL: url))
        #expect(ref.host == "gitlab.com")
        #expect(ref.pathSegments == ["group", "sub", "repo"])
    }
}
