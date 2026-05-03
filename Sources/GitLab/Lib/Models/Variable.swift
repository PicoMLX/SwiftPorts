import Foundation

/// One project-scoped CI/CD variable. GitLab also exposes group +
/// instance scopes; for the glab subset we focus on the project scope
/// since that's the most-needed.
public struct Variable: Codable, Sendable, Equatable {
    public let key: String
    public let value: String
    public let variableType: String?  // env_var | file
    public let `protected`: Bool?
    public let masked: Bool?
    public let raw: Bool?
    public let environmentScope: String?
}
