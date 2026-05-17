mod application;
mod domain;
mod infrastructure;
mod metrics;
mod server;

use std::sync::Arc;
use application::ScreenService;
use infrastructure::screens::register_all;
use metrics::Metrics;
use server::state::AppState;

#[tokio::main]
async fn main() {
    tracing_subscriber::fmt()
        .with_target(false)
        .with_env_filter(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| "bdui_server=info".parse().unwrap()),
        )
        .init();

    let registry = Arc::new(register_all());
    let screen_service = Arc::new(ScreenService::new(registry));
    let metrics = Arc::new(Metrics::default());

    let state = AppState { screen_service, metrics };
    let app = server::build_router(state);

    let listener = tokio::net::TcpListener::bind("0.0.0.0:3000")
        .await
        .expect("failed to bind port 3000");

    tracing::info!("BDUI server (protocol v{}) → http://localhost:3000", domain::protocol::CURRENT);
    tracing::info!("  GET /bdui/screen/:id              → full / cached response");
    tracing::info!("  GET /bdui/screen/:id?cache_key=…  → dynamic only on hit");
    tracing::info!("  GET /bdui/meta                    → protocol metadata");
    tracing::info!("  GET /metrics                      → aggregated stats");

    axum::serve(listener, app).await.expect("server error");
}
