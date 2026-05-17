import XCTest
@testable import BDUIClient

// MARK: - Mock client

final class MockBDUIClient: BDUIClientProtocol {
    var responses: [String: BDUIServerResponse] = [:]
    var lastFetchedKey: String? = nil
    var requestCount = 0

    func fetch(screenId: String, cachedKey: String?) async throws -> BDUIServerResponse {
        lastFetchedKey = cachedKey
        requestCount += 1
        guard let response = responses[screenId] else {
            throw BDUIError.serverError(statusCode: 404)
        }
        return response
    }
}

// MARK: - Helpers

private func makeFullResponse(layout: String = "TestLayout", username: String = "Tagir") -> BDUIServerResponse {
    let json = """
    {
      "protocol_version": 1,
      "ui": {
        "static": {
          "screen_id": "profile",
          "layout": "\(layout)",
          "navigation": { "tab_bar": false, "back_button": true, "title": "Profile" },
          "components": [{ "type": "text", "id": "username" }]
        },
        "dynamic": { "username": "\(username)" }
      },
      "cache_key": "abc123"
    }
    """.data(using: .utf8)!
    return try! JSONDecoder().decode(BDUIServerResponse.self, from: json)
}

private func makeCacheHitResponse(username: String = "Tagir Updated") -> BDUIServerResponse {
    let json = """
    {
      "protocol_version": 1,
      "ui": {
        "dynamic": { "username": "\(username)" }
      }
    }
    """.data(using: .utf8)!
    return try! JSONDecoder().decode(BDUIServerResponse.self, from: json)
}

// MARK: - Cache tests

final class BDUICacheTests: XCTestCase {
    var cache: BDUICache!

    override func setUp() {
        super.setUp()
        // Use a separate suite to avoid polluting standard UserDefaults.
        cache = BDUICache(suiteName: "bdui.test.\(UUID().uuidString)")
    }

    func test_storeThenRetrieveCacheKey() {
        cache.update(
            cacheKey: "abc123",
            staticScreen: makeFullResponse().ui.staticScreen!,
            for: "profile"
        )
        XCTAssertEqual(cache.cachedKey(for: "profile"), "abc123")
    }

    func test_storeThenRetrieveStaticScreen() throws {
        let full = makeFullResponse(layout: "ProfileV2")
        cache.update(cacheKey: "abc", staticScreen: full.ui.staticScreen!, for: "profile")
        let retrieved = cache.cachedStatic(for: "profile")
        XCTAssertEqual(retrieved?.layout, "ProfileV2")
    }

    func test_invalidateRemovesData() {
        cache.update(cacheKey: "k", staticScreen: makeFullResponse().ui.staticScreen!, for: "profile")
        cache.invalidate(for: "profile")
        XCTAssertNil(cache.cachedKey(for: "profile"))
        XCTAssertNil(cache.cachedStatic(for: "profile"))
    }

    func test_differentScreensDontInterfere() {
        let full = makeFullResponse()
        cache.update(cacheKey: "key-profile",  staticScreen: full.ui.staticScreen!, for: "profile")
        cache.update(cacheKey: "key-home",     staticScreen: full.ui.staticScreen!, for: "home")
        XCTAssertEqual(cache.cachedKey(for: "profile"), "key-profile")
        XCTAssertEqual(cache.cachedKey(for: "home"),    "key-home")
    }
}

// MARK: - Response decoding tests

final class BDUIResponseDecodingTests: XCTestCase {
    func test_fullResponseDecoding() {
        let response = makeFullResponse(layout: "HomeLayout", username: "Alice")
        XCTAssertFalse(response.isCacheHit)
        XCTAssertEqual(response.cacheKey, "abc123")
        XCTAssertEqual(response.ui.staticScreen?.layout, "HomeLayout")
        XCTAssertEqual(response.ui.dynamic, .object(["username": .string("Alice")]))
    }

    func test_cacheHitResponseDecoding() {
        let response = makeCacheHitResponse(username: "Bob")
        XCTAssertTrue(response.isCacheHit)
        XCTAssertNil(response.cacheKey)
        XCTAssertNil(response.ui.staticScreen)
        XCTAssertEqual(response.ui.dynamic, .object(["username": .string("Bob")]))
    }
}

// MARK: - Screen loader tests

final class BDUIScreenLoaderTests: XCTestCase {
    var mockClient: MockBDUIClient!
    var cache: BDUICache!
    var loader: BDUIScreenLoader!

    override func setUp() {
        super.setUp()
        mockClient = MockBDUIClient()
        cache      = BDUICache(suiteName: "bdui.loader.test.\(UUID().uuidString)")
        loader     = BDUIScreenLoader(client: mockClient, cache: cache)
    }

    // First request: no cache_key sent, full response returned, cache populated.
    func test_firstLoad_sendsNoCacheKey() async throws {
        mockClient.responses["profile"] = makeFullResponse()
        _ = try await loader.load(screenId: "profile")
        XCTAssertNil(mockClient.lastFetchedKey)
    }

    func test_firstLoad_populatesCache() async throws {
        mockClient.responses["profile"] = makeFullResponse()
        _ = try await loader.load(screenId: "profile")
        XCTAssertEqual(cache.cachedKey(for: "profile"), "abc123")
        XCTAssertNotNil(cache.cachedStatic(for: "profile"))
    }

    func test_firstLoad_returnsCorrectScreenData() async throws {
        mockClient.responses["profile"] = makeFullResponse(username: "Tagir")
        let data = try await loader.load(screenId: "profile")
        XCTAssertEqual(data.cacheKey, "abc123")
        XCTAssertEqual(data.dynamic, .object(["username": .string("Tagir")]))
    }

    // Second request: stored key is sent, server returns cache hit.
    func test_secondLoad_sendsCacheKey() async throws {
        mockClient.responses["profile"] = makeFullResponse()
        _ = try await loader.load(screenId: "profile")            // first load — populates cache

        mockClient.responses["profile"] = makeCacheHitResponse()
        _ = try await loader.load(screenId: "profile")            // second load — should send key

        XCTAssertEqual(mockClient.lastFetchedKey, "abc123")
    }

    func test_cacheHit_mergesStoredStaticWithNewDynamic() async throws {
        mockClient.responses["profile"] = makeFullResponse(layout: "ProfileV1", username: "Old")
        _ = try await loader.load(screenId: "profile")

        mockClient.responses["profile"] = makeCacheHitResponse(username: "New")
        let data = try await loader.load(screenId: "profile")

        // Static comes from local cache (not re-sent by server)
        XCTAssertEqual(data.staticScreen.layout, "ProfileV1")
        // Dynamic comes from server cache-hit response
        XCTAssertEqual(data.dynamic, .object(["username": .string("New")]))
    }

    func test_totalRequestCount_twoLoads() async throws {
        mockClient.responses["profile"] = makeFullResponse()
        _ = try await loader.load(screenId: "profile")

        mockClient.responses["profile"] = makeCacheHitResponse()
        _ = try await loader.load(screenId: "profile")

        XCTAssertEqual(mockClient.requestCount, 2)
    }
}
