import XCTest
@testable import BDUIClient

final class BDUIProtocolTests: XCTestCase {

    func test_currentVersion_isOne() {
        XCTAssertEqual(BDUIProtocol.currentVersion, 1)
    }

    func test_supportedVersions_containCurrentVersion() {
        XCTAssertTrue(BDUIProtocol.supportedVersions.contains(BDUIProtocol.currentVersion))
    }

    func test_supportedVersions_isNotEmpty() {
        XCTAssertFalse(BDUIProtocol.supportedVersions.isEmpty)
    }

    func test_versionError_decodesFromJSON() throws {
        let json = """
        {
          "error": "unsupported_protocol_version",
          "client_version": 99,
          "supported_versions": [1, 2]
        }
        """.data(using: .utf8)!

        let error = try JSONDecoder().decode(BDUIVersionError.self, from: json)

        XCTAssertEqual(error.error, "unsupported_protocol_version")
        XCTAssertEqual(error.clientVersion, 99)
        XCTAssertEqual(error.supportedVersions, [1, 2])
    }

    func test_versionError_errorDescription_containsClientVersion() throws {
        let json = """
        {
          "error": "unsupported_protocol_version",
          "client_version": 5,
          "supported_versions": [1]
        }
        """.data(using: .utf8)!

        let error = try JSONDecoder().decode(BDUIVersionError.self, from: json)

        XCTAssertTrue(error.errorDescription?.contains("5") == true)
    }

    func test_meta_decodesFromJSON() throws {
        let json = """
        {
          "protocol_version": 1,
          "supported_versions": [1],
          "screens": [
            { "id": "profile", "endpoint": "/bdui/screen/profile" },
            { "id": "home",    "endpoint": "/bdui/screen/home" }
          ]
        }
        """.data(using: .utf8)!

        let meta = try JSONDecoder().decode(BDUIMeta.self, from: json)

        XCTAssertEqual(meta.protocolVersion, 1)
        XCTAssertEqual(meta.screens.count, 2)
        XCTAssertEqual(meta.screens.first?.id, "profile")
    }
}
