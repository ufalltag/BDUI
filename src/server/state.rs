use std::sync::Arc;
use crate::application::ScreenService;
use crate::metrics::Metrics;

/// Shared application state injected into every handler via axum's `State` extractor.
#[derive(Clone)]
pub struct AppState {
    pub screen_service: Arc<ScreenService>,
    pub metrics: Arc<Metrics>,
}
