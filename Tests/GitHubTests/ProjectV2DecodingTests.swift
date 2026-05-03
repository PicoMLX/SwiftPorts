import Foundation
import Testing
@testable import GitHub

@Suite struct ProjectV2DecodingTests {
    @Test func decodesViewerProjectsResponse() throws {
        let json = #"""
            {
              "viewer": {
                "projectsV2": {
                  "totalCount": 2,
                  "nodes": [
                    {"id":"P1","number":1,"title":"My Roadmap","shortDescription":null,"url":"https://github.com/users/me/projects/1","closed":false,"public":true,"readme":null,"createdAt":"2024-01-01T00:00:00Z","updatedAt":"2024-02-01T00:00:00Z"},
                    {"id":"P2","number":2,"title":"Side Quests","shortDescription":"misc","url":"https://github.com/users/me/projects/2","closed":true,"public":false,"readme":"hello","createdAt":"2024-01-02T00:00:00Z","updatedAt":"2024-02-02T00:00:00Z"}
                  ]
                }
              }
            }
            """#
        let response = try JSONDecoder.gitHub().decode(
            ViewerProjectsResponse.self, from: Data(json.utf8))
        let nodes = response.viewer.projectsV2.nodes
        #expect(nodes.count == 2)
        #expect(nodes[0].title == "My Roadmap")
        #expect(nodes[0].public == true)
        #expect(nodes[0].closed == false)
        #expect(nodes[1].closed == true)
        #expect(nodes[1].readme == "hello")
    }

    @Test func decodesProjectItemContentVariants() throws {
        let json = #"""
            {
              "viewer": {
                "projectV2": {
                  "items": {
                    "totalCount": 3,
                    "nodes": [
                      {"id":"I1","type":"ISSUE","createdAt":"2024-01-01T00:00:00Z","updatedAt":"2024-01-01T00:00:00Z",
                       "content":{"__typename":"Issue","number":42,"title":"bug","state":"OPEN","url":"https://github.com/x/y/issues/42"}},
                      {"id":"I2","type":"PULL_REQUEST","createdAt":"2024-01-01T00:00:00Z","updatedAt":"2024-01-01T00:00:00Z",
                       "content":{"__typename":"PullRequest","number":99,"title":"feature","state":"MERGED","url":"https://github.com/x/y/pull/99"}},
                      {"id":"I3","type":"DRAFT_ISSUE","createdAt":"2024-01-01T00:00:00Z","updatedAt":"2024-01-01T00:00:00Z",
                       "content":{"__typename":"DraftIssue","title":"think about this","body":"…"}}
                    ]
                  }
                }
              }
            }
            """#
        let response = try JSONDecoder.gitHub().decode(
            ViewerProjectItemsResponse.self, from: Data(json.utf8))
        let nodes = try #require(response.viewer.projectV2?.items.nodes)
        #expect(nodes.count == 3)

        guard case let .issue(issue) = nodes[0].content else {
            Issue.record("expected .issue case")
            return
        }
        #expect(issue.number == 42)
        #expect(issue.state == "OPEN")

        guard case let .pullRequest(pr) = nodes[1].content else {
            Issue.record("expected .pullRequest case")
            return
        }
        #expect(pr.number == 99)
        #expect(pr.state == "MERGED")

        guard case let .draftIssue(draft) = nodes[2].content else {
            Issue.record("expected .draftIssue case")
            return
        }
        #expect(draft.title == "think about this")
    }

    @Test func unknownContentTypeMapsToUnknown() throws {
        let json = #"""
            {"id":"X","type":"REDACTED","createdAt":"2024-01-01T00:00:00Z","updatedAt":"2024-01-01T00:00:00Z",
             "content":{"__typename":"SomeFutureType"}}
            """#
        let item = try JSONDecoder.gitHub().decode(
            ProjectV2Item.self, from: Data(json.utf8))
        if case .unknown = item.content {
            // expected
        } else {
            Issue.record("expected .unknown content")
        }
    }
}
