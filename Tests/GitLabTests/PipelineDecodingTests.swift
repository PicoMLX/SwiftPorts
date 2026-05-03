import Foundation
import Testing
@testable import GitLab

@Suite struct PipelineDecodingTests {
    @Test func decodesPipeline() throws {
        let json = """
        {
          "id": 9876,
          "iid": 12,
          "project_id": 7,
          "sha": "deadbeefcafebabe1234567890",
          "ref": "main",
          "status": "running",
          "source": "push",
          "web_url": "https://gitlab.com/group/repo/-/pipelines/9876",
          "created_at": "2024-09-01T12:00:00.000Z",
          "updated_at": "2024-09-01T12:01:00.000Z",
          "started_at": "2024-09-01T12:00:30.000Z",
          "finished_at": null,
          "committed_at": null,
          "duration": null,
          "queued_duration": 4.5,
          "user": {
            "id": 100,
            "username": "alice",
            "name": "Alice",
            "state": "active",
            "avatar_url": null,
            "web_url": "https://gitlab.com/alice"
          }
        }
        """.data(using: .utf8)!

        let p = try JSONDecoder.gitLab().decode(Pipeline.self, from: json)
        #expect(p.id == 9876)
        #expect(p.status == .running)
        #expect(p.ref == "main")
        #expect(p.source == "push")
        #expect(p.user?.username == "alice")
        #expect(p.queuedDuration == 4.5)
        #expect(p.status.isInProgress == true)
        #expect(p.status.isTerminal == false)
    }

    @Test func decodesUnknownStatusGracefully() throws {
        let json = """
        {
          "id": 1, "project_id": 1, "sha": "abc",
          "status": "some_future_status", "ref": "main",
          "web_url": "https://gitlab.com/x/y/-/pipelines/1"
        }
        """.data(using: .utf8)!
        let p = try JSONDecoder.gitLab().decode(Pipeline.self, from: json)
        #expect(p.status == .unknown("some_future_status"))
        #expect(p.status.isTerminal == false)
        #expect(p.status.isInProgress == false)
    }

    @Test func statusIsTerminalForFinishedStates() {
        #expect(PipelineStatus.success.isTerminal)
        #expect(PipelineStatus.failed.isTerminal)
        #expect(PipelineStatus.canceled.isTerminal)
        #expect(PipelineStatus.skipped.isTerminal)
        #expect(PipelineStatus.manual.isTerminal)
        #expect(!PipelineStatus.running.isTerminal)
        #expect(!PipelineStatus.pending.isTerminal)
    }
}

@Suite struct JobDecodingTests {
    @Test func decodesJob() throws {
        let json = """
        {
          "id": 222,
          "name": "rspec",
          "stage": "test",
          "status": "success",
          "ref": "main",
          "tag": false,
          "allow_failure": false,
          "created_at": "2024-09-01T12:00:00.000Z",
          "started_at": "2024-09-01T12:00:30.000Z",
          "finished_at": "2024-09-01T12:05:00.000Z",
          "erased_at": null,
          "duration": 270.5,
          "queued_duration": 4.5,
          "coverage": 92.3,
          "web_url": "https://gitlab.com/group/repo/-/jobs/222",
          "failure_reason": null,
          "user": {
            "id": 100, "username": "alice", "name": "Alice",
            "state": "active", "avatar_url": null, "web_url": "https://gitlab.com/alice"
          },
          "pipeline": {
            "id": 9876, "project_id": 7, "ref": "main", "sha": "deadbeef",
            "status": "running", "web_url": "https://gitlab.com/group/repo/-/pipelines/9876"
          },
          "runner": {
            "id": 1, "description": "shared-1", "active": true, "is_shared": true,
            "runner_type": "instance_type", "name": "shared", "online": true, "status": "online"
          }
        }
        """.data(using: .utf8)!
        let j = try JSONDecoder.gitLab().decode(Job.self, from: json)
        #expect(j.id == 222)
        #expect(j.name == "rspec")
        #expect(j.stage == "test")
        #expect(j.status == .success)
        #expect(j.duration == 270.5)
        #expect(j.coverage == 92.3)
        #expect(j.pipeline?.id == 9876)
        #expect(j.runner?.id == 1)
    }
}
