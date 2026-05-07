import Foundation

/// Thread-safe in-process secret store. Default for tests and for
/// embedders that don't want any disk persistence.
///
/// Values are dropped when the process exits. NEVER use as a "real"
/// store — gh-style commands assume secrets survive across runs.
public final class InMemorySecretStore: SecretStore, @unchecked Sendable {
    private struct Key: Hashable {
        let service: String
        let account: String
    }
    // `NSLock.withLock(_:)` is async-safe (closure can't suspend) and
    // available everywhere we ship. Switching to
    // `Synchronization.Mutex` would force the package floor up to
    // macOS 15 / iOS 18, which we deliberately keep low so SwiftBash
    // and other embedders can target their existing OS ranges.
    private let lock = NSLock()
    private var storage: [Key: String] = [:]

    public init() {}

    public func get(service: String, account: String) async throws -> String? {
        lock.withLock { storage[Key(service: service, account: account)] }
    }

    public func set(service: String, account: String, secret: String) async throws {
        lock.withLock { storage[Key(service: service, account: account)] = secret }
    }

    public func delete(service: String, account: String) async throws {
        lock.withLock { storage[Key(service: service, account: account)] = nil }
    }
}
