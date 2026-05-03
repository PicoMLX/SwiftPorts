import Foundation

/// Error surface for the GitLab `APIClient`.
public enum APIError: Error, Sendable {
    case transport(underlying: Error)
    case http(status: Int, message: String, url: URL)
    case unauthenticated(url: URL)
    case notFound(url: URL)
    case decoding(underlying: Error, url: URL)
}

extension APIError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .transport(let underlying):
            return "Network error: \(underlying.localizedDescription)"
        case .http(let status, let message, let url):
            let trimmed = message.isEmpty ? "" : ": \(message)"
            return "GitLab API \(status)\(trimmed) — \(url.absoluteString)"
        case .unauthenticated(let url):
            return "Unauthenticated. Set GITLAB_TOKEN or run `glab auth login`. (\(url.absoluteString))"
        case .notFound(let url):
            return "Not found: \(url.absoluteString)"
        case .decoding(let underlying, let url):
            return "Decode error from \(url.absoluteString): \(underlying.localizedDescription)"
        }
    }
}
