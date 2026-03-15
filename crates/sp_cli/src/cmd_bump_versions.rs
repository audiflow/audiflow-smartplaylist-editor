use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::process::Command;

use sp_core::models::PatternMeta;

/// Validates that a string is safe to use as a single path segment.
/// Rejects empty strings, `.`, `..`, and strings containing `/`, `\`, or null bytes.
fn validate_path_segment(segment: &str) -> anyhow::Result<()> {
    if segment.is_empty()
        || !segment.chars().all(|c| c.is_ascii_alphanumeric() || c == '-' || c == '_')
    {
        anyhow::bail!("Invalid pattern ID: {segment:?}");
    }
    Ok(())
}

/// Computes the repo-relative path for a given directory by querying
/// `git rev-parse --show-toplevel` and stripping the prefix.
fn repo_relative_path(path: &Path) -> anyhow::Result<String> {
    let output = Command::new("git")
        .args(["rev-parse", "--show-toplevel"])
        .output()
        .map_err(|e| anyhow::anyhow!("Failed to run git rev-parse: {e}"))?;
    if !output.status.success() {
        anyhow::bail!("Not a git repository");
    }
    let toplevel = PathBuf::from(String::from_utf8_lossy(&output.stdout).trim());
    let abs_path = std::fs::canonicalize(path)
        .map_err(|e| anyhow::anyhow!("Failed to resolve {}: {e}", path.display()))?;
    let relative = abs_path
        .strip_prefix(&toplevel)
        .map_err(|_| anyhow::anyhow!("{} is not inside the git repository", path.display()))?;
    Ok(relative.to_string_lossy().to_string())
}

/// Runs `git diff --name-only` against a previous ref, scoped to the patterns directory.
fn git_diff_names(previous_ref: &str, patterns_dir: &Path) -> anyhow::Result<String> {
    let output = Command::new("git")
        .args(["diff", previous_ref, "--name-only", "--"])
        .arg(patterns_dir)
        .output()
        .map_err(|e| anyhow::anyhow!("Failed to run git diff: {e}"))?;
    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        anyhow::bail!("git diff failed: {stderr}");
    }
    Ok(String::from_utf8_lossy(&output.stdout).to_string())
}

/// Retrieves file content at a previous git ref. Returns `None` if the file
/// did not exist at that ref.
fn git_show_file(previous_ref: &str, file_path: &str) -> anyhow::Result<Option<String>> {
    let output = Command::new("git")
        .args(["show", &format!("{previous_ref}:{file_path}")])
        .output()
        .map_err(|e| anyhow::anyhow!("Failed to run git show: {e}"))?;
    if !output.status.success() {
        return Ok(None);
    }
    Ok(Some(String::from_utf8_lossy(&output.stdout).to_string()))
}

/// Loads the previous `dataVersion` for each changed pattern by reading
/// its `meta.json` from the given git ref. Returns an error if the file
/// exists at the ref but cannot be parsed.
fn load_previous_versions(
    previous_ref: &str,
    changed_ids: &[String],
    patterns_dir_name: &str,
) -> anyhow::Result<HashMap<String, i32>> {
    let mut versions = HashMap::new();
    for id in changed_ids {
        let path = format!("{patterns_dir_name}/{id}/meta.json");
        if let Some(content) = git_show_file(previous_ref, &path)? {
            let meta: PatternMeta = serde_json::from_str(&content)
                .map_err(|e| anyhow::anyhow!("Failed to parse {previous_ref}:{path}: {e}"))?;
            versions.insert(id.clone(), meta.data_version);
        }
    }
    Ok(versions)
}

/// Extracts unique pattern IDs from a git diff output.
///
/// Parses lines like `patterns/coten_radio/meta.json` and extracts
/// the pattern ID (`coten_radio`). Skips root-level files (e.g.,
/// `patterns/meta.json`) that have no subdirectory.
fn extract_changed_pattern_ids(diff_output: &str, patterns_dir_name: &str) -> Vec<String> {
    let prefix = format!("{patterns_dir_name}/");
    let mut ids: Vec<String> = diff_output
        .lines()
        .filter_map(|line| line.strip_prefix(&prefix))
        .filter_map(|rest| {
            let slash_pos = rest.find('/')?;
            Some(rest[..slash_pos].to_string())
        })
        .collect::<std::collections::BTreeSet<_>>()
        .into_iter()
        .collect();
    ids.sort();
    ids
}

/// Computes new version numbers for changed patterns.
///
/// For each changed pattern ID, looks up the previous version and
/// increments by one. Patterns not found in the previous map start
/// at version 1.
fn compute_version_bumps(
    changed_ids: &[String],
    previous_versions: &HashMap<String, i32>,
) -> HashMap<String, i32> {
    changed_ids
        .iter()
        .map(|id| {
            let new_version = previous_versions.get(id.as_str()).unwrap_or(&0) + 1;
            (id.clone(), new_version)
        })
        .collect()
}

/// Writes updated `dataVersion` into each changed pattern's `meta.json`.
/// Skips patterns whose `meta.json` no longer exists on disk (deleted patterns).
fn apply_pattern_bumps(
    patterns_dir: &Path,
    bumps: &HashMap<String, i32>,
) -> anyhow::Result<()> {
    for (id, new_version) in bumps {
        let meta_path = patterns_dir.join(id).join("meta.json");
        if !meta_path.exists() {
            continue;
        }
        let content = std::fs::read_to_string(&meta_path)
            .map_err(|e| anyhow::anyhow!("Failed to read {}: {e}", meta_path.display()))?;
        let mut value: serde_json::Value = serde_json::from_str(&content)?;
        value["dataVersion"] = serde_json::json!(new_version);
        let formatted = serde_json::to_string_pretty(&value)? + "\n";
        sp_server::services::atomic_write_str(&meta_path, &formatted)?;
    }
    Ok(())
}

/// Bumps the root `meta.json` version, updates pattern entries with new
/// `dataVersion` and `playlistCount` values, and writes the file atomically.
fn apply_root_bump(
    patterns_dir: &Path,
    bumps: &HashMap<String, i32>,
    previous_ref: &str,
    patterns_dir_name: &str,
) -> anyhow::Result<i32> {
    let root_meta_path = patterns_dir.join("meta.json");
    let content = std::fs::read_to_string(&root_meta_path)
        .map_err(|e| anyhow::anyhow!("Failed to read {}: {e}", root_meta_path.display()))?;
    let mut root: serde_json::Value = serde_json::from_str(&content)
        .map_err(|e| anyhow::anyhow!("Failed to parse {}: {e}", root_meta_path.display()))?;

    let prev_root_path = format!("{patterns_dir_name}/meta.json");
    let prev_root_version = match git_show_file(previous_ref, &prev_root_path)? {
        Some(content) => {
            let value: serde_json::Value = serde_json::from_str(&content)
                .map_err(|e| anyhow::anyhow!("Failed to parse {previous_ref}:{prev_root_path}: {e}"))?;
            value["dataVersion"].as_i64().unwrap_or(0) as i32
        }
        None => 0,
    };
    let new_root_version = prev_root_version + 1;
    root["dataVersion"] = serde_json::json!(new_root_version);

    if let Some(patterns) = root["patterns"].as_array_mut() {
        for pattern in patterns.iter_mut() {
            let Some(id) = pattern["id"].as_str().map(String::from) else {
                continue;
            };
            if let Some(&new_version) = bumps.get(&id) {
                pattern["dataVersion"] = serde_json::json!(new_version);
            }
            let meta_path = patterns_dir.join(&id).join("meta.json");
            if meta_path.exists() {
                match std::fs::read_to_string(&meta_path)
                    .map_err(anyhow::Error::from)
                    .and_then(|c| {
                        serde_json::from_str::<PatternMeta>(&c).map_err(Into::into)
                    }) {
                    Ok(meta) => {
                        pattern["playlistCount"] = serde_json::json!(meta.playlists.len());
                    }
                    Err(e) => {
                        eprintln!(
                            "Warning: failed to read {}: {e}",
                            meta_path.display()
                        );
                    }
                }
            }
        }
    }

    let formatted = serde_json::to_string_pretty(&root)? + "\n";
    sp_server::services::atomic_write_str(&root_meta_path, &formatted)?;
    Ok(new_root_version)
}

#[derive(serde::Serialize)]
struct BumpResult {
    pattern_id: String,
    previous_version: i32,
    new_version: i32,
}

#[derive(serde::Serialize)]
struct BumpSummary {
    changed_patterns: usize,
    root_version: i32,
    bumps: Vec<BumpResult>,
}

/// Entry point for the `bump-versions` subcommand.
///
/// Detects changed patterns via `git diff`, loads previous versions,
/// computes bumps, and writes updated `dataVersion` fields to disk.
pub fn run(patterns_dir: &str, previous_ref: &str, json: bool) -> anyhow::Result<i32> {
    let patterns_path = std::path::PathBuf::from(patterns_dir);
    if !patterns_path.join("meta.json").exists() {
        anyhow::bail!("No meta.json found in {patterns_dir}");
    }

    let patterns_dir_name = repo_relative_path(&patterns_path)?;

    let diff_output = git_diff_names(previous_ref, Path::new(&patterns_dir_name))?;
    let changed_ids = extract_changed_pattern_ids(&diff_output, &patterns_dir_name);

    // Validate path segments to prevent directory traversal
    for id in &changed_ids {
        validate_path_segment(id)?;
    }

    // Filter out deleted patterns whose meta.json no longer exists on disk
    let changed_ids: Vec<String> = changed_ids
        .into_iter()
        .filter(|id| patterns_path.join(id).join("meta.json").exists())
        .collect();

    if changed_ids.is_empty() {
        if json {
            println!(
                "{}",
                serde_json::to_string_pretty(&BumpSummary {
                    changed_patterns: 0,
                    root_version: 0,
                    bumps: vec![],
                })?
            );
        } else {
            eprintln!("No pattern changes detected.");
        }
        return Ok(0);
    }

    let previous_versions =
        load_previous_versions(previous_ref, &changed_ids, &patterns_dir_name)?;
    let bumps = compute_version_bumps(&changed_ids, &previous_versions);

    apply_pattern_bumps(&patterns_path, &bumps)?;
    let new_root_version =
        apply_root_bump(&patterns_path, &bumps, previous_ref, &patterns_dir_name)?;

    let results: Vec<BumpResult> = changed_ids
        .iter()
        .map(|id| BumpResult {
            pattern_id: id.clone(),
            previous_version: *previous_versions.get(id).unwrap_or(&0),
            new_version: *bumps.get(id).unwrap_or(&1),
        })
        .collect();

    if json {
        println!(
            "{}",
            serde_json::to_string_pretty(&BumpSummary {
                changed_patterns: results.len(),
                root_version: new_root_version,
                bumps: results,
            })?
        );
    } else {
        eprintln!("Detecting changes from {previous_ref}...");
        for r in &results {
            eprintln!(
                "  {}: version {} -> {}",
                r.pattern_id, r.previous_version, r.new_version
            );
        }
        eprintln!("  Root meta: version -> {new_root_version}");
        eprintln!("Version bump complete.");
    }

    Ok(0)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn extracts_unique_pattern_ids_from_diff() {
        let diff = "patterns/coten_radio/meta.json\n\
                     patterns/coten_radio/playlists/main.json\n\
                     patterns/rebuild/meta.json\n";
        let result = extract_changed_pattern_ids(diff, "patterns");
        assert_eq!(result, vec!["coten_radio", "rebuild"]);
    }

    #[test]
    fn skips_root_meta_json() {
        let diff = "patterns/meta.json\npatterns/coten_radio/meta.json\n";
        let result = extract_changed_pattern_ids(diff, "patterns");
        assert_eq!(result, vec!["coten_radio"]);
    }

    #[test]
    fn returns_empty_for_no_pattern_changes() {
        let diff = "README.md\nsrc/main.rs\n";
        let result = extract_changed_pattern_ids(diff, "patterns");
        assert!(result.is_empty());
    }

    #[test]
    fn handles_empty_diff() {
        let result = extract_changed_pattern_ids("", "patterns");
        assert!(result.is_empty());
    }

    #[test]
    fn bumps_existing_pattern_version() {
        let mut previous: HashMap<String, i32> = HashMap::new();
        previous.insert("coten_radio".into(), 3);
        let changed = vec!["coten_radio".into()];
        let result = compute_version_bumps(&changed, &previous);
        assert_eq!(result.get("coten_radio"), Some(&4));
    }

    #[test]
    fn new_pattern_starts_at_one() {
        let previous: HashMap<String, i32> = HashMap::new();
        let changed = vec!["new_pattern".into()];
        let result = compute_version_bumps(&changed, &previous);
        assert_eq!(result.get("new_pattern"), Some(&1));
    }

    #[test]
    fn validates_safe_path_segments() {
        assert!(validate_path_segment("coten_radio").is_ok());
        assert!(validate_path_segment("my-show").is_ok());
    }

    #[test]
    fn rejects_path_traversal_segments() {
        assert!(validate_path_segment("..").is_err());
        assert!(validate_path_segment(".").is_err());
        assert!(validate_path_segment("").is_err());
        assert!(validate_path_segment("foo/bar").is_err());
        assert!(validate_path_segment("foo\\bar").is_err());
        assert!(validate_path_segment("foo\0bar").is_err());
    }

    #[test]
    fn integration_bump_versions_in_temp_repo() {
        use std::process::Command;
        use tempfile::TempDir;

        let tmp = TempDir::new().unwrap();
        let repo = tmp.path();

        // Init git repo
        Command::new("git")
            .args(["init"])
            .current_dir(repo)
            .output()
            .unwrap();
        Command::new("git")
            .args(["config", "user.email", "test@test.com"])
            .current_dir(repo)
            .output()
            .unwrap();
        Command::new("git")
            .args(["config", "user.name", "Test"])
            .current_dir(repo)
            .output()
            .unwrap();

        let patterns = repo.join("patterns");
        std::fs::create_dir_all(patterns.join("show_a/playlists")).unwrap();

        // Root meta
        std::fs::write(
            patterns.join("meta.json"),
            r#"{"dataVersion": 1, "schemaVersion": 2, "patterns": [{"id": "show_a", "dataVersion": 1, "displayName": "Show A", "feedUrlHint": "https://example.com", "playlistCount": 1}]}"#,
        )
        .unwrap();

        // Pattern meta
        std::fs::write(
            patterns.join("show_a/meta.json"),
            r#"{"dataVersion": 1, "id": "show_a", "feedUrls": ["https://example.com"], "playlists": ["main", "bonus"]}"#,
        )
        .unwrap();

        // Playlist
        std::fs::write(
            patterns.join("show_a/playlists/main.json"),
            r#"{"resolverType": "category"}"#,
        )
        .unwrap();

        // Initial commit
        Command::new("git")
            .args(["add", "."])
            .current_dir(repo)
            .output()
            .unwrap();
        Command::new("git")
            .args(["commit", "-m", "init"])
            .current_dir(repo)
            .output()
            .unwrap();

        // Make a change
        std::fs::write(
            patterns.join("show_a/playlists/main.json"),
            r#"{"resolverType": "rss"}"#,
        )
        .unwrap();
        Command::new("git")
            .args(["add", "."])
            .current_dir(repo)
            .output()
            .unwrap();
        Command::new("git")
            .args(["commit", "-m", "update"])
            .current_dir(repo)
            .output()
            .unwrap();

        // Test pure functions against real git diff output
        let diff = Command::new("git")
            .args(["diff", "HEAD~1", "--name-only", "--", "patterns"])
            .current_dir(repo)
            .output()
            .unwrap();
        let diff_output = String::from_utf8_lossy(&diff.stdout);
        let changed = extract_changed_pattern_ids(&diff_output, "patterns");
        assert_eq!(changed, vec!["show_a"]);

        let mut prev: HashMap<String, i32> = HashMap::new();
        prev.insert("show_a".into(), 1);
        let bumps = compute_version_bumps(&changed, &prev);
        assert_eq!(bumps.get("show_a"), Some(&2));
    }

    #[test]
    fn integration_run_bumps_versions_on_disk() {
        use std::process::Command;
        use tempfile::TempDir;

        let tmp = TempDir::new().unwrap();
        let repo = tmp.path();

        // Init git repo
        Command::new("git")
            .args(["init"])
            .current_dir(repo)
            .output()
            .unwrap();
        Command::new("git")
            .args(["config", "user.email", "test@test.com"])
            .current_dir(repo)
            .output()
            .unwrap();
        Command::new("git")
            .args(["config", "user.name", "Test"])
            .current_dir(repo)
            .output()
            .unwrap();

        let patterns = repo.join("patterns");
        std::fs::create_dir_all(patterns.join("show_a/playlists")).unwrap();

        std::fs::write(
            patterns.join("meta.json"),
            r#"{"dataVersion": 1, "schemaVersion": 2, "patterns": [{"id": "show_a", "dataVersion": 1, "displayName": "Show A", "feedUrlHint": "https://example.com", "playlistCount": 1}]}"#,
        )
        .unwrap();

        std::fs::write(
            patterns.join("show_a/meta.json"),
            r#"{"dataVersion": 1, "id": "show_a", "feedUrls": ["https://example.com"], "playlists": ["main", "bonus"]}"#,
        )
        .unwrap();

        std::fs::write(
            patterns.join("show_a/playlists/main.json"),
            r#"{"resolverType": "category"}"#,
        )
        .unwrap();

        Command::new("git")
            .args(["add", "."])
            .current_dir(repo)
            .output()
            .unwrap();
        Command::new("git")
            .args(["commit", "-m", "init"])
            .current_dir(repo)
            .output()
            .unwrap();

        // Make a change
        std::fs::write(
            patterns.join("show_a/playlists/main.json"),
            r#"{"resolverType": "rss"}"#,
        )
        .unwrap();
        Command::new("git")
            .args(["add", "."])
            .current_dir(repo)
            .output()
            .unwrap();
        Command::new("git")
            .args(["commit", "-m", "update"])
            .current_dir(repo)
            .output()
            .unwrap();

        // Save current dir and change to repo
        let original_dir = std::env::current_dir().unwrap();
        std::env::set_current_dir(repo).unwrap();

        let result = run("patterns", "HEAD~1", false);

        // Restore dir
        std::env::set_current_dir(&original_dir).unwrap();

        assert!(result.is_ok(), "run() failed: {:?}", result.err());
        assert_eq!(result.unwrap(), 0);

        // Verify pattern meta was bumped
        let meta: serde_json::Value = serde_json::from_str(
            &std::fs::read_to_string(patterns.join("show_a/meta.json")).unwrap(),
        )
        .unwrap();
        assert_eq!(meta["dataVersion"], 2);

        // Verify root meta was bumped
        let root: serde_json::Value = serde_json::from_str(
            &std::fs::read_to_string(patterns.join("meta.json")).unwrap(),
        )
        .unwrap();
        assert_eq!(root["dataVersion"], 2);
        assert_eq!(root["patterns"][0]["dataVersion"], 2);
        // "main" and "bonus" in playlists array
        assert_eq!(root["patterns"][0]["playlistCount"], 2);
    }
}
