import Foundation

// ISO8601DateFormatter is internally thread-safe (Apple docs); marking
// the shared instances `nonisolated(unsafe)` lets the @Sendable
// dateDecodingStrategy closure capture them without warnings.
private nonisolated(unsafe) let iso8601WithFractional: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
}()
private nonisolated(unsafe) let iso8601Plain: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime]
    return f
}()

extension JSONDecoder {
    /// Decoder configured for GitLab REST responses: snake_case →
    /// camelCase mapping, ISO 8601 dates with fractional seconds.
    public static func gitLab() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            if let date = iso8601WithFractional.date(from: raw)
                ?? iso8601Plain.date(from: raw) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unrecognised date \(raw)")
        }
        return decoder
    }
}

extension JSONEncoder {
    /// Encoder configured for GitLab REST request bodies: camelCase →
    /// snake_case mapping, ISO 8601 dates.
    public static func gitLab() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}
