pub mod config;
pub mod derive;
pub mod events;
pub mod feed;
pub mod health;
pub mod identifiers;
pub mod podcast;
pub mod preview;
pub mod schema;

use axum::http::StatusCode;
use axum::response::IntoResponse;
use axum::routing::{get, post, put};
use axum::Router;
use tower_http::cors::CorsLayer;

use crate::app::SharedState;
use crate::static_files::static_handler;

/// Returns 404 JSON for any unmatched `/api/*` path, preventing the
/// SPA fallback from serving `index.html` for misspelled API routes.
async fn api_fallback() -> impl IntoResponse {
    (
        StatusCode::NOT_FOUND,
        axum::Json(serde_json::json!({ "error": "Not found" })),
    )
}

/// Creates the Axum router with all API routes, CORS, and static
/// file fallback.
pub fn create_router(state: SharedState) -> Router {
    let api_routes = Router::new()
        .route("/health", get(health::health))
        .route("/schema", get(schema::get_schema))
        .route(
            "/configs/patterns",
            get(config::list_patterns).post(config::create_pattern),
        )
        .route(
            "/configs/patterns/identifiers",
            get(identifiers::list_pattern_identifiers),
        )
        .route(
            "/configs/derive-pattern-id",
            post(derive::derive_pattern_id_handler),
        )
        .route(
            "/configs/patterns/{id}",
            get(config::get_pattern).delete(config::delete_pattern),
        )
        .route(
            "/configs/patterns/{id}/meta",
            put(config::update_pattern_meta),
        )
        .route(
            "/configs/patterns/{id}/assembled",
            get(config::get_assembled),
        )
        .route(
            "/configs/patterns/{id}/playlists/{pid}",
            get(config::get_playlist)
                .put(config::save_playlist)
                .delete(config::delete_playlist),
        )
        .route("/configs/validate", post(config::validate_config))
        .route("/configs/preview", post(preview::preview_config))
        .route("/feeds", get(feed::fetch_feed))
        .route("/podcasts/search", get(podcast::search_podcasts))
        .route("/events", get(events::sse_events))
        .fallback(api_fallback);

    Router::new()
        .nest("/api", api_routes)
        .fallback(static_handler)
        .layer(CorsLayer::permissive())
        .with_state(state)
}
