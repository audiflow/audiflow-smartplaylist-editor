use axum::extract::{Query, State};
use axum::Json;

use crate::app::{AppError, SharedState};

#[derive(serde::Deserialize)]
pub struct FeedQuery {
    pub url: Option<String>,
}

/// GET /api/feeds?url=... -- fetches and parses an RSS feed, returning
/// episodes as JSON.
pub async fn fetch_feed(
    State(state): State<SharedState>,
    Query(query): Query<FeedQuery>,
) -> Result<Json<serde_json::Value>, AppError> {
    let url = query
        .url
        .filter(|u| !u.is_empty())
        .ok_or_else(|| AppError::bad_request("Missing required query parameter: url"))?;

    // Basic URL validation
    let parsed = url::Url::parse(&url)
        .map_err(|_| AppError::bad_request("Invalid URL"))?;
    if parsed.scheme().is_empty() {
        return Err(AppError::bad_request("Invalid URL"));
    }

    let episodes = state
        .feed_cache
        .fetch_feed(&url, &state.http_client)
        .await
        .map_err(|e| AppError::internal(format!("Failed to fetch feed: {e}")))?;

    Ok(Json(serde_json::json!({ "episodes": episodes })))
}
