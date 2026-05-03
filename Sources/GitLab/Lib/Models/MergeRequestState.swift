import Foundation

/// GitLab merge request states. Modelled with a `.unknown(String)`
/// fallback so future / instance-specific states don't break decoding.
public enum MergeRequestState: RawRepresentable, Codable, Sendable, Hashable {
    case opened
    case closed
    case merged
    case locked
    case unknown(String)

    public init(rawValue: String) {
        switch rawValue {
        case "opened": self = .opened
        case "closed": self = .closed
        case "merged": self = .merged
        case "locked": self = .locked
        default: self = .unknown(rawValue)
        }
    }

    public var rawValue: String {
        switch self {
        case .opened: return "opened"
        case .closed: return "closed"
        case .merged: return "merged"
        case .locked: return "locked"
        case .unknown(let s): return s
        }
    }
}
