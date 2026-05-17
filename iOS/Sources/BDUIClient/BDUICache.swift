import Foundation

/// Persists cache_key and static screen structure per screen ID.
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

    // MARK: - Write

    /// Called after a full server response — stores both key and layout.
    public func update(cacheKey: String, staticScreen: StaticScreen, for screenId: String) {
        defaults.set(cacheKey, forKey: keyForCacheKey(screenId))
        if let data = try? encoder.encode(staticScreen) {
            defaults.set(data, forKey: keyForStatic(screenId))
        }
    }

    /// Wipes cached data — forces a full fetch on the next load.
    public func invalidate(for screenId: String) {
        defaults.removeObject(forKey: keyForCacheKey(screenId))
        defaults.removeObject(forKey: keyForStatic(screenId))
    }

    // MARK: - Keys

    private func keyForCacheKey(_ id: String) -> String { "bdui.key.\(id)" }
    private func keyForStatic(_ id: String) -> String   { "bdui.static.\(id)" }
}
