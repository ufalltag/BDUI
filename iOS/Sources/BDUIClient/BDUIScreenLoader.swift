import Foundation

// MARK: - Protocol (for testability)

public protocol BDUIScreenLoaderProtocol {
    func load(screenId: String, forceRefresh: Bool, category: String?) async throws -> ScreenData
}

extension BDUIScreenLoaderProtocol {
    /// Convenience: loads without forcing refresh and without a variant.
    public func load(screenId: String) async throws -> ScreenData {
        try await load(screenId: screenId, forceRefresh: false, category: nil)
    }

    /// Convenience: loads with an explicit refresh flag, default variant.
    public func load(screenId: String, forceRefresh: Bool) async throws -> ScreenData {
        try await load(screenId: screenId, forceRefresh: forceRefresh, category: nil)
    }
}

/// Coordinates the three-level BDUI caching protocol:
///
///  1. Invalidate local cache if `forceRefresh` or TTL exceeded.
///  2. Read locally cached `cache_key` and `dynamic_key`.
///  3. Send request (with whichever keys are known).
///  4. **Full response**   → update static + dynamic cache, return combined data.
///  5. **CacheHit**        → update dynamic cache, merge with locally stored static.
///  6. **DynamicHit**      → serve entirely from local cache (zero bytes from server).
///  7. **Cache mismatch**  → local static/dynamic gone, invalidate and refetch.
public final class BDUIScreenLoader: BDUIScreenLoaderProtocol {
    private let client: BDUIClientProtocol
    private let cache: BDUICache
    /// Maximum age of a cached screen before it is treated as stale. Default: 24 hours.
    public let maxCacheAge: TimeInterval

    public init(
        client: BDUIClientProtocol,
        cache: BDUICache = BDUICache(),
        maxCacheAge: TimeInterval = 24 * 3600
    ) {
        self.client      = client
        self.cache       = cache
        self.maxCacheAge = maxCacheAge
    }

    public func load(screenId: String, forceRefresh: Bool = false, category: String? = nil) async throws -> ScreenData {
        if forceRefresh || cache.isExpired(for: screenId, maxAge: maxCacheAge) {
            cache.invalidate(for: screenId)
        }

        let storedKey    = cache.cachedKey(for: screenId)
        let storedDynKey = cache.cachedDynamicKey(for: screenId)
        let response     = try await client.fetch(screenId: screenId, cachedKey: storedKey, dynamicKey: storedDynKey, category: category)

        if response.isDynamicHit {
            return try await handleDynamicHit(screenId: screenId, storedKey: storedKey, dynamicKey: response.dynamicKey)
        } else if response.isCacheHit {
            return try await handleCacheHit(response: response, screenId: screenId, storedKey: storedKey)
        } else {
            return try handleFullResponse(response: response, screenId: screenId)
        }
    }

    // MARK: - Private

    private func handleFullResponse(response: BDUIServerResponse, screenId: String) throws -> ScreenData {
        guard let ui         = response.ui,
              let static_    = ui.staticScreen,
              let cacheKey   = response.cacheKey,
              let dynamicKey = response.dynamicKey else {
            throw BDUIError.decodingFailed(
                NSError(domain: "BDUIScreenLoader", code: 0,
                        userInfo: [NSLocalizedDescriptionKey: "Full response missing required fields for screen '\(screenId)'"])
            )
        }
        cache.update(cacheKey: cacheKey, staticScreen: static_, for: screenId, dynamicKey: dynamicKey, dynamic: ui.dynamic)
        return ScreenData(staticScreen: static_, dynamic: ui.dynamic, cacheKey: cacheKey, dynamicKey: dynamicKey)
    }

    private func handleCacheHit(
        response: BDUIServerResponse,
        screenId: String,
        storedKey: String?
    ) async throws -> ScreenData {
        guard let staticScreen = cache.cachedStatic(for: screenId),
              let cacheKey     = storedKey,
              let ui           = response.ui,
              let dynamicKey   = response.dynamicKey else {
            // Local cache is missing required data — invalidate and refetch from scratch.
            cache.invalidate(for: screenId)
            return try await load(screenId: screenId, forceRefresh: false)
        }
        cache.updateDynamic(dynamicKey: dynamicKey, dynamic: ui.dynamic, for: screenId)
        return ScreenData(staticScreen: staticScreen, dynamic: ui.dynamic, cacheKey: cacheKey, dynamicKey: dynamicKey)
    }

    private func handleDynamicHit(screenId: String, storedKey: String?, dynamicKey: String?) async throws -> ScreenData {
        guard let staticScreen = cache.cachedStatic(for: screenId),
              let cacheKey     = storedKey,
              let dynamic      = cache.cachedDynamic(for: screenId),
              let dynKey       = dynamicKey else {
            // Local dynamic cache is gone — invalidate and refetch from scratch.
            cache.invalidate(for: screenId)
            return try await load(screenId: screenId, forceRefresh: false)
        }
        return ScreenData(staticScreen: staticScreen, dynamic: dynamic, cacheKey: cacheKey, dynamicKey: dynKey)
    }
}
