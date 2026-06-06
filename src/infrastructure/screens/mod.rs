mod catalog;
mod home;
mod product;
mod profile;
mod settings;

use crate::domain::{hashing::compute_cache_key, ui::StaticScreen};
use crate::infrastructure::screen_registry::ScreenRegistry;
use serde_json::Value;
use std::path::Path;

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

/// Reads dynamic data from a JSON file at runtime.
/// The path is relative to the cargo workspace root (where `cargo run` is executed).
/// Returns an empty object if the file is missing or malformed.
pub(super) fn read_dynamic(filename: &str) -> Value {
    let path = Path::new("src/infrastructure/screens/data").join(filename);
    match std::fs::read_to_string(&path) {
        Ok(contents) => serde_json::from_str(&contents).unwrap_or_else(|e| {
            eprintln!("BDUI: failed to parse {filename}: {e}");
            Value::Object(Default::default())
        }),
        Err(e) => {
            eprintln!("BDUI: could not read {filename}: {e}");
            Value::Object(Default::default())
        }
    }
}
