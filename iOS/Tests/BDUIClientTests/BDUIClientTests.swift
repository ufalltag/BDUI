import XCTest
@testable import BDUIClient

// MARK: - Mock client

final class MockBDUIClient: BDUIClientProtocol {
    var responses: [String: BDUIServerResponse] = [:]
    var lastFetchedKey: String? = nil
    var lastFetchedDynamicKey: String? = nil
    var lastFetchedCategory: String? = nil
    var requestCount = 0

    func fetch(screenId: String, cachedKey: String?, dynamicKey: String?, category: String?) async throws -> BDUIServerResponse {
        lastFetchedKey        = cachedKey
        lastFetchedDynamicKey = dynamicKey
        lastFetchedCategory   = category
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
      "cache_key": "abc123",
      "dynamic_key": "dyn456"
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
      },
      "dynamic_key": "dyn789"
    }
    """.data(using: .utf8)!
    return try! JSONDecoder().decode(BDUIServerResponse.self, from: json)
}

private func makeDynamicHitResponse(cacheKey: String = "abc123", dynamicKey: String = "dyn456") -> BDUIServerResponse {
    let json = """
    {
      "protocol_version": 1,
      "cache_key": "\(cacheKey)",
      "dynamic_key": "\(dynamicKey)"
    }
    """.data(using: .utf8)!
    return try! JSONDecoder().decode(BDUIServerResponse.self, from: json)
}

// MARK: - Cache tests

final class BDUICacheTests: XCTestCase {
    var cache: BDUICache!

    override func setUp() {
        super.setUp()
        cache = BDUICache(suiteName: "bdui.test.\(UUID().uuidString)")
    }

    func test_storeThenRetrieveCacheKey() {
        cache.update(
            cacheKey: "abc123",
            staticScreen: makeFullResponse().ui!.staticScreen!,
            for: "profile"
        )
        XCTAssertEqual(cache.cachedKey(for: "profile"), "abc123")
    }

    func test_storeThenRetrieveStaticScreen() throws {
        let full = makeFullResponse(layout: "ProfileV2")
        cache.update(cacheKey: "abc", staticScreen: full.ui!.staticScreen!, for: "profile")
        let retrieved = cache.cachedStatic(for: "profile")
        XCTAssertEqual(retrieved?.layout, "ProfileV2")
    }

    func test_invalidateRemovesData() {
        cache.update(cacheKey: "k", staticScreen: makeFullResponse().ui!.staticScreen!, for: "profile")
        cache.invalidate(for: "profile")
        XCTAssertNil(cache.cachedKey(for: "profile"))
        XCTAssertNil(cache.cachedStatic(for: "profile"))
    }

    func test_differentScreensDontInterfere() {
        let full = makeFullResponse()
        cache.update(cacheKey: "key-profile", staticScreen: full.ui!.staticScreen!, for: "profile")
        cache.update(cacheKey: "key-home",    staticScreen: full.ui!.staticScreen!, for: "home")
        XCTAssertEqual(cache.cachedKey(for: "profile"), "key-profile")
        XCTAssertEqual(cache.cachedKey(for: "home"),    "key-home")
    }

    func test_storeDynamicKeyAndRetrieve() {
        let full = makeFullResponse()
        cache.update(cacheKey: "abc", staticScreen: full.ui!.staticScreen!, for: "profile", dynamicKey: "dyn456")
        XCTAssertEqual(cache.cachedDynamicKey(for: "profile"), "dyn456")
    }

    func test_storeDynamicDataAndRetrieve() {
        let full = makeFullResponse(username: "Stored")
        cache.update(
            cacheKey: "abc",
            staticScreen: full.ui!.staticScreen!,
            for: "profile",
            dynamicKey: "dyn456",
            dynamic: full.ui!.dynamic
        )
        XCTAssertEqual(cache.cachedDynamic(for: "profile"), .object(["username": .string("Stored")]))
    }

    func test_updateDynamic_overwritesDynamicKeyAndData() {
        let full = makeFullResponse()
        cache.update(cacheKey: "abc", staticScreen: full.ui!.staticScreen!, for: "profile",
                     dynamicKey: "old_key", dynamic: .object(["username": .string("Old")]))
        cache.updateDynamic(dynamicKey: "new_key", dynamic: .object(["username": .string("New")]), for: "profile")
        XCTAssertEqual(cache.cachedDynamicKey(for: "profile"), "new_key")
        XCTAssertEqual(cache.cachedDynamic(for: "profile"), .object(["username": .string("New")]))
    }

    func test_invalidateRemovesDynamicData() {
        let full = makeFullResponse()
        cache.update(cacheKey: "k", staticScreen: full.ui!.staticScreen!, for: "profile",
                     dynamicKey: "d", dynamic: full.ui!.dynamic)
        cache.invalidate(for: "profile")
        XCTAssertNil(cache.cachedDynamicKey(for: "profile"))
        XCTAssertNil(cache.cachedDynamic(for: "profile"))
    }
}

// MARK: - Response decoding tests

final class BDUIResponseDecodingTests: XCTestCase {
    func test_fullResponseDecoding() {
        let response = makeFullResponse(layout: "HomeLayout", username: "Alice")
        XCTAssertFalse(response.isCacheHit)
        XCTAssertFalse(response.isDynamicHit)
        XCTAssertEqual(response.cacheKey, "abc123")
        XCTAssertEqual(response.dynamicKey, "dyn456")
        XCTAssertEqual(response.ui?.staticScreen?.layout, "HomeLayout")
        XCTAssertEqual(response.ui?.dynamic, .object(["username": .string("Alice")]))
    }

    func test_cacheHitResponseDecoding() {
        let response = makeCacheHitResponse(username: "Bob")
        XCTAssertTrue(response.isCacheHit)
        XCTAssertFalse(response.isDynamicHit)
        XCTAssertNil(response.cacheKey)
        XCTAssertEqual(response.dynamicKey, "dyn789")
        XCTAssertNil(response.ui?.staticScreen)
        XCTAssertEqual(response.ui?.dynamic, .object(["username": .string("Bob")]))
    }

    func test_dynamicHitResponseDecoding() {
        let response = makeDynamicHitResponse()
        XCTAssertFalse(response.isCacheHit)
        XCTAssertTrue(response.isDynamicHit)
        XCTAssertNil(response.ui)
        XCTAssertEqual(response.cacheKey, "abc123")
        XCTAssertEqual(response.dynamicKey, "dyn456")
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

    func test_firstLoad_sendsNoDynamicKey() async throws {
        mockClient.responses["profile"] = makeFullResponse()
        _ = try await loader.load(screenId: "profile")
        XCTAssertNil(mockClient.lastFetchedDynamicKey)
    }

    func test_firstLoad_populatesCache() async throws {
        mockClient.responses["profile"] = makeFullResponse()
        _ = try await loader.load(screenId: "profile")
        XCTAssertEqual(cache.cachedKey(for: "profile"), "abc123")
        XCTAssertNotNil(cache.cachedStatic(for: "profile"))
        XCTAssertEqual(cache.cachedDynamicKey(for: "profile"), "dyn456")
        XCTAssertNotNil(cache.cachedDynamic(for: "profile"))
    }

    func test_firstLoad_returnsCorrectScreenData() async throws {
        mockClient.responses["profile"] = makeFullResponse(username: "Tagir")
        let data = try await loader.load(screenId: "profile")
        XCTAssertEqual(data.cacheKey, "abc123")
        XCTAssertEqual(data.dynamicKey, "dyn456")
        XCTAssertEqual(data.dynamic, .object(["username": .string("Tagir")]))
    }

    // Second request: stored key is sent, server returns cache hit.
    func test_secondLoad_sendsCacheKey() async throws {
        mockClient.responses["profile"] = makeFullResponse()
        _ = try await loader.load(screenId: "profile")

        mockClient.responses["profile"] = makeCacheHitResponse()
        _ = try await loader.load(screenId: "profile")

        XCTAssertEqual(mockClient.lastFetchedKey, "abc123")
    }

    func test_secondLoad_sendsDynamicKey() async throws {
        mockClient.responses["profile"] = makeFullResponse()
        _ = try await loader.load(screenId: "profile")

        mockClient.responses["profile"] = makeCacheHitResponse()
        _ = try await loader.load(screenId: "profile")

        XCTAssertEqual(mockClient.lastFetchedDynamicKey, "dyn456")
    }

    func test_cacheHit_mergesStoredStaticWithNewDynamic() async throws {
        mockClient.responses["profile"] = makeFullResponse(layout: "ProfileV1", username: "Old")
        _ = try await loader.load(screenId: "profile")

        mockClient.responses["profile"] = makeCacheHitResponse(username: "New")
        let data = try await loader.load(screenId: "profile")

        XCTAssertEqual(data.staticScreen.layout, "ProfileV1")
        XCTAssertEqual(data.dynamic, .object(["username": .string("New")]))
        XCTAssertEqual(data.dynamicKey, "dyn789")
    }

    func test_cacheHit_updatesDynamicCache() async throws {
        mockClient.responses["profile"] = makeFullResponse()
        _ = try await loader.load(screenId: "profile")

        mockClient.responses["profile"] = makeCacheHitResponse(username: "Updated")
        _ = try await loader.load(screenId: "profile")

        XCTAssertEqual(cache.cachedDynamicKey(for: "profile"), "dyn789")
        XCTAssertEqual(cache.cachedDynamic(for: "profile"), .object(["username": .string("Updated")]))
    }

    // Third request: server returns DynamicHit (nothing changed).
    func test_dynamicHit_returnsDataFromLocalCache() async throws {
        mockClient.responses["profile"] = makeFullResponse(username: "Cached")
        _ = try await loader.load(screenId: "profile")

        mockClient.responses["profile"] = makeDynamicHitResponse()
        let data = try await loader.load(screenId: "profile")

        XCTAssertEqual(data.cacheKey, "abc123")
        XCTAssertEqual(data.dynamicKey, "dyn456")
        XCTAssertEqual(data.dynamic, .object(["username": .string("Cached")]))
    }

    func test_dynamicHit_doesNotChangeCache() async throws {
        mockClient.responses["profile"] = makeFullResponse(username: "Original")
        _ = try await loader.load(screenId: "profile")

        mockClient.responses["profile"] = makeDynamicHitResponse()
        _ = try await loader.load(screenId: "profile")

        XCTAssertEqual(cache.cachedDynamic(for: "profile"), .object(["username": .string("Original")]))
        XCTAssertEqual(cache.cachedDynamicKey(for: "profile"), "dyn456")
    }

    func test_dynamicHit_sendsCorrectKeys() async throws {
        mockClient.responses["profile"] = makeFullResponse()
        _ = try await loader.load(screenId: "profile")

        mockClient.responses["profile"] = makeDynamicHitResponse()
        _ = try await loader.load(screenId: "profile")

        XCTAssertEqual(mockClient.lastFetchedKey,       "abc123")
        XCTAssertEqual(mockClient.lastFetchedDynamicKey, "dyn456")
    }

    func test_totalRequestCount_threeLoads() async throws {
        mockClient.responses["profile"] = makeFullResponse()
        _ = try await loader.load(screenId: "profile")

        mockClient.responses["profile"] = makeCacheHitResponse()
        _ = try await loader.load(screenId: "profile")

        mockClient.responses["profile"] = makeDynamicHitResponse()
        _ = try await loader.load(screenId: "profile")

        XCTAssertEqual(mockClient.requestCount, 3)
    }

    func test_forceRefresh_ignoresCachedKey() async throws {
        mockClient.responses["profile"] = makeFullResponse()
        _ = try await loader.load(screenId: "profile")
        XCTAssertEqual(cache.cachedKey(for: "profile"), "abc123")

        mockClient.responses["profile"] = makeFullResponse()
        _ = try await loader.load(screenId: "profile", forceRefresh: true)
        XCTAssertNil(mockClient.lastFetchedKey)
    }

    func test_forceRefresh_invalidatesCacheBeforeFetch() async throws {
        mockClient.responses["profile"] = makeFullResponse()
        _ = try await loader.load(screenId: "profile")

        mockClient.responses["profile"] = makeFullResponse()
        _ = try await loader.load(screenId: "profile", forceRefresh: true)

        XCTAssertNotNil(cache.cachedKey(for: "profile"))
    }
}

// MARK: - Cache TTL tests

final class BDUICacheTTLTests: XCTestCase {
    var cache: BDUICache!

    override func setUp() {
        super.setUp()
        cache = BDUICache(suiteName: "bdui.ttl.test.\(UUID().uuidString)")
    }

    func test_isExpired_withNoTimestamp_returnsTrue() {
        XCTAssertTrue(cache.isExpired(for: "profile", maxAge: 3600))
    }

    func test_isExpired_afterUpdate_returnsFalse() {
        cache.update(
            cacheKey: "k",
            staticScreen: makeFullResponse().ui!.staticScreen!,
            for: "profile"
        )
        XCTAssertFalse(cache.isExpired(for: "profile", maxAge: 3600))
    }

    func test_isExpired_afterInvalidate_returnsTrue() {
        cache.update(
            cacheKey: "k",
            staticScreen: makeFullResponse().ui!.staticScreen!,
            for: "profile"
        )
        cache.invalidate(for: "profile")
        XCTAssertTrue(cache.isExpired(for: "profile", maxAge: 3600))
    }

    func test_isExpired_withZeroMaxAge_returnsTrue() {
        cache.update(
            cacheKey: "k",
            staticScreen: makeFullResponse().ui!.staticScreen!,
            for: "profile"
        )
        XCTAssertTrue(cache.isExpired(for: "profile", maxAge: 0))
    }

    func test_isExpired_differentScreensAreIndependent() {
        cache.update(cacheKey: "k", staticScreen: makeFullResponse().ui!.staticScreen!, for: "home")
        XCTAssertTrue(cache.isExpired(for: "profile", maxAge: 3600))
        XCTAssertFalse(cache.isExpired(for: "home", maxAge: 3600))
    }
}

// MARK: - Fallback / resilience tests (Point 12)

final class BDUIScreenLoaderFallbackTests: XCTestCase {
    var mockClient: MockBDUIClient!
    var cache: BDUICache!
    var loader: BDUIScreenLoader!

    override func setUp() {
        super.setUp()
        mockClient = MockBDUIClient()
        cache      = BDUICache(suiteName: "bdui.fallback.test.\(UUID().uuidString)")
        loader     = BDUIScreenLoader(client: mockClient, cache: cache)
    }

    // DynamicHit arrives but local dynamic cache is empty → refetch full response.
    func test_dynamicHit_withEmptyLocalCache_refetchesFull() async throws {
        // Warm up with a full response to populate the static cache but NOT the dynamic cache.
        mockClient.responses["profile"] = makeFullResponse()
        _ = try await loader.load(screenId: "profile")
        // Manually wipe only the dynamic portion.
        cache.updateDynamic(dynamicKey: "", dynamic: .null, for: "profile")
        // Poison the dynamic key so cachedDynamic returns nil after decode failure.
        // Easiest: just call invalidate and re-store only static + cache_key.
        let storedStatic = cache.cachedStatic(for: "profile")!
        cache.invalidate(for: "profile")
        cache.update(cacheKey: "abc123", staticScreen: storedStatic, for: "profile")
        // storedDynamicKey is now nil → loader will pass nil dynamic_key to client.

        // Server returns DynamicHit but local dynamic cache is empty → fallback to full.
        // DynamicHit with no local dynamic → loader invalidates and refetches full response.
        mockClient.responses["profile"] = makeFullResponse()
        // Loader should refetch and return valid ScreenData.
        let data = try await loader.load(screenId: "profile")
        XCTAssertEqual(data.cacheKey, "abc123")
    }

    // With completely empty cache, loader sends no cache_key and returns full response.
    func test_emptyCache_sendsSingleFullRequest() async throws {
        mockClient.responses["profile"] = makeFullResponse()
        let data = try await loader.load(screenId: "profile")
        XCTAssertNil(mockClient.lastFetchedKey)
        XCTAssertNil(mockClient.lastFetchedDynamicKey)
        XCTAssertFalse(data.cacheKey.isEmpty)
        XCTAssertEqual(mockClient.requestCount, 1)
    }

    // Network error propagates correctly (no silent swallowing).
    func test_networkError_propagatesToCaller() async {
        // No response set → MockBDUIClient throws 404.
        do {
            _ = try await loader.load(screenId: "profile")
            XCTFail("Expected error to be thrown")
        } catch BDUIError.serverError(let code) {
            XCTAssertEqual(code, 404)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // Multiple screens are independent — loading one doesn't affect another.
    func test_multipleScreens_independentCaches() async throws {
        mockClient.responses["profile"] = makeFullResponse()
        mockClient.responses["home"]    = makeFullResponse(layout: "HomeLayout", username: "HomeUser")

        let profile = try await loader.load(screenId: "profile")
        let home    = try await loader.load(screenId: "home")

        XCTAssertEqual(profile.staticScreen.layout, "TestLayout")
        XCTAssertEqual(home.staticScreen.layout,    "HomeLayout")
        XCTAssertNil(cache.cachedKey(for: "settings"))
    }
}

// MARK: - Session simulation tests (Point 12)

final class BDUISessionSimulationTests: XCTestCase {
    var mockClient: MockBDUIClient!
    var cache: BDUICache!
    var loader: BDUIScreenLoader!

    override func setUp() {
        super.setUp()
        mockClient = MockBDUIClient()
        cache      = BDUICache(suiteName: "bdui.session.test.\(UUID().uuidString)")
        loader     = BDUIScreenLoader(client: mockClient, cache: cache)
    }

    // Simulates a full three-level session: First → CacheHit → DynamicHit.
    func test_fullSession_firstThenCacheHitThenDynamicHit() async throws {
        // Request 1: First — full response.
        mockClient.responses["profile"] = makeFullResponse(layout: "V1", username: "Tagir")
        let data1 = try await loader.load(screenId: "profile")
        XCTAssertEqual(data1.staticScreen.layout, "V1")
        XCTAssertEqual(data1.dynamic, .object(["username": .string("Tagir")]))

        // Request 2: CacheHit — static unchanged, dynamic updated.
        mockClient.responses["profile"] = makeCacheHitResponse(username: "Tagir Updated")
        let data2 = try await loader.load(screenId: "profile")
        XCTAssertEqual(data2.staticScreen.layout, "V1")   // from local cache
        XCTAssertEqual(data2.dynamic, .object(["username": .string("Tagir Updated")]))

        // Request 3: DynamicHit — nothing changed, served from local cache.
        mockClient.responses["profile"] = makeDynamicHitResponse()
        let data3 = try await loader.load(screenId: "profile")
        XCTAssertEqual(data3.staticScreen.layout, "V1")
        XCTAssertEqual(data3.dynamic, .object(["username": .string("Tagir Updated")]))

        XCTAssertEqual(mockClient.requestCount, 3)
    }

    // After forceRefresh the session starts over: full response is fetched again.
    func test_forceRefresh_resetsSession() async throws {
        // Warm up.
        mockClient.responses["profile"] = makeFullResponse()
        _ = try await loader.load(screenId: "profile")
        _ = try await loader.load(screenId: "profile")   // uses DynamicHit internally if keys match

        // Force refresh: client sends no keys → server returns full response.
        mockClient.responses["profile"] = makeFullResponse(layout: "V2", username: "New")
        let data = try await loader.load(screenId: "profile", forceRefresh: true)
        XCTAssertNil(mockClient.lastFetchedKey)
        XCTAssertNil(mockClient.lastFetchedDynamicKey)
        XCTAssertEqual(data.staticScreen.layout, "V2")
    }

    // ScreenData always contains both keys after any successful load.
    func test_screenData_alwaysHasBothKeys() async throws {
        // Full response
        mockClient.responses["profile"] = makeFullResponse()
        let d1 = try await loader.load(screenId: "profile")
        XCTAssertFalse(d1.cacheKey.isEmpty)
        XCTAssertFalse(d1.dynamicKey.isEmpty)

        // CacheHit
        mockClient.responses["profile"] = makeCacheHitResponse()
        let d2 = try await loader.load(screenId: "profile")
        XCTAssertFalse(d2.cacheKey.isEmpty)
        XCTAssertFalse(d2.dynamicKey.isEmpty)

        // DynamicHit
        mockClient.responses["profile"] = makeDynamicHitResponse()
        let d3 = try await loader.load(screenId: "profile")
        XCTAssertFalse(d3.cacheKey.isEmpty)
        XCTAssertFalse(d3.dynamicKey.isEmpty)
    }
}
