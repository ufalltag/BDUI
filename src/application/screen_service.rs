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

    /// Convenience wrapper for the default variant. Used by the test suite;
    /// production always goes through [`ScreenService::handle_with`].
    #[cfg(test)]
    pub fn handle(
        &self,
        screen_id: &str,
        client_cache_key: Option<&str>,
        client_dynamic_key: Option<&str>,
    ) -> Result<ScreenResult, ScreenError> {
        self.handle_with(screen_id, client_cache_key, client_dynamic_key, None)
    }

    /// Like [`ScreenService::handle`], but for a specific content variant
    /// (e.g. a catalog category). The variant only affects the dynamic part —
    /// the static layout and its `cache_key` are identical across variants.
    pub fn handle_with(
        &self,
        screen_id: &str,
        client_cache_key: Option<&str>,
        client_dynamic_key: Option<&str>,
        variant: Option<&str>,
    ) -> Result<ScreenResult, ScreenError> {
        let screen = self.repository.find(screen_id).ok_or(ScreenError::NotFound)?;

        let static_matched = client_cache_key
            .map(|k| k == screen.cache_key())
            .unwrap_or(false);

        let (bytes, kind, bytes_saved) = if static_matched {
            // Compute dynamic data and its key only when static already matched.
            let dynamic = screen.dynamic_data_for(variant);
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
                let bytes = serde_json::to_vec(&response).expect("BduiDynamicHitResponse serialization is infallible");
                let saved = screen.full_response_size().saturating_sub(bytes.len());
                (bytes, RequestKind::DynamicHit, saved)
            } else {
                // ── Level 2: Cache hit — static unchanged, return fresh dynamic ─
                let response = BduiCacheHitResponse {
                    protocol_version: protocol::CURRENT,
                    dynamic_key: current_dynamic_key,
                    ui: DynamicOnly { dynamic },
                };
                let bytes = serde_json::to_vec(&response).expect("BduiCacheHitResponse serialization is infallible");
                let saved = screen.full_response_size().saturating_sub(bytes.len());
                (bytes, RequestKind::CacheHit, saved)
            }
        } else {
            // ── Level 1: Full response — first request or stale cache_key ──────
            let bytes = serde_json::to_vec(&screen.full_response_for(variant)).expect("BduiFullResponse serialization is infallible");
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

// ── Simulation / integration tests (Point 12) ─────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;
    use crate::infrastructure::screens::register_all;
    use serde_json::Value;

    fn make_service() -> ScreenService {
        ScreenService::new(Arc::new(register_all()))
    }

    /// Extracts (cache_key, dynamic_key) from a serialized full-response payload.
    fn extract_keys(bytes: &[u8]) -> (Option<String>, Option<String>) {
        let v: Value = serde_json::from_slice(bytes).unwrap();
        (
            v["cache_key"].as_str().map(String::from),
            v["dynamic_key"].as_str().map(String::from),
        )
    }

    // ── Correctness ───────────────────────────────────────────────────────────

    #[test]
    fn first_request_returns_full_response() {
        let svc = make_service();
        let r = svc.handle("profile", None, None).unwrap();
        assert_eq!(r.kind, RequestKind::First);
        assert_eq!(r.bytes_saved, 0);
    }

    #[test]
    fn correct_cache_key_returns_cache_hit() {
        let svc = make_service();
        let r1 = svc.handle("profile", None, None).unwrap();
        let (cache_key, _) = extract_keys(&r1.bytes);

        let r2 = svc.handle("profile", cache_key.as_deref(), None).unwrap();
        assert_eq!(r2.kind, RequestKind::CacheHit);
    }

    #[test]
    fn both_keys_correct_returns_dynamic_hit() {
        let svc = make_service();
        let r1 = svc.handle("profile", None, None).unwrap();
        let (cache_key, dynamic_key) = extract_keys(&r1.bytes);

        let r2 = svc.handle("profile", cache_key.as_deref(), dynamic_key.as_deref()).unwrap();
        assert_eq!(r2.kind, RequestKind::DynamicHit);
    }

    #[test]
    fn stale_cache_key_returns_cache_miss() {
        let svc = make_service();
        let r = svc.handle("profile", Some("stale_key_xyz"), None).unwrap();
        assert_eq!(r.kind, RequestKind::CacheMiss);
        assert_eq!(r.bytes_saved, 0);
    }

    #[test]
    fn unknown_screen_returns_not_found() {
        let svc = make_service();
        assert!(matches!(svc.handle("nonexistent", None, None), Err(ScreenError::NotFound)));
    }

    #[test]
    fn all_screens_respond_to_first_request() {
        let svc = make_service();
        for id in svc.all_screen_ids() {
            let r = svc.handle(id, None, None).unwrap();
            assert_eq!(r.kind, RequestKind::First, "screen '{id}' should return First");
            assert!(!r.bytes.is_empty());
        }
    }

    // ── Efficiency ────────────────────────────────────────────────────────────

    #[test]
    fn dynamic_hit_sends_fewer_bytes_than_cache_hit() {
        let svc = make_service();
        let r1 = svc.handle("profile", None, None).unwrap();
        let (ck, dk) = extract_keys(&r1.bytes);

        let r_hit = svc.handle("profile", ck.as_deref(), None).unwrap();
        let r_dyn = svc.handle("profile", ck.as_deref(), dk.as_deref()).unwrap();

        assert!(r_dyn.bytes.len() < r_hit.bytes.len(),
            "DynamicHit ({} B) should be smaller than CacheHit ({} B)",
            r_dyn.bytes.len(), r_hit.bytes.len());
    }

    #[test]
    fn dynamic_hit_saves_more_bytes_than_cache_hit() {
        let svc = make_service();
        let r1 = svc.handle("profile", None, None).unwrap();
        let (ck, dk) = extract_keys(&r1.bytes);

        let r_hit = svc.handle("profile", ck.as_deref(), None).unwrap();
        let r_dyn = svc.handle("profile", ck.as_deref(), dk.as_deref()).unwrap();

        assert!(r_dyn.bytes_saved > r_hit.bytes_saved,
            "DynamicHit ({} B saved) should save more than CacheHit ({} B saved)",
            r_dyn.bytes_saved, r_hit.bytes_saved);
    }

    #[test]
    fn all_screens_cache_hit_saves_positive_bytes() {
        let svc = make_service();
        for id in svc.all_screen_ids() {
            let r1 = svc.handle(id, None, None).unwrap();
            let (ck, dk) = extract_keys(&r1.bytes);

            let r_hit = svc.handle(id, ck.as_deref(), None).unwrap();
            assert!(r_hit.bytes_saved > 0, "screen '{id}' CacheHit should save bytes");

            let r_dyn = svc.handle(id, ck.as_deref(), dk.as_deref()).unwrap();
            assert!(r_dyn.bytes_saved > 0, "screen '{id}' DynamicHit should save bytes");
        }
    }

    // ── Simulation: realistic session ─────────────────────────────────────────

    /// Simulates a user opening the same screen 10 times in one session.
    /// Pattern: 1× First, 9× DynamicHit (data does not change during test).
    /// Asserts that traffic reduction vs naive (always full) is > 80 %.
    #[test]
    fn simulation_repeated_access_traffic_reduction_above_80_pct() {
        let svc = make_service();
        let r1 = svc.handle("profile", None, None).unwrap();
        let full_size = r1.bytes.len();
        let (ck, dk) = extract_keys(&r1.bytes);

        let mut total_sent     = full_size;
        let mut total_baseline = full_size;

        for _ in 0..9 {
            total_baseline += full_size;
            let r = svc.handle("profile", ck.as_deref(), dk.as_deref()).unwrap();
            total_sent += r.bytes.len();
        }

        let reduction_pct = (1.0 - total_sent as f64 / total_baseline as f64) * 100.0;
        assert!(
            reduction_pct > 80.0,
            "Expected >80% traffic reduction for repeated access, got {reduction_pct:.1}%"
        );
    }

    /// Simulates a session where static layout never changes but dynamic data
    /// changes once mid-session (e.g. follower count updates).
    /// Pattern: 1× First, 3× DynamicHit, 1× CacheHit (simulated via None dynamic_key),
    /// 5× DynamicHit.
    #[test]
    fn simulation_mixed_session_traffic_reduction_above_60_pct() {
        let svc = make_service();
        let r1 = svc.handle("profile", None, None).unwrap();
        let full_size = r1.bytes.len();
        let (ck, dk) = extract_keys(&r1.bytes);

        let mut total_sent     = full_size;
        let mut total_baseline = full_size;

        // 3 × DynamicHit
        for _ in 0..3 {
            total_baseline += full_size;
            let r = svc.handle("profile", ck.as_deref(), dk.as_deref()).unwrap();
            total_sent += r.bytes.len();
        }
        // 1 × CacheHit (simulating dynamic data refresh — client drops dynamic_key)
        total_baseline += full_size;
        let r_hit = svc.handle("profile", ck.as_deref(), None).unwrap();
        let (_, new_dk) = extract_keys(&r_hit.bytes);
        total_sent += r_hit.bytes.len();

        let dk2 = new_dk.as_deref().or(dk.as_deref());

        // 5 × DynamicHit again
        for _ in 0..5 {
            total_baseline += full_size;
            let r = svc.handle("profile", ck.as_deref(), dk2).unwrap();
            total_sent += r.bytes.len();
        }

        let reduction_pct = (1.0 - total_sent as f64 / total_baseline as f64) * 100.0;
        assert!(
            reduction_pct > 60.0,
            "Expected >60% traffic reduction for mixed session, got {reduction_pct:.1}%"
        );
    }

    /// Verifies that the cache hit rate across all screens is 100 % after warm-up.
    #[test]
    fn simulation_cache_hit_rate_100_pct_after_warmup() {
        let svc = make_service();
        let mut cache_hits = 0;
        let total = 5 * svc.all_screen_ids().len();

        for id in svc.all_screen_ids() {
            let r1 = svc.handle(id, None, None).unwrap();
            let (ck, dk) = extract_keys(&r1.bytes);
            for _ in 0..5 {
                let r = svc.handle(id, ck.as_deref(), dk.as_deref()).unwrap();
                if matches!(r.kind, RequestKind::DynamicHit) {
                    cache_hits += 1;
                }
            }
        }
        assert_eq!(cache_hits, total, "All repeat requests should be DynamicHit after warm-up");
    }
}
