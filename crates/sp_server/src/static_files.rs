use std::path::Path;

use axum::body::Body;
use axum::extract::State;
use axum::http::{header, Request, StatusCode};
use axum::response::{IntoResponse, Response};

use crate::app::SharedState;

/// Fallback handler that serves static files from the configured
/// static directory (React SPA).
///
/// - Files with extensions are served with appropriate content types.
/// - Extensionless paths serve `index.html` (SPA fallback).
/// - Missing assets (paths with extensions) return 404 directly.
/// - Returns 404 if no static directory is configured.
pub async fn static_handler(
    State(state): State<SharedState>,
    request: Request<Body>,
) -> Response {
    let static_dir = match &state.static_dir {
        Some(dir) => dir,
        None => return StatusCode::NOT_FOUND.into_response(),
    };

    let path = request.uri().path().trim_start_matches('/');

    // Sanitize: resolve the path and ensure it stays within static_dir
    let file_path = if path.is_empty() || !path.contains('.') {
        static_dir.join("index.html")
    } else {
        let candidate = static_dir.join(path);
        if !is_safe_path(static_dir, &candidate) {
            return StatusCode::NOT_FOUND.into_response();
        }
        candidate
    };

    match tokio::fs::read(&file_path).await {
        Ok(contents) => {
            let content_type = mime_from_path(&file_path);
            ([(header::CONTENT_TYPE, content_type)], contents).into_response()
        }
        Err(_) => {
            // Only fall back to index.html for extensionless paths (SPA routes).
            // Missing assets (.js, .css, etc.) should 404.
            if path.contains('.') {
                return StatusCode::NOT_FOUND.into_response();
            }
            let index_path = static_dir.join("index.html");
            match tokio::fs::read(&index_path).await {
                Ok(contents) => (
                    [(header::CONTENT_TYPE, "text/html; charset=utf-8")],
                    contents,
                )
                    .into_response(),
                Err(_) => StatusCode::NOT_FOUND.into_response(),
            }
        }
    }
}

/// Returns true if `candidate` is safely within `base_dir` (no traversal).
fn is_safe_path(base_dir: &Path, candidate: &Path) -> bool {
    match candidate.canonicalize() {
        Ok(resolved) => resolved.starts_with(base_dir),
        // File doesn't exist yet; check components for traversal
        Err(_) => !candidate
            .components()
            .any(|c| matches!(c, std::path::Component::ParentDir)),
    }
}

/// Returns a MIME type string based on file extension.
fn mime_from_path(path: &std::path::Path) -> &'static str {
    match path.extension().and_then(|e| e.to_str()) {
        Some("html") => "text/html; charset=utf-8",
        Some("js") | Some("mjs") => "application/javascript; charset=utf-8",
        Some("css") => "text/css; charset=utf-8",
        Some("json") => "application/json",
        Some("svg") => "image/svg+xml",
        Some("png") => "image/png",
        Some("jpg") | Some("jpeg") => "image/jpeg",
        Some("gif") => "image/gif",
        Some("ico") => "image/x-icon",
        Some("woff") => "font/woff",
        Some("woff2") => "font/woff2",
        Some("ttf") => "font/ttf",
        Some("wasm") => "application/wasm",
        Some("map") => "application/json",
        _ => "application/octet-stream",
    }
}
