import Foundation

extension GraphQLError: LocalizedError {
    public var errorDescription: String? {
        if let path, !path.isEmpty {
            return "GraphQL error at \(path.joined(separator: ".")): \(message)"
        }
        return "GraphQL error: \(message)"
    }
}

/// Thrown when the server returned `errors` and the caller asked
/// for the data unwrapped. Carries every error so the user gets the
/// full picture.
public struct GraphQLAggregateError: Error, LocalizedError {
    public let errors: [GraphQLError]

    public var errorDescription: String? {
        if errors.count == 1 {
            return errors[0].errorDescription
        }
        return "GraphQL request failed with \(errors.count) errors:\n  - " +
            errors.map { $0.errorDescription ?? $0.message }.joined(separator: "\n  - ")
    }
}
