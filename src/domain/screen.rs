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

    /// Returns dynamic data for an optional content variant (e.g. a catalog
    /// category). Default ignores the variant — screens that support variants
    /// (like the catalog) override this. The static layout never changes, so
    /// `cache_key` is unaffected; only the dynamic part (and `dynamic_key`) differ.
    fn dynamic_data_for(&self, _variant: Option<&str>) -> Value {
        self.dynamic_data()
    }

    /// Pre-computed serialized size of `full_response()`.
    /// Used to calculate bytes saved on cache hits.
    fn full_response_size(&self) -> usize;

    /// Builds a full protocol response for the default variant.
    fn full_response(&self) -> BduiFullResponse {
        self.full_response_for(None)
    }

    /// Builds a full protocol response for a specific content variant.
    fn full_response_for(&self, variant: Option<&str>) -> BduiFullResponse {
        let dynamic = self.dynamic_data_for(variant);
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
