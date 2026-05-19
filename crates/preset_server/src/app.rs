use std::path::PathBuf;
use std::sync::Arc;

use axum::Json;
use axum::http::StatusCode;
use axum::response::{IntoResponse, Response};

use crate::services::{DiskFeedCacheService, FileWatcherService, LocalConfigRepository};
use preset_core::schema::Validator;

/// Shared application state passed to all route handlers.
pub struct AppState {
    pub config_repo: LocalConfigRepository,
    pub feed_cache: DiskFeedCacheService,
    pub validator: Validator,
    pub file_watcher: FileWatcherService,
    /// Cached playlist-definition schema JSON for GET /api/schema.
    pub schema_json: String,
    pub http_client: reqwest::Client,
    /// Optional directory for serving static files (React SPA).
    pub static_dir: Option<PathBuf>,
}

pub type SharedState = Arc<AppState>;

/// Unified error type for route handlers that converts to a JSON
/// response with appropriate status code.
#[derive(Debug)]
pub struct AppError {
    pub status: StatusCode,
    pub message: String,
}

impl AppError {
    pub fn bad_request(msg: impl Into<String>) -> Self {
        Self {
            status: StatusCode::BAD_REQUEST,
            message: msg.into(),
        }
    }

    pub fn not_found(msg: impl Into<String>) -> Self {
        Self {
            status: StatusCode::NOT_FOUND,
            message: msg.into(),
        }
    }

    pub fn internal(msg: impl Into<String>) -> Self {
        Self {
            status: StatusCode::INTERNAL_SERVER_ERROR,
            message: msg.into(),
        }
    }

    pub fn conflict(msg: impl Into<String>) -> Self {
        Self {
            status: StatusCode::CONFLICT,
            message: msg.into(),
        }
    }

    pub fn bad_gateway(msg: impl Into<String>) -> Self {
        Self {
            status: StatusCode::BAD_GATEWAY,
            message: msg.into(),
        }
    }
}

impl IntoResponse for AppError {
    fn into_response(self) -> Response {
        let body = serde_json::json!({ "error": self.message });
        (self.status, Json(body)).into_response()
    }
}

impl From<crate::services::local_config_repository::Error> for AppError {
    fn from(err: crate::services::local_config_repository::Error) -> Self {
        match err {
            crate::services::local_config_repository::Error::NotFound(path) => {
                AppError::not_found(format!("Not found: {path}"))
            }
            crate::services::local_config_repository::Error::InvalidPathSegment {
                label,
                value,
            } => AppError::bad_request(format!(
                "{label} '{value}' must contain only alphanumeric characters, hyphens, or underscores"
            )),
            other => AppError::internal(format!("Config error: {other}")),
        }
    }
}
