use std::time::Instant;
use axum::{
    extract::{Path, Query, State},
    http::{HeaderMap, StatusCode},
    response::IntoResponse,
};
use serde::Deserialize;
use crate::domain::protocol;
use crate::metrics::event::RequestKind;
use crate::server::{error::AppError, state::AppState};

#[derive(Deserialize)]
pub struct ScreenParams {
    cache_key: Option<String>,
    dynamic_key: Option<String>,
}

pub async fn handle(
    State(state): State<AppState>,
    Path(screen_id): Path<String>,
    Query(params): Query<ScreenParams>,
    headers: HeaderMap,
) -> Result<impl IntoResponse, AppError> {
    validate_version(&headers)?;

    let start = Instant::now();
    let result = state
        .screen_service
        .handle(
            &screen_id,
            params.cache_key.as_deref(),
            params.dynamic_key.as_deref(),
        )
        .map_err(AppError::from)?;

    let duration_ms = start.elapsed().as_secs_f64() * 1000.0;
    let (bytes, event) = result.into_event(screen_id, duration_ms);

    let cache_status = match event.kind {
        RequestKind::First      => "first",
        RequestKind::CacheHit   => "hit",
        RequestKind::CacheMiss  => "miss",
        RequestKind::DynamicHit => "dynamic_hit",
    };

    tracing::info!(
        screen = %event.screen_id,
        kind   = ?event.kind,
        sent   = event.bytes_sent,
        saved  = event.bytes_saved,
        ms     = format!("{:.3}", event.duration_ms),
    );

    state.metrics.record(event);

    Ok((
        StatusCode::OK,
        [
            ("content-type",        "application/json"),
            ("x-bdui-cache-status", cache_status),
        ],
        bytes,
    ))
}

/// Returns `Err` if the client sends an `X-BDUI-Version` header with an
/// unsupported version number. Absent header = assume current version (graceful).
fn validate_version(headers: &HeaderMap) -> Result<(), AppError> {
    let Some(value) = headers.get("X-BDUI-Version") else {
        return Ok(());
    };
    let version: u8 = value
        .to_str()
        .ok()
        .and_then(|s| s.parse().ok())
        .unwrap_or(0);

    if protocol::SUPPORTED.contains(&version) {
        Ok(())
    } else {
        Err(AppError::UnsupportedVersion { client_version: version })
    }
}
