use std::path::{Path, PathBuf};

use crate::config_walker;

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

    config_walker::walk_config_files(patterns_dir, |path, _schema_type| {
        let result = format_file(path, check)?;
        if result == FormatResult::Changed {
            would_change = true;
            formatted_count += 1;
        }
        Ok(())
    })?;

    report_format_result(check, would_change, formatted_count)
}

/// Formats specific files.
fn format_files(data_dir: &str, files: &[String], check: bool) -> anyhow::Result<i32> {
    let mut would_change = false;
    let mut formatted_count = 0u32;

    for file in files {
        let path = config_walker::resolve_file_path(data_dir, file);
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

    report_format_result(check, would_change, formatted_count)
}

fn report_format_result(check: bool, would_change: bool, count: u32) -> anyhow::Result<i32> {
    if check && would_change {
        println!("{count} file(s) would be reformatted.");
        return Ok(1);
    }
    if !check && 0 < count {
        println!("Formatted {count} file(s).");
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

    sp_server::services::atomic_write_str(path, &formatted)?;
    println!("  Formatted: {}", path.display());

    Ok(FormatResult::Changed)
}
