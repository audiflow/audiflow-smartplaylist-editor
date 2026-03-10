use std::path::PathBuf;
use std::sync::Arc;
use std::time::Duration;

use sp_core::schema::Validator;
use sp_server::app::AppState;
use sp_server::routes::create_router;
use sp_server::services::{DiskFeedCacheService, FileWatcherService, LocalConfigRepository};

/// Starts the web editor server bound to localhost.
pub async fn run(data_dir: &str, host: &str, port: u16, static_dir: Option<&str>) -> anyhow::Result<()> {
    let data_path = PathBuf::from(data_dir);

    // Verify patterns/meta.json exists
    let meta_path = data_path.join("patterns").join("meta.json");
    if !meta_path.exists() {
        anyhow::bail!(
            "Data directory does not contain patterns/meta.json: {}",
            data_dir
        );
    }

    let config_repo = LocalConfigRepository::new(&data_path);

    let cache_dir = data_path.join(".cache").join("feeds");
    let feed_cache = DiskFeedCacheService::new(cache_dir, Duration::from_secs(3600));

    let validator = Validator::from_embedded()
        .map_err(|e| anyhow::anyhow!("Failed to load embedded schemas: {e}"))?;

    let schema_json = Validator::playlist_definition_schema_json().to_string();

    let file_watcher = FileWatcherService::new(
        data_path.clone(),
        vec![".cache".to_string()],
    )
    .map_err(|e| anyhow::anyhow!("Failed to start file watcher: {e}"))?;

    let static_path = static_dir.map(PathBuf::from);

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
