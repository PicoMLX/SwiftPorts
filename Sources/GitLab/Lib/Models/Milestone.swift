import Foundation

public struct Milestone: Codable, Sendable, Hashable {
    public let id: Int
    public let iid: Int
    public let title: String
    public let description: String?
    public let state: String
    public let webUrl: URL?
}
