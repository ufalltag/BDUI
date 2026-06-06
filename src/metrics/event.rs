#[derive(Debug, Clone, Copy, PartialEq)]
pub enum RequestKind {
    /// First-ever request for this screen — no cache_key sent.
    First,
    /// Client sent the correct cache_key — only dynamic data returned.
    CacheHit,
    /// Client sent a stale cache_key — full response returned.
    CacheMiss,
    /// Client sent matching cache_key AND dynamic_key — nothing returned (keys only).
    DynamicHit,
}

pub struct RequestEvent {
    pub screen_id: String,
    pub kind: RequestKind,
    /// Bytes actually written to the wire.
    pub bytes_sent: usize,
    /// Bytes saved vs. a naive full response (non-zero for CacheHit and DynamicHit).
    pub bytes_saved: usize,
    pub duration_ms: f64,
}
