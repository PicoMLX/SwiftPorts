import Foundation
import Testing
@testable import GitLab

@Suite struct IssueDecodingTests {
    @Test func decodesIssue() throws {
        let json = """
        {
          "id": 1,
          "iid": 11,
          "project_id": 7,
          "title": "Fix the thing",
          "description": "Steps to reproduce…",
          "state": "opened",
          "confidential": false,
          "labels": ["bug", "needs-review"],
          "milestone": null,
          "author": {
            "id": 100,
            "username": "alice",
            "name": "Alice Example",
            "state": "active",
            "avatar_url": null,
            "web_url": "https://gitlab.com/alice"
          },
          "assignees": [],
          "assignee": null,
          "user_notes_count": 4,
          "upvotes": 1,
          "downvotes": 0,
          "created_at": "2024-09-01T12:00:00.000Z",
          "updated_at": "2024-09-02T15:30:00.000Z",
          "closed_at": null,
          "due_date": null,
          "web_url": "https://gitlab.com/group/repo/-/issues/11",
          "issue_type": "issue",
          "has_tasks": false,
          "task_status": null
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder.gitLab()
        let issue = try decoder.decode(Issue.self, from: json)
        #expect(issue.iid == 11)
        #expect(issue.state == .opened)
        #expect(issue.labels == ["bug", "needs-review"])
        #expect(issue.author?.username == "alice")
        #expect(issue.webUrl.absoluteString == "https://gitlab.com/group/repo/-/issues/11")
    }
}
