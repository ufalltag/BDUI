import Foundation

/// Persists cache_key, static screen structure, dynamic data, and timestamp per screen ID.
/// Thread-safe: UserDefaults is safe to read/write from any thread.
public final class BDUICache {
    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(suiteName: String? = nil) {
        self.defaults = suiteName.flatMap(UserDefaults.init(suiteName:)) ?? .standard
    }

    // MARK: - Read

    public func cachedKey(for screenId: String) -> String? {
        defaults.string(forKey: keyForCacheKey(screenId))
    }

    public func cachedStatic(for screenId: String) -> StaticScreen? {
        guard let data = defaults.data(forKey: keyForStatic(screenId)) else { return nil }
        return try? decoder.decode(StaticScreen.self, from: data)
    }

    public func cachedDynamicKey(for screenId: String) -> String? {
        defaults.string(forKey: keyForDynamicKey(screenId))
    }

    public func cachedDynamic(for screenId: String) -> JSONValue? {
        guard let data = defaults.data(forKey: keyForDynamic(screenId)) else { return nil }
        return try? decoder.decode(JSONValue.self, from: data)
    }

    /// Returns true if the cache entry is older than `maxAge` seconds, or was never stored.
    public func isExpired(for screenId: String, maxAge: TimeInterval) -> Bool {
        let timestamp = defaults.double(forKey: keyForTimestamp(screenId))
        guard timestamp > 0 else { return true }
        return Date().timeIntervalSince1970 - timestamp > maxAge
    }

    // MARK: - Write

    /// Called after a full server response — stores static, dynamic, keys, and current timestamp.
    public func update(
        cacheKey: String,
        staticScreen: StaticScreen,
        for screenId: String,
        dynamicKey: String? = nil,
        dynamic: JSONValue? = nil
    ) {
        defaults.set(cacheKey, forKey: keyForCacheKey(screenId))
        defaults.set(Date().timeIntervalSince1970, forKey: keyForTimestamp(screenId))
        if let data = try? encoder.encode(staticScreen) {
            defaults.set(data, forKey: keyForStatic(screenId))
        }
        if let dk = dynamicKey {
            defaults.set(dk, forKey: keyForDynamicKey(screenId))
        }
        if let dyn = dynamic, let data = try? encoder.encode(dyn) {
            defaults.set(data, forKey: keyForDynamic(screenId))
        }
    }

    /// Called after a cache hit — updates only the dynamic data (static is unchanged).
    public func updateDynamic(dynamicKey: String, dynamic: JSONValue, for screenId: String) {
        defaults.set(dynamicKey, forKey: keyForDynamicKey(screenId))
        if let data = try? encoder.encode(dynamic) {
            defaults.set(data, forKey: keyForDynamic(screenId))
        }
    }

    /// Wipes all cached data for a screen — forces a full fetch on the next load.
    public func invalidate(for screenId: String) {
        defaults.removeObject(forKey: keyForCacheKey(screenId))
        defaults.removeObject(forKey: keyForStatic(screenId))
        defaults.removeObject(forKey: keyForTimestamp(screenId))
        defaults.removeObject(forKey: keyForDynamicKey(screenId))
        defaults.removeObject(forKey: keyForDynamic(screenId))
    }

    // MARK: - Keys

    private func keyForCacheKey(_ id: String)   -> String { "bdui.key.\(id)" }
    private func keyForStatic(_ id: String)     -> String { "bdui.static.\(id)" }
    private func keyForTimestamp(_ id: String)  -> String { "bdui.ts.\(id)" }
    private func keyForDynamicKey(_ id: String) -> String { "bdui.dynkey.\(id)" }
    private func keyForDynamic(_ id: String)    -> String { "bdui.dyn.\(id)" }
}
