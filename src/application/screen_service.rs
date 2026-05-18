use std::sync::Arc;
use crate::domain::{
    hashing::compute_cache_key,
    models::{BduiCacheHitResponse, BduiDynamicHitResponse, DynamicOnly},
    protocol,
    screen::ScreenRepository,
};
use crate::metrics::event::{RequestEvent, RequestKind};

// ── Result ────────────────────────────────────────────────────────────────────

pub struct ScreenResult {
    /// Serialized response bytes, ready to write to the wire.
    pub bytes: Vec<u8>,
    pub kind: RequestKind,
    pub bytes_saved: usize,
}

// ── Error ─────────────────────────────────────────────────────────────────────

#[derive(Debug)]
pub enum ScreenError {
    NotFound,
}

// ── Service ───────────────────────────────────────────────────────────────────

/// Encapsulates the four cache decision levels:
///   First      → full response (no prior key)
///   CacheMiss  → full response (stale cache_key)
///   CacheHit   → dynamic only (cache_key matched, dynamic may have changed)
///   DynamicHit → keys only    (both cache_key and dynamic_key matched)
pub struct ScreenService {
    repository: Arc<dyn ScreenRepository>,
}

impl ScreenService {
    pub fn new(repository: Arc<dyn ScreenRepository>) -> Self {
        Self { repository }
    }

    pub fn handle(
        &self,
        screen_id: &str,
        client_cache_key: Option<&str>,
        client_dynamic_key: Option<&str>,
    ) -> Result<ScreenResult, ScreenError> {
        let screen = self.repository.find(screen_id).ok_or(ScreenError::NotFound)?;

        let static_matched = client_cache_key
            .map(|k| k == screen.cache_key())
            .unwrap_or(false);

        let (bytes, kind, bytes_saved) = if static_matched {
            // Compute dynamic data and its key only when static already matched.
            let dynamic = screen.dynamic_data();
            let current_dynamic_key = compute_cache_key(&dynamic);

            let dynamic_matched = client_dynamic_key
                .map(|k| k == current_dynamic_key)
                .unwrap_or(false);

            if dynamic_matched {
                // ── Level 3: Dynamic hit — nothing has changed ─────────────────
                let response = BduiDynamicHitResponse {
                    protocol_version: protocol::CURRENT,
                    cache_key: screen.cache_key().to_owned(),
                    dynamic_key: current_dynamic_key,
                };
                let bytes = serde_json::to_vec(&response).unwrap();
                let saved = screen.full_response_size().saturating_sub(bytes.len());
                (bytes, RequestKind::DynamicHit, saved)
            } else {
                // ── Level 2: Cache hit — static unchanged, return fresh dynamic ─
                let response = BduiCacheHitResponse {
                    protocol_version: protocol::CURRENT,
                    dynamic_key: current_dynamic_key,
                    ui: DynamicOnly { dynamic },
                };
                let bytes = serde_json::to_vec(&response).unwrap();
                let saved = screen.full_response_size().saturating_sub(bytes.len());
                (bytes, RequestKind::CacheHit, saved)
            }
        } else {
            // ── Level 1: Full response — first request or stale cache_key ──────
            let bytes = serde_json::to_vec(&screen.full_response()).unwrap();
            let kind = if client_cache_key.is_some() {
                RequestKind::CacheMiss
            } else {
                RequestKind::First
            };
            (bytes, kind, 0)
        };

        Ok(ScreenResult { bytes, kind, bytes_saved })
    }

    pub fn all_screen_ids(&self) -> Vec<&'static str> {
        self.repository.all_ids()
    }
}

// ── RequestEvent builder helper ───────────────────────────────────────────────

impl ScreenResult {
    pub fn into_event(self, screen_id: String, duration_ms: f64) -> (Vec<u8>, RequestEvent) {
        let event = RequestEvent {
            screen_id,
            kind: self.kind,
            bytes_sent: self.bytes.len(),
            bytes_saved: self.bytes_saved,
            duration_ms,
        };
        (self.bytes, event)
    }
}
