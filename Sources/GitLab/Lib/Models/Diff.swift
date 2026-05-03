import Foundation

/// Single-file diff entry returned by
/// `GET /projects/:id/merge_requests/:iid/changes` (under `.changes`).
public struct DiffChange: Codable, Sendable {
    public let oldPath: String
    public let newPath: String
    public let aMode: String?
    public let bMode: String?
    public let newFile: Bool
    public let renamedFile: Bool
    public let deletedFile: Bool
    public let diff: String
}

/// Wrapper for the MR-changes response, decoded as a sibling of
/// every `MergeRequest` field with an extra `changes` array.
public struct MergeRequestChanges: Codable, Sendable {
    public let changes: [DiffChange]
}
