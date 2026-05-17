use serde::{Deserialize, Serialize};
use serde_json::Value;
use crate::domain::ui::StaticScreen;

// ── Full response (first request or cache miss) ───────────────────────────────

#[derive(Serialize)]
pub struct BduiFullResponse {
    pub protocol_version: u8,
    pub ui: UiParts,
    pub cache_key: String,
}

#[derive(Serialize)]
pub struct UiParts {
    #[serde(rename = "static")]
    pub static_part: StaticScreen,
    pub dynamic: Value,
}

// ── Cache-hit response (client key matched) ───────────────────────────────────

#[derive(Serialize)]
pub struct BduiCacheHitResponse {
    pub protocol_version: u8,
    pub ui: DynamicOnly,
}

#[derive(Serialize)]
pub struct DynamicOnly {
    pub dynamic: Value,
}

// ── Meta endpoint ─────────────────────────────────────────────────────────────

#[derive(Serialize)]
pub struct BduiMetaResponse {
    pub protocol_version: u8,
    pub supported_versions: Vec<u8>,
    pub screens: Vec<ScreenMeta>,
}

#[derive(Serialize)]
pub struct ScreenMeta {
    pub id: &'static str,
    pub endpoint: String,
}

// ── Error responses ───────────────────────────────────────────────────────────

#[derive(Serialize, Deserialize)]
pub struct BduiVersionError {
    pub error: &'static str,
    pub client_version: u8,
    pub supported_versions: Vec<u8>,
}
