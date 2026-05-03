import Foundation
import Testing
@testable import GitLab

@Suite struct ReleaseDecodingTests {
    @Test func decodesRelease() throws {
        let json = """
        {
          "tag_name": "v1.2.3",
          "name": "Release 1.2.3",
          "description": "## What's new\\n- bugfix",
          "created_at": "2024-09-01T12:00:00.000Z",
          "released_at": "2024-09-01T12:30:00.000Z",
          "author": {
            "id": 7, "username": "alice", "name": "Alice",
            "state": "active", "avatar_url": null,
            "web_url": "https://gitlab.com/alice"
          },
          "assets": {
            "count": 2,
            "sources": [
              { "format": "zip",    "url": "https://gitlab.com/g/r/-/archive/v1.2.3/r-v1.2.3.zip" },
              { "format": "tar.gz", "url": "https://gitlab.com/g/r/-/archive/v1.2.3/r-v1.2.3.tar.gz" }
            ],
            "links": [
              { "id": 1, "name": "binary", "url": "https://example.com/b.zip", "link_type": "package" }
            ]
          },
          "_links": {
            "self": "https://gitlab.com/g/r/-/releases/v1.2.3"
          }
        }
        """.data(using: .utf8)!
        let r = try JSONDecoder.gitLab().decode(Release.self, from: json)
        #expect(r.tagName == "v1.2.3")
        #expect(r.name == "Release 1.2.3")
        #expect(r.author?.username == "alice")
        #expect(r.assets?.count == 2)
        #expect(r.assets?.sources?.count == 2)
        #expect(r.assets?.links?.first?.linkType == "package")
        #expect(r._links?.selfLink?.absoluteString == "https://gitlab.com/g/r/-/releases/v1.2.3")
    }

    @Test func decodesMinimalRelease() throws {
        let json = """
        {
          "tag_name": "v0.0.1",
          "created_at": "2024-09-01T12:00:00.000Z"
        }
        """.data(using: .utf8)!
        let r = try JSONDecoder.gitLab().decode(Release.self, from: json)
        #expect(r.tagName == "v0.0.1")
        #expect(r.name == nil)
        #expect(r.releasedAt == nil)
        #expect(r.assets == nil)
    }
}

@Suite struct TagDecodingTests {
    @Test func decodesAnnotatedTag() throws {
        let json = """
        {
          "name": "v1.0.0",
          "message": "first stable release",
          "target": "9b4a3c2d1e",
          "commit": {
            "id": "1234567890abcdef",
            "short_id": "12345678",
            "title": "Bump version",
            "created_at": "2024-09-01T12:00:00.000Z"
          }
        }
        """.data(using: .utf8)!
        let t = try JSONDecoder.gitLab().decode(GitLab.Tag.self, from: json)
        #expect(t.name == "v1.0.0")
        #expect(t.message == "first stable release")
        #expect(t.target == "9b4a3c2d1e")
        #expect(t.commit?.id == "1234567890abcdef")
        #expect(t.commit?.shortId == "12345678")
    }

    @Test func decodesLightweightTag() throws {
        let json = """
        {
          "name": "v0.1.0",
          "message": null,
          "target": null,
          "commit": {
            "id": "abc",
            "short_id": "abc",
            "title": "init",
            "created_at": "2024-09-01T12:00:00.000Z"
          }
        }
        """.data(using: .utf8)!
        let t = try JSONDecoder.gitLab().decode(GitLab.Tag.self, from: json)
        #expect(t.name == "v0.1.0")
        #expect(t.message == nil)
        #expect(t.target == nil)
    }
}

@Suite struct VariableDecodingTests {
    @Test func decodesVariable() throws {
        let json = """
        {
          "key": "API_TOKEN",
          "value": "supersecret",
          "variable_type": "env_var",
          "protected": true,
          "masked": true,
          "raw": false,
          "environment_scope": "*"
        }
        """.data(using: .utf8)!
        let v = try JSONDecoder.gitLab().decode(Variable.self, from: json)
        #expect(v.key == "API_TOKEN")
        #expect(v.value == "supersecret")
        #expect(v.variableType == "env_var")
        #expect(v.protected == true)
        #expect(v.masked == true)
        #expect(v.environmentScope == "*")
    }

    @Test func decodesMinimalVariable() throws {
        let json = """
        { "key": "X", "value": "y" }
        """.data(using: .utf8)!
        let v = try JSONDecoder.gitLab().decode(Variable.self, from: json)
        #expect(v.key == "X")
        #expect(v.value == "y")
        #expect(v.protected == nil)
        #expect(v.masked == nil)
    }
}

@Suite struct LabelDecodingTests {
    @Test func decodesProjectLabel() throws {
        let json = """
        {
          "id": 11,
          "name": "bug",
          "description": "Something broken",
          "color": "#FF0000",
          "text_color": "#FFFFFF",
          "priority": null,
          "is_project_label": true
        }
        """.data(using: .utf8)!
        let l = try JSONDecoder.gitLab().decode(Label.self, from: json)
        #expect(l.id == 11)
        #expect(l.name == "bug")
        #expect(l.color == "#FF0000")
        #expect(l.textColor == "#FFFFFF")
        #expect(l.isProjectLabel == true)
    }

    @Test func decodesGroupLabel() throws {
        let json = """
        {
          "id": 99,
          "name": "blocker",
          "color": "#000000",
          "is_project_label": false
        }
        """.data(using: .utf8)!
        let l = try JSONDecoder.gitLab().decode(Label.self, from: json)
        #expect(l.id == 99)
        #expect(l.isProjectLabel == false)
        #expect(l.description == nil)
    }
}
