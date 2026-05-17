use axum::{extract::State, response::{IntoResponse, Json}};
use crate::server::state::AppState;

pub async fn handle(State(state): State<AppState>) -> impl IntoResponse {
    Json(state.metrics.snapshot())
}
