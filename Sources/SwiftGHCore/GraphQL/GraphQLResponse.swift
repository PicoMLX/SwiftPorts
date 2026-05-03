import Foundation

/// Envelope returned by every GraphQL endpoint:
///
/// ```json
/// { "data": { ... }, "errors": [ { "message": "...", ... } ] }
/// ```
///
/// `data` is generic so callers decode their own typed payload.
/// `errors` is populated even when `data` is partial — GraphQL
/// returns 200 with both on partial failures.
public struct GraphQLResponse<Payload: Decodable & Sendable>: Decodable, Sendable {
    public let data: Payload?
    public let errors: [GraphQLError]?
}

public struct GraphQLError: Decodable, Sendable, Error {
    public let message: String
    public let path: [String]?
    public let locations: [Location]?
    public let type: String?
    public let extensions: [String: String]?

    public struct Location: Decodable, Sendable {
        public let line: Int
        public let column: Int
    }
}
