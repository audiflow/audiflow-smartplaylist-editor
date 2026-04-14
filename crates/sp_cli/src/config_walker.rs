use std::path::{Path, PathBuf};

use sp_core::schema::SchemaType;

/// Walks all config files under the patterns directory, calling the
/// callback for each file with its detected schema type.
///
/// Walk order: root meta.json, then for each pattern directory:
/// pattern meta.json, then all playlist .json files.
pub fn walk_config_files<F>(patterns_dir: &Path, mut callback: F) -> anyhow::Result<()>
where
    F: FnMut(&Path, SchemaType) -> anyhow::Result<()>,
{
    let root_meta_path = patterns_dir.join("meta.json");
    if root_meta_path.exists() {
        callback(&root_meta_path, SchemaType::PatternIndex)?;
    }

    let mut dirs: Vec<PathBuf> = std::fs::read_dir(patterns_dir)
        .map_err(|e| {
            anyhow::anyhow!(
                "Failed to read patterns directory {}: {e}",
                patterns_dir.display()
            )
        })?
        .filter_map(|e| e.ok())
        .map(|e| e.path())
        .filter(|p| p.is_dir())
        .collect();
    dirs.sort();

    for path in &dirs {
        let pattern_meta_path = path.join("meta.json");
        if pattern_meta_path.exists() {
            callback(&pattern_meta_path, SchemaType::PatternMeta)?;
        }

        walk_playlist_dir(&path.join("playlists"), &mut callback)?;
    }

    Ok(())
}

fn walk_playlist_dir<F>(playlists_dir: &Path, callback: &mut F) -> anyhow::Result<()>
where
    F: FnMut(&Path, SchemaType) -> anyhow::Result<()>,
{
    if !playlists_dir.is_dir() {
        return Ok(());
    }

    let mut files: Vec<PathBuf> = match std::fs::read_dir(playlists_dir) {
        Ok(e) => e,
        Err(_) => return Ok(()),
    }
    .filter_map(|e| e.ok())
    .map(|e| e.path())
    .filter(|p| p.extension().and_then(|e| e.to_str()) == Some("json"))
    .collect();
    files.sort();

    for path in &files {
        callback(path, SchemaType::PlaylistDefinition)?;
    }

    Ok(())
}

/// Resolves a file path relative to data_dir if not absolute.
pub fn resolve_file_path(data_dir: &str, file: &str) -> PathBuf {
    let path = PathBuf::from(file);
    if path.is_absolute() {
        path
    } else {
        PathBuf::from(data_dir).join(&path)
    }
}

/// Detects the schema type based on file path structure.
pub fn detect_schema_type(path: &Path) -> SchemaType {
    let file_name = path.file_name().and_then(|n| n.to_str()).unwrap_or("");
    let parent_name = path
        .parent()
        .and_then(|p| p.file_name())
        .and_then(|n| n.to_str())
        .unwrap_or("");

    if parent_name == "playlists" {
        return SchemaType::PlaylistDefinition;
    }
    if file_name == "meta.json" && parent_name == "patterns" {
        return SchemaType::PatternIndex;
    }
    if file_name == "meta.json" {
        return SchemaType::PatternMeta;
    }
    SchemaType::PlaylistDefinition
}
