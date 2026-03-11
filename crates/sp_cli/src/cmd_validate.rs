use std::path::{Path, PathBuf};

use sp_core::models::PatternMeta;
use sp_core::schema::{SchemaType, Validator};
use sp_core::services::check_uniqueness;

use crate::config_walker;

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
    let root_meta = patterns_dir.join("meta.json");
    if !root_meta.exists() {
        eprintln!("File not found: {}", root_meta.display());
        return Ok(2);
    }

    let mut error_count = 0u32;
    let mut file_count = 0u32;

    config_walker::walk_config_files(patterns_dir, |path, schema_type| {
        file_count += 1;
        error_count += validate_file(path, schema_type, validator)?;
        Ok(())
    })?;

    error_count += validate_cross_pattern_uniqueness(patterns_dir)?;

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
        let path = config_walker::resolve_file_path(data_dir, file);
        if !path.exists() {
            eprintln!("File not found: {}", path.display());
            not_found = true;
            continue;
        }

        let schema_type = config_walker::detect_schema_type(&path);
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

/// Validates a single file and prints errors.
/// Returns the number of validation errors found.
///
/// Human-readable status goes to stdout (OK/FAIL lines).
/// Structured JSON error objects go to stderr for machine consumption.
fn validate_file(
    path: &Path,
    schema_type: SchemaType,
    validator: &Validator,
) -> anyhow::Result<u32> {
    let content = std::fs::read_to_string(path)?;
    let value: serde_json::Value = serde_json::from_str(&content)
        .map_err(|e| anyhow::anyhow!("Invalid JSON in {}: {e}", path.display()))?;

    let schema_type_str = match schema_type {
        SchemaType::PatternIndex => "patternIndex",
        SchemaType::PatternMeta => "patternMeta",
        SchemaType::PlaylistDefinition => "playlistDefinition",
    };

    let errors = validator.validate(schema_type, &value);
    if errors.is_empty() {
        println!("  OK: {}", path.display());
        return Ok(0);
    }

    println!("  FAIL: {}", path.display());
    let error_json = serde_json::to_string_pretty(&serde_json::json!({
        "file": path.display().to_string(),
        "schemaType": schema_type_str,
        "errors": errors,
    }))?;
    eprintln!("{error_json}");

    let count = errors.len() as u32;
    Ok(count)
}

/// Loads every pattern meta.json and checks for cross-pattern uniqueness
/// conflicts (duplicate podcastGuid or feedUrls).
/// Returns the number of conflicts found.
fn validate_cross_pattern_uniqueness(patterns_dir: &Path) -> anyhow::Result<u32> {
    let metas = load_pattern_metas(patterns_dir)?;

    let mut conflict_count = 0u32;
    for i in 1..metas.len() {
        let candidate = &metas[i];
        let others = &metas[..i];
        let conflicts = check_uniqueness(candidate, others);
        for conflict in &conflicts {
            println!("  FAIL: pattern \"{}\" -- {conflict}", candidate.id);
            conflict_count += 1;
        }
    }

    Ok(conflict_count)
}

/// Reads pattern meta.json files from subdirectories of patterns_dir.
fn load_pattern_metas(patterns_dir: &Path) -> anyhow::Result<Vec<PatternMeta>> {
    let mut metas: Vec<PatternMeta> = Vec::new();

    let dirs: Vec<PathBuf> = match std::fs::read_dir(patterns_dir) {
        Ok(entries) => entries
            .filter_map(|e| e.ok())
            .map(|e| e.path())
            .filter(|p| p.is_dir())
            .collect(),
        Err(_) => return Ok(metas),
    };

    for dir in &dirs {
        let meta_path = dir.join("meta.json");
        if !meta_path.exists() {
            continue;
        }
        let content = std::fs::read_to_string(&meta_path)?;
        if let Ok(meta) = serde_json::from_str::<PatternMeta>(&content) {
            metas.push(meta);
        }
    }

    Ok(metas)
}
