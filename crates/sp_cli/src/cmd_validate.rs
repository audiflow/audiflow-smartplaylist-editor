use std::path::{Path, PathBuf};

use sp_core::schema::{SchemaType, Validator};

/// Validates config files against JSON schemas.
/// Returns exit code: 0 = all valid, 1 = validation errors, 2 = file not found.
pub fn run(data_dir: &str, files: &[String]) -> anyhow::Result<i32> {
    let validator = Validator::from_embedded()
        .map_err(|e| anyhow::anyhow!("Failed to load embedded schemas: {e}"))?;
    let patterns_dir = PathBuf::from(data_dir).join("patterns");

    if files.is_empty() {
        validate_all(&patterns_dir, &validator)
    } else {
        validate_files(data_dir, files, &validator)
    }
}

/// Validates all config files found under the patterns directory.
fn validate_all(patterns_dir: &Path, validator: &Validator) -> anyhow::Result<i32> {
    let mut error_count = 0u32;
    let mut file_count = 0u32;

    // Validate root meta.json
    let root_meta_path = patterns_dir.join("meta.json");
    if root_meta_path.exists() {
        file_count += 1;
        error_count += validate_file(&root_meta_path, SchemaType::PatternIndex, validator)?;
    } else {
        eprintln!("Warning: root meta.json not found at {}", root_meta_path.display());
    }

    // Walk pattern directories
    let entries = match std::fs::read_dir(patterns_dir) {
        Ok(e) => e,
        Err(e) => {
            eprintln!("Failed to read patterns directory: {e}");
            return Ok(2);
        }
    };

    for entry in entries {
        let entry = entry?;
        let path = entry.path();
        if !path.is_dir() {
            continue;
        }

        // Validate pattern meta.json
        let pattern_meta_path = path.join("meta.json");
        if pattern_meta_path.exists() {
            file_count += 1;
            error_count +=
                validate_file(&pattern_meta_path, SchemaType::PatternMeta, validator)?;
        }

        // Validate playlist files
        let playlists_dir = path.join("playlists");
        if !playlists_dir.is_dir() {
            continue;
        }

        let playlist_entries = match std::fs::read_dir(&playlists_dir) {
            Ok(e) => e,
            Err(_) => continue,
        };

        for playlist_entry in playlist_entries {
            let playlist_entry = playlist_entry?;
            let playlist_path = playlist_entry.path();
            if playlist_path.extension().and_then(|e| e.to_str()) != Some("json") {
                continue;
            }
            file_count += 1;
            error_count += validate_file(
                &playlist_path,
                SchemaType::PlaylistDefinition,
                validator,
            )?;
        }
    }

    println!("Validated {file_count} file(s).");
    if 0 < error_count {
        println!("{error_count} error(s) found.");
        Ok(1)
    } else {
        println!("All files are valid.");
        Ok(0)
    }
}

/// Validates specific files, auto-detecting schema type from path.
fn validate_files(data_dir: &str, files: &[String], validator: &Validator) -> anyhow::Result<i32> {
    let mut error_count = 0u32;
    let mut not_found = false;

    for file in files {
        let path = PathBuf::from(file);
        let path = if path.is_absolute() {
            path
        } else {
            PathBuf::from(data_dir).join(&path)
        };

        if !path.exists() {
            eprintln!("File not found: {}", path.display());
            not_found = true;
            continue;
        }

        let schema_type = detect_schema_type(&path);
        error_count += validate_file(&path, schema_type, validator)?;
    }

    if not_found {
        return Ok(2);
    }
    if 0 < error_count {
        Ok(1)
    } else {
        println!("All files are valid.");
        Ok(0)
    }
}

/// Detects the schema type based on file path structure.
fn detect_schema_type(path: &Path) -> SchemaType {
    let file_name = path.file_name().and_then(|n| n.to_str()).unwrap_or("");
    let parent_name = path
        .parent()
        .and_then(|p| p.file_name())
        .and_then(|n| n.to_str())
        .unwrap_or("");

    // Files under playlists/ directory are playlist definitions
    if parent_name == "playlists" {
        return SchemaType::PlaylistDefinition;
    }

    // Root meta.json is in the patterns/ directory
    if file_name == "meta.json" && parent_name == "patterns" {
        return SchemaType::PatternIndex;
    }

    // Other meta.json files are pattern metadata
    if file_name == "meta.json" {
        return SchemaType::PatternMeta;
    }

    // Default to playlist definition for unknown .json files
    SchemaType::PlaylistDefinition
}

/// Validates a single file and prints errors.
/// Returns the number of validation errors found.
fn validate_file(
    path: &Path,
    schema_type: SchemaType,
    validator: &Validator,
) -> anyhow::Result<u32> {
    let content = std::fs::read_to_string(path)?;
    let value: serde_json::Value = serde_json::from_str(&content)
        .map_err(|e| anyhow::anyhow!("Invalid JSON in {}: {e}", path.display()))?;

    let errors = validator.validate(schema_type, &value);
    if errors.is_empty() {
        println!("  OK: {}", path.display());
        return Ok(0);
    }

    eprintln!("  FAIL: {}", path.display());
    let error_json = serde_json::to_string_pretty(&errors)?;
    eprintln!("{error_json}");

    let count = errors.len() as u32;
    Ok(count)
}
