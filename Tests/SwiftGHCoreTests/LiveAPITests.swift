import Foundation
import Testing
@testable import SwiftGHCore

/// Opt-in: hits real `api.github.com` unauthenticated.
///
/// Excluded by default (rate-limit safety). Run with:
///
///     SWIFTGH_LIVE=1 swift test
///
/// or filter by tag:
///
///     swift test --filter "Live"
@Suite(
    .tags(.live),
    .disabled(if: ProcessInfo.processInfo.environment["SWIFTGH_LIVE"] == nil,
              "Set SWIFTGH_LIVE=1 to run live tests against api.github.com.")
)
struct LiveAPITests {
    @Test func fetchesOctocatHelloWorld() async throws {
        let client = APIClient()
        let repo: Repository = try await client.get("repos/octocat/Hello-World")
        #expect(repo.fullName == "octocat/Hello-World")
        #expect(repo.owner.login == "octocat")
    }

    @Test func fetchesCliCliLatestRelease() async throws {
        let client = APIClient()
        let release: Release = try await client.get("repos/cli/cli/releases/latest")
        #expect(release.tagName.hasPrefix("v"))
        #expect(!release.assets.isEmpty)
    }

    @Test func searchesRepos() async throws {
        let client = APIClient()
        let result: SearchResult<Repository> = try await client.get(
            "search/repositories",
            query: [
                URLQueryItem(name: "q", value: "swift cli"),
                URLQueryItem(name: "per_page", value: "3"),
            ])
        #expect(result.totalCount > 0)
        #expect(!result.items.isEmpty)
    }

    /// Requires a token (so requires an authenticated env: SWIFTGH_LIVE
    /// with GH_TOKEN/GITHUB_TOKEN). Hits the GraphQL endpoint with a
    /// trivial viewer{} query.
    @Test func graphQLViewer() async throws {
        let config = Configuration.live()
        guard config.token != nil else {
            // Soft-skip: GraphQL endpoint requires auth.
            print("[skip] no token in env; can't probe GraphQL viewer{}")
            return
        }
        let client = GraphQLClient(configuration: config)
        let result: ViewerQuery = try await client.query(ViewerQuery.query)
        #expect(!result.viewer.login.isEmpty)
        print("[live] graphQL viewer login: \(result.viewer.login)")
    }
}

extension Tag {
    @Tag static var live: Self
}
