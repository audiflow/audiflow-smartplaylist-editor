use axum::extract::{Query, State};
use axum::Json;
use serde::Deserialize;
use url::form_urlencoded;

use crate::app::{AppError, SharedState};

#[derive(Deserialize)]
pub struct SearchQuery {
    pub term: Option<String>,
    pub limit: Option<u32>,
}

/// GET /api/podcasts/search?term=...&limit=25
///
/// Proxies to the iTunes Search API and returns podcast results.
pub async fn search_podcasts(
    State(state): State<SharedState>,
    Query(query): Query<SearchQuery>,
) -> Result<Json<serde_json::Value>, AppError> {
    let term = query
        .term
        .map(|t| t.trim().to_string())
        .filter(|t| !t.is_empty())
        .ok_or_else(|| AppError::bad_request("Missing required query parameter: term"))?;

    let limit = query.limit.unwrap_or(25).clamp(1, 200);

    let encoded_term: String = form_urlencoded::byte_serialize(term.as_bytes()).collect();
    let url = format!(
        "https://itunes.apple.com/search?media=podcast&term={encoded_term}&limit={limit}",
    );

    let response = state
        .http_client
        .get(&url)
        .send()
        .await
        .map_err(|e| AppError::bad_gateway(format!("iTunes API request failed: {e}")))?
        .error_for_status()
        .map_err(|e| AppError::bad_gateway(format!("iTunes API error: {e}")))?;

    let body: serde_json::Value = response
        .json()
        .await
        .map_err(|e| AppError::bad_gateway(format!("Failed to parse iTunes response: {e}")))?;

    Ok(Json(body))
}
