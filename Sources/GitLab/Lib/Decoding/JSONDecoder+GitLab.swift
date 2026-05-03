import Foundation

extension JSONDecoder {
    /// Decoder configured for GitLab REST responses: snake_case →
    /// camelCase mapping, ISO 8601 dates with fractional seconds.
    public static func gitLab() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fallback = ISO8601DateFormatter()
        fallback.formatOptions = [.withInternetDateTime]
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            if let date = formatter.date(from: raw) ?? fallback.date(from: raw) {
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
