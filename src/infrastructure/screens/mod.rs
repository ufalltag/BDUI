mod catalog;
mod home;
mod product;
mod profile;
mod settings;

use crate::domain::ui::StaticScreen;
use crate::infrastructure::hashing::compute_cache_key;
use crate::infrastructure::screen_registry::ScreenRegistry;

/// Builds and returns the registry with all known screens.
/// To add a new screen: create a module, implement `Screen`, add `.register(NewScreen)` here.
pub fn register_all() -> ScreenRegistry {
    ScreenRegistry::new()
        .register(profile::ProfileScreen)
        .register(home::HomeScreen)
        .register(settings::SettingsScreen)
        .register(catalog::CatalogScreen)
        .register(product::ProductScreen)
}

/// Parses a static screen from compile-time embedded JSON and derives its cache key.
/// Called exactly once per screen via `LazyLock`.
pub(super) fn parse_static(json: &str, label: &str) -> (StaticScreen, String) {
    let screen: StaticScreen =
        serde_json::from_str(json).unwrap_or_else(|e| panic!("{label}: {e}"));
    let key = compute_cache_key(&screen);
    (screen, key)
}
