import Foundation

public struct SSHKey: Codable, Sendable, Identifiable {
    public let id: Int
    public let key: String
    public let title: String?
    public let url: URL?
    public let createdAt: Date?
    public let verified: Bool?
    public let readOnly: Bool?
}

public struct GPGKey: Codable, Sendable, Identifiable {
    public let id: Int
    public let primaryKeyId: Int?
    public let keyId: String
    public let publicKey: String?
    public let emails: [GPGKeyEmail]?
    public let canSign: Bool?
    public let canEncryptComms: Bool?
    public let canEncryptStorage: Bool?
    public let canCertify: Bool?
    public let createdAt: Date?
    public let expiresAt: Date?
    public let revoked: Bool?
}

public struct GPGKeyEmail: Codable, Sendable {
    public let email: String
    public let verified: Bool
}
