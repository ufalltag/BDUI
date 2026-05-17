pub mod event;

use std::collections::HashMap;
use std::sync::Mutex;
use serde::Serialize;
use event::{RequestEvent, RequestKind};

// ── Internal storage ──────────────────────────────────────────────────────────

#[derive(Default)]
struct Inner {
    first_count: u64,
    hit_count:   u64,
    miss_count:  u64,

    first_bytes: u64,
    hit_bytes:   u64,
    miss_bytes:  u64,
    bytes_saved: u64,

    first_ms: f64,
    hit_ms:   f64,
    miss_ms:  f64,

    per_screen: HashMap<String, ScreenStats>,
}

// ── Public snapshot types ─────────────────────────────────────────────────────

#[derive(Default, Clone, Serialize)]
pub struct ScreenStats {
    pub requests:       u64,
    pub first_requests: u64,
    pub cache_hits:     u64,
    pub cache_misses:   u64,
    pub bytes_sent:     u64,
    pub bytes_saved:    u64,
}

#[derive(Serialize)]
pub struct TypeStats {
    pub count:       u64,
    pub total_bytes: u64,
    pub avg_bytes:   f64,
    pub avg_ms:      f64,
}

#[derive(Serialize)]
pub struct MetricsSnapshot {
    pub total_requests:        u64,
    pub cache_hit_rate_pct:    f64,
    pub total_bytes_sent:      u64,
    pub total_bytes_saved:     u64,
    pub traffic_reduction_pct: f64,
    pub first:                 TypeStats,
    pub cache_hit:             TypeStats,
    pub cache_miss:            TypeStats,
    pub per_screen:            HashMap<String, ScreenStats>,
}

// ── Store ─────────────────────────────────────────────────────────────────────

#[derive(Default)]
pub struct Metrics(Mutex<Inner>);

impl Metrics {
    pub fn record(&self, ev: RequestEvent) {
        let mut d = self.0.lock().unwrap();

        let bytes = ev.bytes_sent as u64;
        let saved = ev.bytes_saved as u64;
        let ms    = ev.duration_ms;

        // Update global counters before taking per_screen borrow.
        match ev.kind {
            RequestKind::First => {
                d.first_count += 1; d.first_bytes += bytes; d.first_ms += ms;
            }
            RequestKind::CacheHit => {
                d.hit_count += 1; d.hit_bytes += bytes; d.hit_ms += ms;
                d.bytes_saved += saved;
            }
            RequestKind::CacheMiss => {
                d.miss_count += 1; d.miss_bytes += bytes; d.miss_ms += ms;
            }
        }

        let screen = d.per_screen.entry(ev.screen_id).or_default();
        screen.requests    += 1;
        screen.bytes_sent  += bytes;
        screen.bytes_saved += saved;
        match ev.kind {
            RequestKind::First     => screen.first_requests += 1,
            RequestKind::CacheHit  => screen.cache_hits     += 1,
            RequestKind::CacheMiss => screen.cache_misses   += 1,
        }
    }

    pub fn snapshot(&self) -> MetricsSnapshot {
        let d = self.0.lock().unwrap();

        let total       = d.first_count + d.hit_count + d.miss_count;
        let total_bytes = d.first_bytes + d.hit_bytes + d.miss_bytes;
        let would_have  = total_bytes + d.bytes_saved;

        MetricsSnapshot {
            total_requests:        total,
            cache_hit_rate_pct:    pct(d.hit_count, total),
            total_bytes_sent:      total_bytes,
            total_bytes_saved:     d.bytes_saved,
            traffic_reduction_pct: pct(d.bytes_saved, would_have),
            first: TypeStats {
                count: d.first_count, total_bytes: d.first_bytes,
                avg_bytes: avg(d.first_bytes, d.first_count),
                avg_ms:    avg_f(d.first_ms, d.first_count),
            },
            cache_hit: TypeStats {
                count: d.hit_count, total_bytes: d.hit_bytes,
                avg_bytes: avg(d.hit_bytes, d.hit_count),
                avg_ms:    avg_f(d.hit_ms, d.hit_count),
            },
            cache_miss: TypeStats {
                count: d.miss_count, total_bytes: d.miss_bytes,
                avg_bytes: avg(d.miss_bytes, d.miss_count),
                avg_ms:    avg_f(d.miss_ms, d.miss_count),
            },
            per_screen: d.per_screen.clone(),
        }
    }
}

fn avg(sum: u64, n: u64) -> f64   { if n == 0 { 0.0 } else { sum as f64 / n as f64 } }
fn avg_f(sum: f64, n: u64) -> f64 { if n == 0 { 0.0 } else { sum / n as f64 } }
fn pct(part: u64, total: u64) -> f64 {
    if total == 0 { 0.0 } else { part as f64 / total as f64 * 100.0 }
}
