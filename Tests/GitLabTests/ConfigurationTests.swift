import Foundation
import Testing
@testable import GitLab

@Suite struct ConfigurationTests {
    @Test func defaultsToGitlabCom() {
        let config = Configuration.fromEnvironment([:])
        #expect(config.host == "gitlab.com")
        #expect(config.token == nil)
        #expect(config.apiRoot.absoluteString == "https://gitlab.com/api/v4/")
    }

    @Test func picksUpGitlabToken() {
        let config = Configuration.fromEnvironment([
            "GITLAB_TOKEN": "abc",
        ])
        #expect(config.token == "abc")
    }

    @Test func gitlabAccessTokenFallback() {
        let config = Configuration.fromEnvironment([
            "GITLAB_ACCESS_TOKEN": "secondary",
        ])
        #expect(config.token == "secondary")
    }

    @Test func oauthTokenFallback() {
        let config = Configuration.fromEnvironment([
            "OAUTH_TOKEN": "oauthy",
        ])
        #expect(config.token == "oauthy")
    }

    @Test func gitlabHostBeatsAlternates() {
        let config = Configuration.fromEnvironment([
            "GITLAB_HOST": "self.example.com",
            "GL_HOST": "ignored.example.com",
        ])
        #expect(config.host == "self.example.com")
    }

    @Test func glHostFallback() {
        let config = Configuration.fromEnvironment(["GL_HOST": "fallback.example.com"])
        #expect(config.host == "fallback.example.com")
    }

    @Test func stripsSchemeFromHost() {
        let config = Configuration.fromEnvironment([
            "GITLAB_HOST": "https://self-hosted.example.com",
        ])
        #expect(config.host == "self-hosted.example.com")
        #expect(config.apiRoot.absoluteString == "https://self-hosted.example.com/api/v4/")
    }
}
