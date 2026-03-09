pub mod config;
pub mod events;
pub mod feed;
pub mod health;
pub mod preview;
pub mod schema;

use axum::routing::{get, post, put};
use axum::Router;
use tower_http::cors::CorsLayer;

use crate::app::SharedState;
use crate::static_files::static_handler;

/// Creates the Axum router with all API routes, CORS, and static
/// file fallback.
pub fn create_router(state: SharedState) -> Router {
    Router::new()
        .route("/api/health", get(health::health))
        .route("/api/schema", get(schema::get_schema))
        .route(
            "/api/configs/patterns",
            get(config::list_patterns).post(config::create_pattern),
        )
        .route(
            "/api/configs/patterns/{id}",
            get(config::get_pattern).delete(config::delete_pattern),
        )
        .route(
            "/api/configs/patterns/{id}/meta",
            put(config::update_pattern_meta),
        )
        .route(
            "/api/configs/patterns/{id}/assembled",
            get(config::get_assembled),
        )
        .route(
            "/api/configs/patterns/{id}/playlists/{pid}",
            get(config::get_playlist)
                .put(config::save_playlist)
                .delete(config::delete_playlist),
        )
        .route("/api/configs/validate", post(config::validate_config))
        .route("/api/configs/preview", post(preview::preview_config))
        .route("/api/feeds", get(feed::fetch_feed))
        .route("/api/events", get(events::sse_events))
        .fallback(static_handler)
        .layer(CorsLayer::permissive())
        .with_state(state)
}
