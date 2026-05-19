use axum::Json;
use axum::extract::State;
use serde::Serialize;
use serde_json::Value;

use crate::app::{AppError, SharedState};

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct PatternIdentifiers {
    id: String,
    podcast_guid: Option<String>,
    feed_urls: Vec<String>,
}

/// GET /api/configs/presets/identifiers -- returns podcast identifiers
/// for all patterns. Used by the frontend to detect duplicates while
/// the user edits podcastGuid / feedUrls fields.
pub async fn list_preset_identifiers(
    State(state): State<SharedState>,
) -> Result<Json<Value>, AppError> {
    let summaries = state.config_repo.list_presets()?;
    let mut result = Vec::with_capacity(summaries.len());

    for summary in &summaries {
        if let Ok(meta) = state.config_repo.get_preset_meta(&summary.id) {
            result.push(PatternIdentifiers {
                id: meta.id,
                podcast_guid: meta.podcast_guid,
                feed_urls: meta.feed_urls,
            });
        }
    }

    let json = serde_json::to_value(result)
        .map_err(|e| AppError::internal(format!("Serialization error: {e}")))?;
    Ok(Json(json))
}
