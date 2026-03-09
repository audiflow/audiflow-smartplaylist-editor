use std::path::{Path, PathBuf};

/// Formats config JSON files with 2-space indent and trailing newline.
/// Returns exit code: 0 = all formatted/already correct, 1 = would change (--check mode).
pub fn run(data_dir: &str, check: bool, files: &[String]) -> anyhow::Result<i32> {
    let patterns_dir = PathBuf::from(data_dir).join("patterns");

    if files.is_empty() {
        format_all(&patterns_dir, check)
    } else {
        format_files(data_dir, files, check)
    }
}

/// Formats all JSON files found under the patterns directory.
fn format_all(patterns_dir: &Path, check: bool) -> anyhow::Result<i32> {
    let mut would_change = false;
    let mut formatted_count = 0u32;

    // Root meta.json
    let root_meta_path = patterns_dir.join("meta.json");
    if root_meta_path.exists() {
        let result = format_file(&root_meta_path, check)?;
        if result == FormatResult::Changed {
            would_change = true;
            formatted_count += 1;
        }
    }

    // Walk pattern directories
    let entries = match std::fs::read_dir(patterns_dir) {
        Ok(e) => e,
        Err(e) => {
            eprintln!("Failed to read patterns directory: {e}");
            return Ok(1);
        }
    };

    for entry in entries {
        let entry = entry?;
        let path = entry.path();
        if !path.is_dir() {
            continue;
        }

        // Pattern meta.json
        let pattern_meta_path = path.join("meta.json");
        if pattern_meta_path.exists() {
            let result = format_file(&pattern_meta_path, check)?;
            if result == FormatResult::Changed {
                would_change = true;
                formatted_count += 1;
            }
        }

        // Playlist files
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
            let result = format_file(&playlist_path, check)?;
            if result == FormatResult::Changed {
                would_change = true;
                formatted_count += 1;
            }
        }
    }

    if check && would_change {
        println!("{formatted_count} file(s) would be reformatted.");
        return Ok(1);
    }

    if !check && 0 < formatted_count {
        println!("Formatted {formatted_count} file(s).");
    } else {
        println!("All files are already formatted.");
    }
    Ok(0)
}

/// Formats specific files.
fn format_files(data_dir: &str, files: &[String], check: bool) -> anyhow::Result<i32> {
    let mut would_change = false;
    let mut formatted_count = 0u32;

    for file in files {
        let path = PathBuf::from(file);
        let path = if path.is_absolute() {
            path
        } else {
            PathBuf::from(data_dir).join(&path)
        };

        if !path.exists() {
            eprintln!("File not found: {}", path.display());
            continue;
        }

        let result = format_file(&path, check)?;
        if result == FormatResult::Changed {
            would_change = true;
            formatted_count += 1;
        }
    }

    if check && would_change {
        println!("{formatted_count} file(s) would be reformatted.");
        return Ok(1);
    }

    if !check && 0 < formatted_count {
        println!("Formatted {formatted_count} file(s).");
    } else {
        println!("All files are already formatted.");
    }
    Ok(0)
}

#[derive(PartialEq)]
enum FormatResult {
    Unchanged,
    Changed,
}

/// Formats a single JSON file. In check mode, reports whether it would change.
/// In write mode, writes the formatted version only if different from original.
fn format_file(path: &Path, check: bool) -> anyhow::Result<FormatResult> {
    let original = std::fs::read_to_string(path)?;
    let value: serde_json::Value = serde_json::from_str(&original)
        .map_err(|e| anyhow::anyhow!("Invalid JSON in {}: {e}", path.display()))?;

    let formatted = format!("{}\n", serde_json::to_string_pretty(&value)?);

    if original == formatted {
        return Ok(FormatResult::Unchanged);
    }

    if check {
        println!("  Would reformat: {}", path.display());
        return Ok(FormatResult::Changed);
    }

    // Atomic write: .tmp then rename
    let tmp_path = path.with_extension("json.tmp");
    std::fs::write(&tmp_path, &formatted)?;
    std::fs::rename(&tmp_path, path)?;
    println!("  Formatted: {}", path.display());

    Ok(FormatResult::Changed)
}
