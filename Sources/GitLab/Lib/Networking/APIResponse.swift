import Foundation

/// Generic response wrapper for the GitLab `APIClient`. GitLab uses
/// header-based pagination — `X-Next-Page`, `X-Total-Pages`, etc.
public struct APIResponse: Sendable {
    public let status: Int
    public let body: Data
    public let url: URL
    public let nextPage: Int?
    public let totalPages: Int?
    public let total: Int?
    public let perPage: Int?
    public let contentType: String?
}
