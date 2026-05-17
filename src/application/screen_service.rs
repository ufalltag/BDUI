use std::sync::Arc;
use crate::domain::{
    models::{BduiCacheHitResponse, DynamicOnly},
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

/// Encapsulates the cache-hit / cache-miss / first-request decision.
/// Knows nothing about HTTP — takes IDs and keys, returns bytes.
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
    ) -> Result<ScreenResult, ScreenError> {
        let screen = self.repository.find(screen_id).ok_or(ScreenError::NotFound)?;

        let (bytes, kind, bytes_saved) = match client_cache_key {
            Some(key) if key == screen.cache_key() => {
                // ── Cache hit ─────────────────────────────────────────────────
                let response = BduiCacheHitResponse {
                    protocol_version: protocol::CURRENT,
                    ui: DynamicOnly { dynamic: screen.dynamic_data() },
                };
                let bytes = serde_json::to_vec(&response).unwrap();
                let saved = screen.full_response_size().saturating_sub(bytes.len());
                (bytes, RequestKind::CacheHit, saved)
            }
            Some(_) => {
                // ── Cache miss (stale key) ────────────────────────────────────
                let bytes = serde_json::to_vec(&screen.full_response()).unwrap();
                (bytes, RequestKind::CacheMiss, 0)
            }
            None => {
                // ── First request ─────────────────────────────────────────────
                let bytes = serde_json::to_vec(&screen.full_response()).unwrap();
                (bytes, RequestKind::First, 0)
            }
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
