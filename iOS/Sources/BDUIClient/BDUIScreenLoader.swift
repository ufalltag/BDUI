import Foundation

// MARK: - Protocol (for testability)

public protocol BDUIScreenLoaderProtocol {
    func load(screenId: String) async throws -> ScreenData
}

/// Coordinates the BDUI caching protocol:
///
///  1. Read locally cached `cache_key` for the screen.
///  2. Send request (with or without the key).
///  3. On **full response**   → update local cache, return combined data.
///  4. On **cache hit**       → merge server dynamic with locally stored static.
///  5. On **cache mismatch** (stored static is gone) → refetch without key.
public final class BDUIScreenLoader: BDUIScreenLoaderProtocol {
    private let client: BDUIClientProtocol
    private let cache: BDUICache

    public init(client: BDUIClientProtocol, cache: BDUICache = BDUICache()) {
        self.client = client
        self.cache  = cache
    }

    public func load(screenId: String) async throws -> ScreenData {
        let storedKey = cache.cachedKey(for: screenId)
        let response  = try await client.fetch(screenId: screenId, cachedKey: storedKey)

        if response.isCacheHit {
            return try await handleCacheHit(response: response, screenId: screenId, storedKey: storedKey)
        } else {
            return handleFullResponse(response: response, screenId: screenId)
        }
    }

    // MARK: - Private

    private func handleFullResponse(response: BDUIServerResponse, screenId: String) -> ScreenData {
        guard let staticScreen = response.ui.staticScreen,
              let cacheKey     = response.cacheKey else {
            // Should never happen: server contract guarantees both fields in full response.
            preconditionFailure("Full response missing static or cache_key for screen '\(screenId)'")
        }
        cache.update(cacheKey: cacheKey, staticScreen: staticScreen, for: screenId)
        return ScreenData(staticScreen: staticScreen, dynamic: response.ui.dynamic, cacheKey: cacheKey)
    }

    private func handleCacheHit(
        response: BDUIServerResponse,
        screenId: String,
        storedKey: String?
    ) async throws -> ScreenData {
        guard let staticScreen = cache.cachedStatic(for: screenId),
              let cacheKey     = storedKey else {
            // Local cache is missing the static part — invalidate and refetch from scratch.
            cache.invalidate(for: screenId)
            return try await load(screenId: screenId)
        }
        return ScreenData(staticScreen: staticScreen, dynamic: response.ui.dynamic, cacheKey: cacheKey)
    }
}
