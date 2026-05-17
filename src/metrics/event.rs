#[derive(Debug, Clone, Copy)]
pub enum RequestKind {
    /// First-ever request for this screen — no cache_key sent.
    First,
    /// Client sent the correct cache_key — only dynamic data returned.
    CacheHit,
    /// Client sent a stale cache_key — full response returned.
    CacheMiss,
}

pub struct RequestEvent {
    pub screen_id: String,
    pub kind: RequestKind,
    /// Bytes actually written to the wire.
    pub bytes_sent: usize,
    /// Bytes saved vs. a naive full response (non-zero only for CacheHit).
    pub bytes_saved: usize,
    pub duration_ms: f64,
}
