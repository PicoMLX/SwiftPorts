import Foundation

/// GitLab pipeline / job status. Modelled as a `RawRepresentable` enum
/// with a `.unknown` fallback so future statuses don't break decoding.
public enum PipelineStatus: RawRepresentable, Codable, Sendable, Hashable {
    case created
    case waitingForResource
    case preparing
    case pending
    case running
    case success
    case failed
    case canceled
    case skipped
    case manual
    case scheduled
    case canceling
    case unknown(String)

    public init(rawValue: String) {
        switch rawValue {
        case "created": self = .created
        case "waiting_for_resource": self = .waitingForResource
        case "preparing": self = .preparing
        case "pending": self = .pending
        case "running": self = .running
        case "success": self = .success
        case "failed": self = .failed
        case "canceled": self = .canceled
        case "skipped": self = .skipped
        case "manual": self = .manual
        case "scheduled": self = .scheduled
        case "canceling": self = .canceling
        default: self = .unknown(rawValue)
        }
    }

    public var rawValue: String {
        switch self {
        case .created: return "created"
        case .waitingForResource: return "waiting_for_resource"
        case .preparing: return "preparing"
        case .pending: return "pending"
        case .running: return "running"
        case .success: return "success"
        case .failed: return "failed"
        case .canceled: return "canceled"
        case .skipped: return "skipped"
        case .manual: return "manual"
        case .scheduled: return "scheduled"
        case .canceling: return "canceling"
        case .unknown(let s): return s
        }
    }

    /// `true` once the status will not change again.
    public var isTerminal: Bool {
        switch self {
        case .success, .failed, .canceled, .skipped, .manual:
            return true
        default:
            return false
        }
    }

    /// `true` if the status counts as "in progress" (still doing work).
    public var isInProgress: Bool {
        switch self {
        case .pending, .running, .preparing, .waitingForResource, .canceling, .created:
            return true
        default:
            return false
        }
    }
}
