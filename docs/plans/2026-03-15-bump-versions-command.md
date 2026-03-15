# bump-versions Command Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a `bump-versions` subcommand to `audiflow-editor` CLI that auto-increments `dataVersion` fields for changed patterns, used by data repo CI to prevent version tampering.

**Architecture:** All logic lives in `sp_cli` (git interaction is CLI-specific, not domain). Pure functions for pattern ID extraction and version computation are unit-tested separately from git calls. Uses `std::process::Command` for git operations.

**Tech Stack:** Rust, clap, serde_json, std::process::Command

---

### Task 1: Pure functions with tests

**Files:**
- Create: `crates/sp_cli/src/cmd_bump_versions.rs`

**Step 1: Write tests for `extract_changed_pattern_ids`**

```rust
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
}
```

**Step 2: Implement `extract_changed_pattern_ids`**

```rust
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
```

**Step 3: Write tests for `compute_version_bumps`**

```rust
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
```

**Step 4: Implement `compute_version_bumps`**

```rust
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
```

**Step 5: Run tests**

Run: `cargo test -p sp_cli`
Expected: All 6 tests pass

**Step 6: Commit**

```
feat: add pure functions for bump-versions command
```

---

### Task 2: Git helper functions

**Files:**
- Modify: `crates/sp_cli/src/cmd_bump_versions.rs`

**Step 1: Implement git helper functions**

```rust
use std::process::Command;

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

fn git_show_file(previous_ref: &str, file_path: &str) -> anyhow::Result<Option<String>> {
    let output = Command::new("git")
        .args(["show", &format!("{previous_ref}:{file_path}")])
        .output()
        .map_err(|e| anyhow::anyhow!("Failed to run git show: {e}"))?;
    if !output.status.success() {
        return Ok(None); // file didn't exist in previous ref
    }
    Ok(Some(String::from_utf8_lossy(&output.stdout).to_string()))
}
```

**Step 2: Implement `load_previous_versions`**

```rust
fn load_previous_versions(
    previous_ref: &str,
    changed_ids: &[String],
    patterns_dir_name: &str,
) -> anyhow::Result<HashMap<String, i32>> {
    let mut versions = HashMap::new();
    for id in changed_ids {
        let path = format!("{patterns_dir_name}/{id}/meta.json");
        if let Some(content) = git_show_file(previous_ref, &path)? {
            if let Ok(meta) = serde_json::from_str::<PatternMeta>(&content) {
                versions.insert(id.clone(), meta.data_version);
            }
        }
    }
    Ok(versions)
}
```

**Step 3: Commit**

```
feat: add git helper functions for bump-versions
```

---

### Task 3: Apply bumps and write files

**Files:**
- Modify: `crates/sp_cli/src/cmd_bump_versions.rs`

**Step 1: Implement `apply_bumps`**

```rust
fn apply_pattern_bumps(
    patterns_dir: &Path,
    bumps: &HashMap<String, i32>,
) -> anyhow::Result<()> {
    for (id, new_version) in bumps {
        let meta_path = patterns_dir.join(id).join("meta.json");
        let content = std::fs::read_to_string(&meta_path)
            .map_err(|e| anyhow::anyhow!("Failed to read {}: {e}", meta_path.display()))?;
        let mut value: serde_json::Value = serde_json::from_str(&content)?;
        value["dataVersion"] = serde_json::json!(new_version);
        let formatted = serde_json::to_string_pretty(&value)? + "\n";
        sp_server::services::atomic_write_str(&meta_path, &formatted)?;
    }
    Ok(())
}

fn apply_root_bump(
    patterns_dir: &Path,
    bumps: &HashMap<String, i32>,
    previous_ref: &str,
    patterns_dir_name: &str,
) -> anyhow::Result<i32> {
    let root_meta_path = patterns_dir.join("meta.json");
    let content = std::fs::read_to_string(&root_meta_path)?;
    let mut root: serde_json::Value = serde_json::from_str(&content)?;

    // Bump root dataVersion from previous
    let prev_root_path = format!("{patterns_dir_name}/meta.json");
    let prev_root_version = git_show_file(previous_ref, &prev_root_path)?
        .and_then(|c| serde_json::from_str::<serde_json::Value>(&c).ok())
        .and_then(|v| v["dataVersion"].as_i64())
        .unwrap_or(0) as i32;
    let new_root_version = prev_root_version + 1;
    root["dataVersion"] = serde_json::json!(new_root_version);

    // Update pattern entries
    if let Some(patterns) = root["patterns"].as_array_mut() {
        for pattern in patterns.iter_mut() {
            if let Some(id) = pattern["id"].as_str() {
                if let Some(&new_version) = bumps.get(id) {
                    pattern["dataVersion"] = serde_json::json!(new_version);
                }
                // Refresh playlistCount from current meta
                let meta_path = patterns_dir.join(id).join("meta.json");
                if let Ok(meta_content) = std::fs::read_to_string(&meta_path) {
                    if let Ok(meta) = serde_json::from_str::<PatternMeta>(&meta_content) {
                        pattern["playlistCount"] = serde_json::json!(meta.playlists.len());
                    }
                }
            }
        }
    }

    let formatted = serde_json::to_string_pretty(&root)? + "\n";
    sp_server::services::atomic_write_str(&root_meta_path, &formatted)?;
    Ok(new_root_version)
}
```

**Step 2: Commit**

```
feat: add file write logic for bump-versions
```

---

### Task 4: Wire up the `run` entry point and CLI subcommand

**Files:**
- Modify: `crates/sp_cli/src/cmd_bump_versions.rs`
- Modify: `crates/sp_cli/src/main.rs`

**Step 1: Implement `run` function and output structs**

```rust
use std::collections::HashMap;
use std::path::Path;

use sp_core::models::PatternMeta;

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

pub fn run(patterns_dir: &str, previous_ref: &str, json: bool) -> anyhow::Result<i32> {
    let patterns_path = std::path::PathBuf::from(patterns_dir);
    if !patterns_path.join("meta.json").exists() {
        anyhow::bail!("No meta.json found in {patterns_dir}");
    }

    let patterns_dir_name = patterns_path
        .file_name()
        .and_then(|n| n.to_str())
        .unwrap_or("patterns");

    let diff_output = git_diff_names(previous_ref, &patterns_path)?;
    let changed_ids = extract_changed_pattern_ids(&diff_output, patterns_dir_name);

    if changed_ids.is_empty() {
        if json {
            println!("{}", serde_json::to_string_pretty(&BumpSummary {
                changed_patterns: 0,
                root_version: 0,
                bumps: vec![],
            })?);
        } else {
            eprintln!("No pattern changes detected.");
        }
        return Ok(0);
    }

    let previous_versions = load_previous_versions(previous_ref, &changed_ids, patterns_dir_name)?;
    let bumps = compute_version_bumps(&changed_ids, &previous_versions);

    apply_pattern_bumps(&patterns_path, &bumps)?;
    let new_root_version = apply_root_bump(&patterns_path, &bumps, previous_ref, patterns_dir_name)?;

    let results: Vec<BumpResult> = changed_ids
        .iter()
        .map(|id| BumpResult {
            pattern_id: id.clone(),
            previous_version: *previous_versions.get(id).unwrap_or(&0),
            new_version: *bumps.get(id).unwrap_or(&1),
        })
        .collect();

    if json {
        println!("{}", serde_json::to_string_pretty(&BumpSummary {
            changed_patterns: results.len(),
            root_version: new_root_version,
            bumps: results,
        })?);
    } else {
        eprintln!("Detecting changes from {previous_ref}...");
        for r in &results {
            eprintln!("  {}: version {} -> {}", r.pattern_id, r.previous_version, r.new_version);
        }
        eprintln!("  Root meta: version -> {new_root_version}");
        eprintln!("Version bump complete.");
    }

    Ok(0)
}
```

**Step 2: Add subcommand to `main.rs`**

Add `mod cmd_bump_versions;` and the `BumpVersions` variant:

```rust
/// Bump dataVersion fields for changed patterns (CI use)
BumpVersions {
    /// Path to patterns directory
    #[arg(default_value = "patterns")]
    patterns_dir: String,
    /// Git ref for previous state (e.g. HEAD~1)
    previous_ref: String,
    /// Output as JSON
    #[arg(long)]
    json: bool,
},
```

Add match arm:

```rust
Commands::BumpVersions {
    patterns_dir,
    previous_ref,
    json,
} => match cmd_bump_versions::run(&patterns_dir, &previous_ref, json) {
    Ok(code) => code,
    Err(e) => {
        eprintln!("Error: {e}");
        1
    }
},
```

**Step 3: Run `cargo build` and `cargo test -p sp_cli`**

Expected: Build succeeds, all tests pass

**Step 4: Run `cargo clippy -p sp_cli -- -W warnings`**

Expected: Zero warnings

**Step 5: Commit**

```
feat: wire bump-versions subcommand into CLI
```

---

### Task 5: Integration test with a temp git repo

**Files:**
- Modify: `crates/sp_cli/src/cmd_bump_versions.rs`

**Step 1: Write integration test**

```rust
#[cfg(test)]
mod tests {
    // ... existing unit tests ...

    #[test]
    fn integration_bump_versions_in_temp_repo() {
        use std::process::Command;
        use tempfile::TempDir;

        let tmp = TempDir::new().unwrap();
        let repo = tmp.path();

        // Init git repo
        Command::new("git").args(["init"]).current_dir(repo).output().unwrap();
        Command::new("git").args(["config", "user.email", "test@test.com"]).current_dir(repo).output().unwrap();
        Command::new("git").args(["config", "user.name", "Test"]).current_dir(repo).output().unwrap();

        let patterns = repo.join("patterns");
        std::fs::create_dir_all(patterns.join("show_a/playlists")).unwrap();

        // Root meta
        std::fs::write(
            patterns.join("meta.json"),
            r#"{"dataVersion": 1, "schemaVersion": 2, "patterns": [{"id": "show_a", "dataVersion": 1, "displayName": "Show A", "feedUrlHint": "https://example.com", "playlistCount": 1}]}"#
        ).unwrap();

        // Pattern meta
        std::fs::write(
            patterns.join("show_a/meta.json"),
            r#"{"dataVersion": 1, "id": "show_a", "feedUrls": ["https://example.com"], "playlists": ["main", "bonus"]}"#
        ).unwrap();

        // Playlist
        std::fs::write(
            patterns.join("show_a/playlists/main.json"),
            r#"{"resolverType": "category"}"#
        ).unwrap();

        // Initial commit
        Command::new("git").args(["add", "."]).current_dir(repo).output().unwrap();
        Command::new("git").args(["commit", "-m", "init"]).current_dir(repo).output().unwrap();

        // Make a change
        std::fs::write(
            patterns.join("show_a/playlists/main.json"),
            r#"{"resolverType": "rss"}"#
        ).unwrap();
        Command::new("git").args(["add", "."]).current_dir(repo).output().unwrap();
        Command::new("git").args(["commit", "-m", "update"]).current_dir(repo).output().unwrap();

        // Run bump-versions in the repo context
        let diff = Command::new("git")
            .args(["diff", "HEAD~1", "--name-only", "--", "patterns"])
            .current_dir(repo)
            .output()
            .unwrap();
        let diff_output = String::from_utf8_lossy(&diff.stdout);
        let changed = super::extract_changed_pattern_ids(&diff_output, "patterns");
        assert_eq!(changed, vec!["show_a"]);

        let mut prev: std::collections::HashMap<String, i32> = std::collections::HashMap::new();
        prev.insert("show_a".into(), 1);
        let bumps = super::compute_version_bumps(&changed, &prev);
        assert_eq!(bumps.get("show_a"), Some(&2));
    }
}
```

**Step 2: Add `tempfile` dev-dependency to `crates/sp_cli/Cargo.toml`**

```toml
[dev-dependencies]
tempfile = "3"
```

**Step 3: Run tests**

Run: `cargo test -p sp_cli`
Expected: All tests pass (unit + integration)

**Step 4: Run `cargo clippy -p sp_cli -- -W warnings`**

Expected: Zero warnings

**Step 5: Commit**

```
test: add integration test for bump-versions command
```
