import ArgumentParser
import Foundation
import Testing
@testable import GlabCommand

/// Argv-only parsing tests for the issue + auth surface. No network.
@Suite struct CommandParsingTests {
    @Test func issueListAcceptsRepoFlag() throws {
        let cmd = try IssueList.parse(["--repo", "group/sub/repo"])
        #expect(cmd.repo?.pathSegments == ["group", "sub", "repo"])
    }

    @Test func issueListDefaultsToOpened() throws {
        let cmd = try IssueList.parse([])
        #expect(cmd.all == false)
        #expect(cmd.closed == false)
    }

    @Test func issueListLabelsRepeatable() throws {
        let cmd = try IssueList.parse(["-l", "bug", "-l", "needs-review"])
        #expect(cmd.labels == ["bug", "needs-review"])
    }

    @Test func issueListConfidentialAndJSON() throws {
        let cmd = try IssueList.parse(["-C", "--json"])
        #expect(cmd.confidential == true)
        #expect(cmd.json == true)
    }

    @Test func issueViewAcceptsURLArgument() throws {
        let cmd = try IssueView.parse([
            "https://gitlab.com/foo/bar/-/issues/9",
        ])
        #expect(cmd.issue == "https://gitlab.com/foo/bar/-/issues/9")
    }

    @Test func issueCreateRequiresTitle() {
        #expect(throws: (any Error).self) {
            _ = try IssueCreate.parse([])
        }
    }

    @Test func issueCreateLabelsAndAssignees() throws {
        let cmd = try IssueCreate.parse([
            "--title", "Bug",
            "-l", "ui", "-l", "ux",
            "-a", "alice", "-a", "bob",
        ])
        #expect(cmd.title == "Bug")
        #expect(cmd.labels == ["ui", "ux"])
        #expect(cmd.assignees == ["alice", "bob"])
    }

    @Test func issueUpdateAccepts() throws {
        let cmd = try IssueUpdate.parse([
            "12",
            "--title", "Better title",
            "-l", "needs-review",
            "-u", "bug",
            "-C",
            "--lock-discussion",
        ])
        #expect(cmd.title == "Better title")
        #expect(cmd.addLabels == ["needs-review"])
        #expect(cmd.removeLabels == ["bug"])
        #expect(cmd.confidential == true)
        #expect(cmd.lockDiscussion == true)
    }

    @Test func issueNoteRequiresMessage() {
        #expect(throws: (any Error).self) {
            _ = try IssueNote.parse(["1"])
        }
    }

    @Test func issueNoteAccepts() throws {
        let cmd = try IssueNote.parse(["1", "-m", "looking into it"])
        #expect(cmd.issue == "1")
        #expect(cmd.message == "looking into it")
    }

    @Test func issueCloseAccepts() throws {
        let cmd = try IssueClose.parse(["#42"])
        #expect(cmd.issue == "#42")
    }

    @Test func issueDeleteAccepts() throws {
        let cmd = try IssueDelete.parse(["7"])
        #expect(cmd.issue == "7")
    }

    @Test func authStatusHostnameOptional() throws {
        let withFlag = try AuthStatus.parse(["-h", "self.example.com"])
        #expect(withFlag.hostname == "self.example.com")
        let bare = try AuthStatus.parse([])
        #expect(bare.hostname == nil)
    }

    @Test func authLoginWithTokenFlag() throws {
        let cmd = try AuthLogin.parse(["--with-token"])
        #expect(cmd.withToken == true)
    }
}
