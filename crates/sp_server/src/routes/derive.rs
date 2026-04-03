use axum::Json;
use serde_json::Value;
use sp_core::services::derive_pattern_id;

use crate::app::AppError;

/// POST /api/configs/derive-pattern-id
///
/// Derives a deterministic pattern ID from the given podcast identity.
/// Returns the derived ID and which source field was used.
///
/// Request:  `{ "podcastGuid": "...", "feedUrls": ["..."] }`
/// Response: `{ "id": "a1b2c3d4e5f6", "source": "podcastGuid" | "feedUrls" }`
pub async fn derive_pattern_id_handler(
    Json(body): Json<Value>,
) -> Result<Json<Value>, AppError> {
    if !body.is_object() {
        return Err(AppError::bad_request("Request body must be a JSON object"));
    }

    let guid = body
        .get("podcastGuid")
        .and_then(|v| v.as_str())
        .filter(|s| !s.is_empty());

    let feed_urls: Vec<String> = body
        .get("feedUrls")
        .and_then(|v| v.as_array())
        .map(|arr| {
            arr.iter()
                .filter_map(|v| v.as_str())
                .filter(|s| !s.is_empty())
                .map(|s| s.to_string())
                .collect()
        })
        .unwrap_or_default();

    let has_guid = guid.is_some();
    let id = derive_pattern_id(guid, &feed_urls).ok_or_else(|| {
        AppError::bad_request(
            "Cannot derive pattern ID: provide a non-empty podcastGuid or at least one feedUrls entry",
        )
    })?;

    let source = if has_guid { "podcastGuid" } else { "feedUrls" };

    Ok(Json(serde_json::json!({
        "id": id,
        "source": source,
    })))
}
