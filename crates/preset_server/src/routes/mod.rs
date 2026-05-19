pub mod config;
pub mod derive;
pub mod events;
pub mod feed;
pub mod health;
pub mod identifiers;
pub mod podcast;
pub mod preview;
pub mod schema;

use axum::Router;
use axum::http::StatusCode;
use axum::response::IntoResponse;
use axum::routing::{get, post, put};
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
            "/configs/presets",
            get(config::list_presets).post(config::create_preset),
        )
        .route(
            "/configs/presets/identifiers",
            get(identifiers::list_preset_identifiers),
        )
        .route(
            "/configs/derive-pattern-id",
            post(derive::derive_preset_id_handler),
        )
        .route(
            "/configs/presets/{id}",
            get(config::get_preset).delete(config::delete_preset),
        )
        .route(
            "/configs/presets/{id}/meta",
            put(config::update_preset_meta),
        )
        .route(
            "/configs/presets/{id}/assembled",
            get(config::get_assembled),
        )
        .route(
            "/configs/presets/{id}/playlists/{pid}",
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
