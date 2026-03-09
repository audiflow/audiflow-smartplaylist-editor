use axum::body::Body;
use axum::extract::State;
use axum::http::{header, Request, StatusCode};
use axum::response::{IntoResponse, Response};

use crate::app::SharedState;

/// Fallback handler that serves static files from the configured
/// static directory (React SPA).
///
/// - Files with extensions are served with appropriate content types.
/// - Paths without file extensions serve `index.html` (SPA fallback).
/// - Returns 404 if no static directory is configured or file not found.
pub async fn static_handler(
    State(state): State<SharedState>,
    request: Request<Body>,
) -> Response {
    let static_dir = match &state.static_dir {
        Some(dir) => dir,
        None => return StatusCode::NOT_FOUND.into_response(),
    };

    let path = request.uri().path().trim_start_matches('/');

    // SPA fallback: if the path has no file extension, serve index.html
    let file_path = if path.is_empty() || !path.contains('.') {
        static_dir.join("index.html")
    } else {
        static_dir.join(path)
    };

    match tokio::fs::read(&file_path).await {
        Ok(contents) => {
            let content_type = mime_from_path(&file_path);
            (
                [(header::CONTENT_TYPE, content_type)],
                contents,
            )
                .into_response()
        }
        Err(_) => {
            // Try index.html as final SPA fallback
            let index_path = static_dir.join("index.html");
            match tokio::fs::read(&index_path).await {
                Ok(contents) => {
                    (
                        [(header::CONTENT_TYPE, "text/html; charset=utf-8")],
                        contents,
                    )
                        .into_response()
                }
                Err(_) => StatusCode::NOT_FOUND.into_response(),
            }
        }
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
