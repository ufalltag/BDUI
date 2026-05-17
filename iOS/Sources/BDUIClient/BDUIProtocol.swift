import Foundation

public enum BDUIProtocol {
    /// Protocol version this client implements.
    public static let currentVersion: Int = 1

    /// All versions this client can read.
    public static let supportedVersions: [Int] = [1]
}

// MARK: - Version error

public struct BDUIVersionError: Error, LocalizedError, Decodable {
    public let error: String
    public let clientVersion: Int
    public let supportedVersions: [Int]

    enum CodingKeys: String, CodingKey {
        case error
        case clientVersion     = "client_version"
        case supportedVersions = "supported_versions"
    }

    public var errorDescription: String? {
        "Server rejected protocol v\(clientVersion). Supported: \(supportedVersions)"
    }
}

// MARK: - Meta

public struct BDUIMeta: Decodable {
    public let protocolVersion: Int
    public let supportedVersions: [Int]
    public let screens: [BDUIScreenMeta]

    enum CodingKeys: String, CodingKey {
        case protocolVersion   = "protocol_version"
        case supportedVersions = "supported_versions"
        case screens
    }
}

public struct BDUIScreenMeta: Decodable {
    public let id: String
    public let endpoint: String
}
