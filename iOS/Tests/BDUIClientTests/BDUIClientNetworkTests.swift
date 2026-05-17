import XCTest
@testable import BDUIClient

// MARK: - URLProtocol mock

final class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.cannotFindHost))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

// MARK: - Helpers

private let baseURL = URL(string: "http://localhost:3000")!

private func makeMockSession() -> URLSession {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
    return URLSession(configuration: config)
}

private func makeClient() -> BDUIClient {
    BDUIClient(baseURL: baseURL, session: makeMockSession())
}

private func httpResponse(for request: URLRequest, statusCode: Int) -> HTTPURLResponse {
    HTTPURLResponse(url: request.url!, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
}

private let validScreenData = """
{
  "protocol_version": 1,
  "ui": {
    "static": {
      "screen_id": "profile",
      "layout": "ProfileLayout",
      "navigation": { "tab_bar": false, "back_button": true, "title": "Profile" },
      "components": []
    },
    "dynamic": {}
  },
  "cache_key": "abc123"
}
""".data(using: .utf8)!

private let validMetaData = """
{
  "protocol_version": 1,
  "supported_versions": [1],
  "screens": [
    { "id": "profile", "endpoint": "/bdui/screen/profile" }
  ]
}
""".data(using: .utf8)!

private let versionErrorData = """
{
  "error": "unsupported_protocol_version",
  "client_version": 99,
  "supported_versions": [1]
}
""".data(using: .utf8)!

// MARK: - BDUIClient network tests

final class BDUIClientNetworkTests: XCTestCase {

    override func tearDown() {
        MockURLProtocol.requestHandler = nil
        super.tearDown()
    }

    // MARK: Version header

    func test_fetch_sendsVersionHeader() async throws {
        var capturedRequest: URLRequest?
        MockURLProtocol.requestHandler = { request in
            capturedRequest = request
            return (httpResponse(for: request, statusCode: 200), validScreenData)
        }

        _ = try await makeClient().fetch(screenId: "profile", cachedKey: nil)

        let header = capturedRequest?.value(forHTTPHeaderField: "X-BDUI-Version")
        XCTAssertEqual(header, "\(BDUIProtocol.currentVersion)")
    }

    func test_fetchMeta_sendsVersionHeader() async throws {
        var capturedRequest: URLRequest?
        MockURLProtocol.requestHandler = { request in
            capturedRequest = request
            return (httpResponse(for: request, statusCode: 200), validMetaData)
        }

        _ = try await makeClient().fetchMeta()

        let header = capturedRequest?.value(forHTTPHeaderField: "X-BDUI-Version")
        XCTAssertEqual(header, "\(BDUIProtocol.currentVersion)")
    }

    // MARK: URL construction

    func test_fetchWithNoCacheKey_urlHasNoQueryParam() async throws {
        var capturedURL: URL?
        MockURLProtocol.requestHandler = { request in
            capturedURL = request.url
            return (httpResponse(for: request, statusCode: 200), validScreenData)
        }

        _ = try await makeClient().fetch(screenId: "profile", cachedKey: nil)

        XCTAssertNil(capturedURL?.query)
    }

    func test_fetchWithCacheKey_urlHasCacheKeyQueryParam() async throws {
        var capturedURL: URL?
        MockURLProtocol.requestHandler = { request in
            capturedURL = request.url
            return (httpResponse(for: request, statusCode: 200), validScreenData)
        }

        _ = try await makeClient().fetch(screenId: "profile", cachedKey: "abc123")

        XCTAssertTrue(capturedURL?.query?.contains("cache_key=abc123") == true)
    }

    func test_fetch_urlContainsScreenId() async throws {
        var capturedURL: URL?
        MockURLProtocol.requestHandler = { request in
            capturedURL = request.url
            return (httpResponse(for: request, statusCode: 200), validScreenData)
        }

        _ = try await makeClient().fetch(screenId: "profile", cachedKey: nil)

        XCTAssertTrue(capturedURL?.path.contains("profile") == true)
    }

    func test_fetchMeta_urlContainsMetaPath() async throws {
        var capturedURL: URL?
        MockURLProtocol.requestHandler = { request in
            capturedURL = request.url
            return (httpResponse(for: request, statusCode: 200), validMetaData)
        }

        _ = try await makeClient().fetchMeta()

        XCTAssertTrue(capturedURL?.absoluteString.contains("bdui/meta") == true)
    }

    // MARK: HTTP status handling

    func test_406Response_throwsBDUIVersionError() async {
        MockURLProtocol.requestHandler = { request in
            return (httpResponse(for: request, statusCode: 406), versionErrorData)
        }

        do {
            _ = try await makeClient().fetch(screenId: "profile", cachedKey: nil)
            XCTFail("Expected BDUIVersionError to be thrown")
        } catch let error as BDUIVersionError {
            XCTAssertEqual(error.error, "unsupported_protocol_version")
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    func test_500Response_throwsServerError() async {
        MockURLProtocol.requestHandler = { request in
            return (httpResponse(for: request, statusCode: 500), Data())
        }

        do {
            _ = try await makeClient().fetch(screenId: "profile", cachedKey: nil)
            XCTFail("Expected BDUIError.serverError to be thrown")
        } catch BDUIError.serverError(let code) {
            XCTAssertEqual(code, 500)
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    func test_200Response_returnsDecodedResponse() async throws {
        MockURLProtocol.requestHandler = { request in
            return (httpResponse(for: request, statusCode: 200), validScreenData)
        }

        let response = try await makeClient().fetch(screenId: "profile", cachedKey: nil)

        XCTAssertEqual(response.cacheKey, "abc123")
        XCTAssertEqual(response.protocolVersion, 1)
        XCTAssertFalse(response.isCacheHit)
    }
}
