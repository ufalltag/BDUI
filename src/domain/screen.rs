use serde_json::Value;
use crate::domain::{
    hashing::compute_cache_key,
    models::{BduiFullResponse, UiParts},
    protocol,
    ui::StaticScreen,
};

/// Contract every screen must satisfy.
///
/// Implementors provide the static layout and the current dynamic data;
/// the default methods compose them — Template Method pattern.
pub trait Screen: Send + Sync {
    fn id(&self) -> &'static str;
    fn cache_key(&self) -> &'static str;
    fn static_screen(&self) -> &'static StaticScreen;
    fn dynamic_data(&self) -> Value;

    /// SHA-256 hash of the current dynamic data.
    /// Used by the service to detect dynamic-level cache hits.
    fn dynamic_key(&self) -> String {
        compute_cache_key(&self.dynamic_data())
    }

    /// Pre-computed serialized size of `full_response()`.
    /// Used to calculate bytes saved on cache hits.
    fn full_response_size(&self) -> usize;

    /// Builds a full protocol response. Rarely overridden.
    fn full_response(&self) -> BduiFullResponse {
        let dynamic = self.dynamic_data();
        let dynamic_key = compute_cache_key(&dynamic);
        BduiFullResponse {
            protocol_version: protocol::CURRENT,
            ui: UiParts {
                static_part: self.static_screen().clone(),
                dynamic,
            },
            cache_key: self.cache_key().to_owned(),
            dynamic_key,
        }
    }
}

/// Abstraction over the screen store. Handlers depend on this, never on
/// concrete implementations — Dependency Inversion principle.
pub trait ScreenRepository: Send + Sync {
    fn find(&self, id: &str) -> Option<&dyn Screen>;
    fn all_ids(&self) -> Vec<&'static str>;
}
