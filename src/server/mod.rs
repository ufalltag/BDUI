pub mod error;
pub mod handlers;
pub mod state;

use axum::{Router, routing::get};
use state::AppState;

pub fn build_router(state: AppState) -> Router {
    Router::new()
        .route("/bdui/screen/{screen_id}", get(handlers::screen::handle))
        .route("/bdui/meta",               get(handlers::meta::handle))
        .route("/metrics",                 get(handlers::metrics::handle))
        .with_state(state)
}
