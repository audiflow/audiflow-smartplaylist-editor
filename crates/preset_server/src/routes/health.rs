use axum::Json;

/// GET /api/health -- returns a simple health check response.
pub async fn health() -> Json<serde_json::Value> {
    Json(serde_json::json!({ "status": "ok" }))
}
