use axum::{extract::State, response::{IntoResponse, Json}};
use crate::domain::{
    models::{BduiMetaResponse, ScreenMeta},
    protocol,
};
use crate::server::state::AppState;

pub async fn handle(State(state): State<AppState>) -> impl IntoResponse {
    let screens = state
        .screen_service
        .all_screen_ids()
        .into_iter()
        .map(|id| ScreenMeta {
            id,
            endpoint: format!("/bdui/screen/{id}"),
        })
        .collect();

    Json(BduiMetaResponse {
        protocol_version: protocol::CURRENT,
        supported_versions: protocol::SUPPORTED.to_vec(),
        screens,
    })
}
