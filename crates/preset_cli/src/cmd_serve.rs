use std::path::PathBuf;
use std::sync::Arc;
use std::time::Duration;

use preset_core::schema::Validator;
use preset_server::app::AppState;
use preset_server::routes::create_router;
use preset_server::services::{DiskFeedCacheService, FileWatcherService, LocalConfigRepository};

/// Starts the web editor server bound to localhost.
pub async fn run(
    data_dir: &str,
    host: &str,
    port: u16,
    static_dir: Option<&str>,
) -> anyhow::Result<()> {
    let data_path = PathBuf::from(data_dir);

    // Verify presets/meta.json or legacy patterns/meta.json exists
    let root_dir = crate::config_walker::resolve_root_data_dir(&data_path).ok_or_else(|| {
        anyhow::anyhow!(
            "Data directory does not contain presets/meta.json or patterns/meta.json: {}",
            data_dir
        )
    })?;
    let meta_path = root_dir.join("meta.json");
    if !meta_path.exists() {
        anyhow::bail!(
            "Data directory does not contain {}/meta.json: {}",
            root_dir
                .file_name()
                .and_then(|n| n.to_str())
                .unwrap_or("presets"),
            data_dir
        );
    }

    let config_repo = LocalConfigRepository::new(&data_path);

    let cache_dir = data_path.join(".cache").join("feeds");
    let feed_cache = DiskFeedCacheService::new(cache_dir, Duration::from_secs(3600));

    let validator = Validator::from_embedded()
        .map_err(|e| anyhow::anyhow!("Failed to load embedded schemas: {e}"))?;

    let schema_json = Validator::playlist_definition_schema_json().to_string();

    let file_watcher = FileWatcherService::new(data_path.clone(), vec![".cache".to_string()])
        .map_err(|e| anyhow::anyhow!("Failed to start file watcher: {e}"))?;

    let static_path = static_dir.map(PathBuf::from);

    // Warn when no SPA assets are available (common on fresh builds).
    if static_path.is_none() && !preset_server::has_embedded_index() {
        eprintln!(
            "Warning: no embedded SPA assets found and --static-dir not set.\n\
             Build the React app first (cd packages/preset_react && pnpm build) \
             or pass --static-dir to serve from disk."
        );
    }

    let state = Arc::new(AppState {
        config_repo,
        feed_cache,
        validator,
        file_watcher,
        schema_json,
        http_client: reqwest::Client::new(),
        static_dir: static_path,
    });

    let app = create_router(state);

    let addr = format!("{host}:{port}");
    let listener = tokio::net::TcpListener::bind(&addr).await?;
    println!("Server running at http://{addr}");

    axum::serve(listener, app).await?;
    Ok(())
}
