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
    let has_extension = Path::new(path).extension().is_some();

    // Sanitize: resolve the path and ensure it stays within static_dir
    let file_path = if path.is_empty() || !has_extension {
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
            if has_extension {
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
///
/// Canonicalizes both paths when possible so symlinks and normalization
/// differences cannot bypass the prefix check.
fn is_safe_path(base_dir: &Path, candidate: &Path) -> bool {
    let canonical_base = base_dir.canonicalize().unwrap_or_else(|_| base_dir.to_path_buf());
    match candidate.canonicalize() {
        Ok(resolved) => resolved.starts_with(&canonical_base),
        // File doesn't exist yet; reject any traversal or root/prefix components
        Err(_) => !candidate.components().any(|c| {
            matches!(
                c,
                std::path::Component::ParentDir
                    | std::path::Component::RootDir
                    | std::path::Component::Prefix(_)
            )
        }),
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

#[cfg(test)]
mod tests {
    use super::*;
    use std::path::PathBuf;

    #[test]
    fn is_safe_path_allows_normal_path() {
        let tmp = tempfile::TempDir::new().unwrap();
        let base = tmp.path();
        let file = base.join("app.js");
        std::fs::write(&file, "console.log()").unwrap();
        assert!(is_safe_path(base, &file));
    }

    #[test]
    fn is_safe_path_rejects_parent_traversal() {
        let tmp = tempfile::TempDir::new().unwrap();
        let base = tmp.path();
        let traversal = base.join("..").join("etc").join("passwd");
        assert!(!is_safe_path(base, &traversal));
    }

    #[test]
    fn is_safe_path_rejects_absolute_path() {
        let tmp = tempfile::TempDir::new().unwrap();
        let base = tmp.path();
        let absolute = PathBuf::from("/etc/passwd");
        assert!(!is_safe_path(base, &absolute));
    }

    #[test]
    fn is_safe_path_allows_nested_path() {
        let tmp = tempfile::TempDir::new().unwrap();
        let base = tmp.path();
        let nested = base.join("assets").join("css");
        std::fs::create_dir_all(&nested).unwrap();
        let file = nested.join("style.css");
        std::fs::write(&file, "body {}").unwrap();
        assert!(is_safe_path(base, &file));
    }

    #[test]
    fn is_safe_path_rejects_nonexistent_with_traversal() {
        let tmp = tempfile::TempDir::new().unwrap();
        let base = tmp.path();
        // File doesn't exist, but has traversal component
        let traversal = base.join("assets").join("..").join("..").join("secret");
        assert!(!is_safe_path(base, &traversal));
    }

    #[test]
    fn mime_from_path_returns_correct_types() {
        assert_eq!(mime_from_path(Path::new("index.html")), "text/html; charset=utf-8");
        assert_eq!(mime_from_path(Path::new("app.js")), "application/javascript; charset=utf-8");
        assert_eq!(mime_from_path(Path::new("style.css")), "text/css; charset=utf-8");
        assert_eq!(mime_from_path(Path::new("data.json")), "application/json");
        assert_eq!(mime_from_path(Path::new("image.png")), "image/png");
        assert_eq!(mime_from_path(Path::new("unknown.xyz")), "application/octet-stream");
    }
}
