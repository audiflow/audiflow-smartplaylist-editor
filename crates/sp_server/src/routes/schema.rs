use axum::extract::State;
use axum::http::header;
use axum::response::IntoResponse;

use crate::app::SharedState;

/// GET /api/schema -- returns the cached playlist-definition schema JSON.
pub async fn get_schema(State(state): State<SharedState>) -> impl IntoResponse {
    (
        [(header::CONTENT_TYPE, "application/json")],
        state.schema_json.clone(),
    )
}
