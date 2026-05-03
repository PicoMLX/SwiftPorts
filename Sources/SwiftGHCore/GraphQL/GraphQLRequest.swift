import Foundation

/// A GraphQL request: a query / mutation string plus optional
/// variables. Encodes to the wire format the GitHub GraphQL endpoint
/// expects: `{"query": "...", "variables": {...}, "operationName": "..."}`.
public struct GraphQLRequest: Sendable, Encodable {
    public let query: String
    public let variables: [String: GraphQLValue]?
    public let operationName: String?

    public init(
        query: String,
        variables: [String: GraphQLValue]? = nil,
        operationName: String? = nil
    ) {
        self.query = query
        self.variables = variables
        self.operationName = operationName
    }
}

/// Loosely-typed JSON value for GraphQL variables. Mirrors what
/// `JSONSerialization` accepts: scalars, arrays, and dictionaries.
///
/// Values constructed via the literal-conformances or the static
/// helpers, never via raw `Any`.
public enum GraphQLValue: Sendable, Encodable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case array([GraphQLValue])
    case object([String: GraphQLValue])
    case null

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let v): try container.encode(v)
        case .int(let v): try container.encode(v)
        case .double(let v): try container.encode(v)
        case .bool(let v): try container.encode(v)
        case .array(let v): try container.encode(v)
        case .object(let v): try container.encode(v)
        case .null: try container.encodeNil()
        }
    }
}

extension GraphQLValue: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) { self = .string(value) }
}
extension GraphQLValue: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) { self = .int(value) }
}
extension GraphQLValue: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) { self = .double(value) }
}
extension GraphQLValue: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) { self = .bool(value) }
}
extension GraphQLValue: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: GraphQLValue...) { self = .array(elements) }
}
extension GraphQLValue: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, GraphQLValue)...) {
        self = .object(Dictionary(uniqueKeysWithValues: elements))
    }
}
extension GraphQLValue: ExpressibleByNilLiteral {
    public init(nilLiteral: ()) { self = .null }
}
