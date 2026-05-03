import Foundation
import GitHub

/// Per-process defaults for command runtime: a shared resolver, the
/// default secret store, etc. Centralised here so individual
/// subcommands have one line of boilerplate.
enum CommandContext {
    static let resolver = ConfigurationResolver()

    static func resolveConfig(host: String? = nil) async throws -> Configuration {
        try await resolver.resolve(host: host)
    }

    static func apiClient(host: String? = nil) async throws -> APIClient {
        let config = try await resolveConfig(host: host)
        return APIClient(configuration: config)
    }

    static func graphQLClient(host: String? = nil) async throws -> GraphQLClient {
        let config = try await resolveConfig(host: host)
        return GraphQLClient(configuration: config)
    }
}
