import Foundation
import GitLab

/// Per-process defaults for command runtime: a shared resolver, the
/// default secret store. Centralised so individual subcommands have
/// one line of boilerplate.
enum CommandContext {
    static let resolver = ConfigurationResolver()

    static func resolveConfig(host: String? = nil) async throws -> Configuration {
        try await resolver.resolve(host: host)
    }

    static func apiClient(host: String? = nil) async throws -> APIClient {
        let config = try await resolveConfig(host: host)
        return APIClient(configuration: config)
    }
}
