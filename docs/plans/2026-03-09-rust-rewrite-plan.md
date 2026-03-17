# Rust Rewrite Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace Dart backend with Rust (Axum server + CLI), keeping React frontend unchanged.

**Architecture:** Three Rust crates (`sp_core`, `sp_server`, `sp_cli`) replace `packages/sp_shared`, `packages/sp_server`, and `mcp_server`. The React SPA in `packages/sp_react` stays as-is. A single binary `audiflow-editor` provides both the web server and CLI commands.

**Tech Stack:** Rust (serde, regex, jsonschema, axum, tokio, clap, feed-rs, notify, rust-embed, reqwest)

---

## Task 1: Scaffold Rust Workspace

**Files:**
- Create: `Cargo.toml` (workspace root)
- Create: `crates/sp_core/Cargo.toml`
- Create: `crates/sp_core/src/lib.rs`
- Create: `crates/sp_server/Cargo.toml`
- Create: `crates/sp_server/src/lib.rs`
- Create: `crates/sp_cli/Cargo.toml`
- Create: `crates/sp_cli/src/main.rs`
- Create: `.cargo/config.toml`

**Step 1: Create workspace Cargo.toml**

```toml
[workspace]
resolver = "2"
members = [
    "crates/sp_core",
    "crates/sp_server",
    "crates/sp_cli",
]

[workspace.package]
version = "0.1.0"
edition = "2024"
license = "AGPL-3.0-or-later"

[workspace.dependencies]
serde = { version = "1", features = ["derive"] }
serde_json = "1"
```

**Step 2: Create sp_core/Cargo.toml**

```toml
[package]
name = "sp_core"
version.workspace = true
edition.workspace = true

[dependencies]
serde = { workspace = true }
serde_json = { workspace = true }
regex = "1"
jsonschema = "0.29"
sha2 = "0.10"
chrono = { version = "0.4", features = ["serde"] }
```

**Step 3: Create sp_server/Cargo.toml**

```toml
[package]
name = "sp_server"
version.workspace = true
edition.workspace = true

[dependencies]
sp_core = { path = "../sp_core" }
serde = { workspace = true }
serde_json = { workspace = true }
axum = "0.8"
tokio = { version = "1", features = ["full"] }
tower-http = { version = "0.6", features = ["cors", "fs"] }
notify = "7"
rust-embed = "8"
feed-rs = "2"
reqwest = { version = "0.12", features = ["json"] }
```

**Step 4: Create sp_cli/Cargo.toml**

```toml
[package]
name = "sp_cli"
version.workspace = true
edition.workspace = true

[[bin]]
name = "audiflow-editor"
path = "src/main.rs"

[dependencies]
sp_core = { path = "../sp_core" }
sp_server = { path = "../sp_server" }
serde = { workspace = true }
serde_json = { workspace = true }
clap = { version = "4", features = ["derive"] }
tokio = { version = "1", features = ["full"] }
```

**Step 5: Create minimal lib.rs and main.rs stubs**

`crates/sp_core/src/lib.rs`:
```rust
pub mod models;
pub mod resolvers;
pub mod services;
pub mod schema;
```

`crates/sp_server/src/lib.rs`:
```rust
pub mod routes;
pub mod services;
pub mod static_files;
```

`crates/sp_cli/src/main.rs`:
```rust
fn main() {
    println!("audiflow-editor");
}
```

**Step 6: Create .cargo/config.toml for fast builds on macOS**

```toml
[target.aarch64-apple-darwin]
rustflags = ["-C", "link-arg=-fuse-ld=/opt/homebrew/bin/lld"]

[target.x86_64-apple-darwin]
rustflags = ["-C", "link-arg=-fuse-ld=/opt/homebrew/bin/lld"]
```

**Step 7: Verify workspace compiles**

Run: `cargo build`
Expected: Successful compilation with no errors.

**Step 8: Add Rust artifacts to .gitignore**

Append to `.gitignore`:
```
/target/
```

**Step 9: Commit**

```bash
git add Cargo.toml crates/ .cargo/ .gitignore
git commit -m "chore: scaffold rust workspace with sp_core, sp_server, sp_cli"
```

---

## Task 2: Port Core Models (sp_core/models)

Port all Dart models from `packages/sp_shared/lib/src/models/` to Rust structs with serde.

**Files:**
- Create: `crates/sp_core/src/models/mod.rs`
- Create: `crates/sp_core/src/models/episode_data.rs`
- Create: `crates/sp_core/src/models/sort.rs`
- Create: `crates/sp_core/src/models/title_extractor.rs`
- Create: `crates/sp_core/src/models/episode_extractor.rs`
- Create: `crates/sp_core/src/models/group_def.rs`
- Create: `crates/sp_core/src/models/playlist_definition.rs`
- Create: `crates/sp_core/src/models/playlist.rs`
- Create: `crates/sp_core/src/models/pattern_config.rs`
- Create: `crates/sp_core/src/models/pattern_meta.rs`
- Create: `crates/sp_core/src/models/root_meta.rs`
- Create: `crates/sp_core/src/models/preview_grouping.rs`
- Test: `crates/sp_core/tests/models/`

### Key mapping rules

All models use `#[derive(Debug, Clone, Serialize, Deserialize)]`.
Optional fields use `Option<T>` with `#[serde(skip_serializing_if = "Option::is_none")]`.
Boolean defaults use `#[serde(default)]` and `#[serde(skip_serializing_if = "std::ops::Not::not")]`.
Integer defaults use `#[serde(default)]` and `#[serde(skip_serializing_if = "is_zero")]` helper.
Enums use `#[serde(rename_all = "camelCase")]`.

**Step 1: Write tests for EpisodeData and sort enums**

Create `crates/sp_core/tests/models/mod.rs` and `crates/sp_core/tests/models/episode_data_test.rs`:

```rust
use sp_core::models::episode_data::{EpisodeData, SimpleEpisodeData};

#[test]
fn simple_episode_data_fields() {
    let ep = SimpleEpisodeData {
        id: 1,
        title: "Episode 1".into(),
        description: Some("Desc".into()),
        season_number: Some(2),
        episode_number: Some(3),
        published_at: None,
        image_url: None,
    };
    assert_eq!(ep.id(), 1);
    assert_eq!(ep.title(), "Episode 1");
    assert_eq!(ep.season_number(), Some(2));
}
```

Create `crates/sp_core/tests/models/sort_test.rs`:

```rust
use sp_core::models::sort::*;

#[test]
fn sort_rule_roundtrip() {
    let rule = SortRule {
        field: SortField::PlaylistNumber,
        order: SortOrder::Ascending,
    };
    let json = serde_json::to_value(&rule).unwrap();
    assert_eq!(json["field"], "playlistNumber");
    assert_eq!(json["order"], "ascending");
    let back: SortRule = serde_json::from_value(json).unwrap();
    assert_eq!(back.field, SortField::PlaylistNumber);
}

#[test]
fn episode_sort_rule_roundtrip() {
    let rule = EpisodeSortRule {
        field: EpisodeSortField::PublishedAt,
        order: SortOrder::Descending,
    };
    let json = serde_json::to_value(&rule).unwrap();
    assert_eq!(json["field"], "publishedAt");
    let back: EpisodeSortRule = serde_json::from_value(json).unwrap();
    assert_eq!(back.order, SortOrder::Descending);
}
```

**Step 2: Run tests to verify they fail**

Run: `cargo test -p sp_core`
Expected: Compilation errors (modules don't exist yet).

**Step 3: Implement episode_data.rs**

```rust
use chrono::{DateTime, Utc};

pub trait EpisodeData {
    fn id(&self) -> i64;
    fn title(&self) -> &str;
    fn description(&self) -> Option<&str>;
    fn season_number(&self) -> Option<i32>;
    fn episode_number(&self) -> Option<i32>;
    fn published_at(&self) -> Option<DateTime<Utc>>;
    fn image_url(&self) -> Option<&str>;
}

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SimpleEpisodeData {
    pub id: i64,
    pub title: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub description: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub season_number: Option<i32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub episode_number: Option<i32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub published_at: Option<DateTime<Utc>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub image_url: Option<String>,
}

impl EpisodeData for SimpleEpisodeData {
    fn id(&self) -> i64 { self.id }
    fn title(&self) -> &str { &self.title }
    fn description(&self) -> Option<&str> { self.description.as_deref() }
    fn season_number(&self) -> Option<i32> { self.season_number }
    fn episode_number(&self) -> Option<i32> { self.episode_number }
    fn published_at(&self) -> Option<DateTime<Utc>> { self.published_at }
    fn image_url(&self) -> Option<&str> { self.image_url.as_deref() }
}
```

**Step 4: Implement sort.rs**

```rust
#[derive(Debug, Clone, Copy, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum SortField {
    PlaylistNumber,
    NewestEpisodeDate,
    Alphabetical,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum EpisodeSortField {
    PublishedAt,
    EpisodeNumber,
    Title,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum SortOrder {
    Ascending,
    Descending,
}

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct SortRule {
    pub field: SortField,
    pub order: SortOrder,
}

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct EpisodeSortRule {
    pub field: EpisodeSortField,
    pub order: SortOrder,
}
```

**Step 5: Implement title_extractor.rs**

Port `SmartPlaylistTitleExtractor` including the recursive `extract()` method.

```rust
use super::episode_data::EpisodeData;

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct TitleExtractor {
    pub source: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub pattern: Option<String>,
    #[serde(default, skip_serializing_if = "is_zero")]
    pub group: i32,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub template: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub fallback: Option<Box<TitleExtractor>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub fallback_value: Option<String>,
}

fn is_zero(v: &i32) -> bool { *v == 0 }

impl TitleExtractor {
    pub fn extract(&self, episode: &dyn EpisodeData) -> Option<String> {
        let season_num = episode.season_number();
        if let Some(ref fv) = self.fallback_value {
            if season_num.is_none() || season_num.is_some_and(|n| n < 1) {
                return Some(fv.clone());
            }
        }

        let source_value = self.get_source_value(episode);

        let source_value = match source_value {
            Some(v) => v,
            None => return self.fallback.as_ref().and_then(|f| f.extract(episode)),
        };

        let result = if let Some(ref pat) = self.pattern {
            self.extract_with_pattern(&source_value, pat)
        } else {
            Some(source_value)
        };

        let result = match result {
            Some(r) => r,
            None => return self.fallback.as_ref().and_then(|f| f.extract(episode)),
        };

        Some(match &self.template {
            Some(tmpl) => tmpl.replace("{value}", &result),
            None => result,
        })
    }

    fn get_source_value(&self, episode: &dyn EpisodeData) -> Option<String> {
        match self.source.as_str() {
            "title" => Some(episode.title().to_string()),
            "description" => episode.description().map(String::from),
            "seasonNumber" => episode.season_number().map(|n| n.to_string()),
            "episodeNumber" => episode.episode_number().map(|n| n.to_string()),
            _ => None,
        }
    }

    fn extract_with_pattern(&self, value: &str, pattern: &str) -> Option<String> {
        let regex = regex::Regex::new(pattern).ok()?;
        let captures = regex.captures(value)?;

        if self.group == 0 {
            captures.get(0).map(|m| m.as_str().to_string())
        } else {
            captures.get(self.group as usize).map(|m| m.as_str().to_string())
        }
    }
}
```

**Step 6: Implement episode_extractor.rs**

Port `SmartPlaylistEpisodeExtractor` with primary/fallback/RSS extraction chain.

```rust
use super::episode_data::EpisodeData;

#[derive(Debug, Clone, Default)]
pub struct EpisodeExtractionResult {
    pub season_number: Option<i32>,
    pub episode_number: Option<i32>,
}

impl EpisodeExtractionResult {
    pub fn has_values(&self) -> bool {
        self.season_number.is_some() || self.episode_number.is_some()
    }
}

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct EpisodeExtractor {
    pub source: String,
    pub pattern: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub season_group: Option<i32>,
    #[serde(default = "default_episode_group")]
    pub episode_group: i32,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub fallback_season_number: Option<i32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub fallback_episode_pattern: Option<String>,
    #[serde(default = "default_one", skip_serializing_if = "is_one")]
    pub fallback_episode_capture_group: i32,
    #[serde(default, skip_serializing_if = "std::ops::Not::not")]
    pub fallback_to_rss: bool,
}

fn default_episode_group() -> i32 { 2 }
fn default_one() -> i32 { 1 }
fn is_one(v: &i32) -> bool { *v == 1 }

impl EpisodeExtractor {
    pub fn extract(&self, episode: &dyn EpisodeData) -> EpisodeExtractionResult {
        let source_value = match self.source.as_str() {
            "title" => Some(episode.title().to_string()),
            "description" => episode.description().map(String::from),
            _ => None,
        };

        let Some(source_value) = source_value else {
            return self.rss_fallback(episode);
        };

        let primary = self.extract_from_primary(&source_value);
        if primary.has_values() {
            return primary;
        }

        if let Some(ref fallback_pattern) = self.fallback_episode_pattern {
            let fallback = self.extract_from_fallback(&source_value, fallback_pattern);
            if fallback.has_values() {
                return fallback;
            }
        }

        self.rss_fallback(episode)
    }

    fn rss_fallback(&self, episode: &dyn EpisodeData) -> EpisodeExtractionResult {
        if !self.fallback_to_rss {
            return EpisodeExtractionResult::default();
        }
        EpisodeExtractionResult {
            season_number: None,
            episode_number: episode.episode_number(),
        }
    }

    fn extract_from_primary(&self, value: &str) -> EpisodeExtractionResult {
        let Ok(regex) = regex::Regex::new(&self.pattern) else {
            return EpisodeExtractionResult::default();
        };
        let Some(captures) = regex.captures(value) else {
            return EpisodeExtractionResult::default();
        };

        let season = self.season_group.and_then(|g| {
            captures.get(g as usize)
                .and_then(|m| m.as_str().parse::<i32>().ok())
        });

        let episode = captures.get(self.episode_group as usize)
            .and_then(|m| m.as_str().parse::<i32>().ok());

        EpisodeExtractionResult { season_number: season, episode_number: episode }
    }

    fn extract_from_fallback(&self, value: &str, pattern: &str) -> EpisodeExtractionResult {
        let Ok(regex) = regex::Regex::new(pattern) else {
            return EpisodeExtractionResult::default();
        };
        let Some(captures) = regex.captures(value) else {
            return EpisodeExtractionResult::default();
        };

        let episode = captures.get(self.fallback_episode_capture_group as usize)
            .and_then(|m| m.as_str().parse::<i32>().ok());

        EpisodeExtractionResult {
            season_number: self.fallback_season_number,
            episode_number: episode,
        }
    }
}
```

**Step 7: Implement group_def.rs**

Port `SmartPlaylistGroupDef` and its sub-types.

```rust
use super::episode_extractor::EpisodeExtractor;
use super::sort::EpisodeSortRule;
use super::title_extractor::TitleExtractor;

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct GroupDef {
    pub id: String,
    pub display_name: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub pattern: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub display: Option<GroupDefDisplay>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub episode_list: Option<GroupDefEpisodeList>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub episode_extractor: Option<EpisodeExtractor>,
}

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct GroupDefDisplay {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub show_date_range: Option<bool>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub year_binding: Option<String>,
}

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct GroupDefEpisodeList {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub show_year_headers: Option<bool>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub sort: Option<EpisodeSortRule>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub title_extractor: Option<TitleExtractor>,
}
```

**Step 8: Implement playlist_definition.rs**

Port `SmartPlaylistDefinition`, `EpisodeFilters`, `GroupListSettings`, `EpisodeListSettings`.

```rust
use super::episode_extractor::EpisodeExtractor;
use super::group_def::GroupDef;
use super::sort::{EpisodeSortRule, SortRule};
use super::title_extractor::TitleExtractor;

fn is_zero(v: &i32) -> bool { *v == 0 }

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PlaylistDefinition {
    pub id: String,
    pub display_name: String,
    pub resolver_type: String,
    pub playlist_structure: String,
    #[serde(default, skip_serializing_if = "is_zero")]
    pub priority: i32,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub episode_filters: Option<EpisodeFilters>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub null_season_group_key: Option<i32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub title_extractor: Option<TitleExtractor>,
    #[serde(default, skip_serializing_if = "std::ops::Not::not")]
    pub prepend_season_number: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub group_list: Option<GroupListSettings>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub episode_list: Option<EpisodeListSettings>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub episode_extractor: Option<EpisodeExtractor>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub groups: Option<Vec<GroupDef>>,
}

impl PlaylistDefinition {
    pub fn has_filters(&self) -> bool {
        match &self.episode_filters {
            None => false,
            Some(f) => {
                let has_require = f.require.as_ref().is_some_and(|r| !r.is_empty());
                let has_exclude = f.exclude.as_ref().is_some_and(|e| !e.is_empty());
                has_require || has_exclude
            }
        }
    }
}

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct EpisodeFilters {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub require: Option<Vec<EpisodeFilterEntry>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub exclude: Option<Vec<EpisodeFilterEntry>>,
}

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct EpisodeFilterEntry {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub title: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub description: Option<String>,
}

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct GroupListSettings {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub year_binding: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub user_sortable: Option<bool>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub show_date_range: Option<bool>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub sort: Option<SortRule>,
}

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct EpisodeListSettings {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub show_year_headers: Option<bool>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub sort: Option<EpisodeSortRule>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub title_extractor: Option<TitleExtractor>,
}
```

**Step 9: Implement playlist.rs**

Port `SmartPlaylist`, `SmartPlaylistGroup`, `SmartPlaylistGrouping`, and enums.

```rust
use chrono::{DateTime, Utc};

#[derive(Debug, Clone, Copy, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum PlaylistStructure {
    Split,
    Grouped,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum YearBinding {
    None,
    PinToYear,
    SplitByYear,
}

#[derive(Debug, Clone)]
pub struct PlaylistGroup {
    pub id: String,
    pub display_name: String,
    pub sort_key: i32,
    pub episode_ids: Vec<i64>,
    pub thumbnail_url: Option<String>,
    pub year_override: Option<YearBinding>,
    pub show_year_headers: Option<bool>,
    pub show_date_range: bool,
    pub earliest_date: Option<DateTime<Utc>>,
    pub latest_date: Option<DateTime<Utc>>,
    pub total_duration_ms: Option<i64>,
}

#[derive(Debug, Clone)]
pub struct Playlist {
    pub id: String,
    pub display_name: String,
    pub sort_key: i32,
    pub episode_ids: Vec<i64>,
    pub thumbnail_url: Option<String>,
    pub playlist_structure: PlaylistStructure,
    pub year_binding: YearBinding,
    pub show_year_headers: bool,
    pub show_date_range: bool,
    pub groups: Option<Vec<PlaylistGroup>>,
}

#[derive(Debug, Clone)]
pub struct Grouping {
    pub playlists: Vec<Playlist>,
    pub ungrouped_episode_ids: Vec<i64>,
    pub resolver_type: String,
}
```

**Step 10: Implement pattern_config.rs**

```rust
use super::playlist_definition::PlaylistDefinition;

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PatternConfig {
    pub id: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub podcast_guid: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub feed_urls: Option<Vec<String>>,
    #[serde(default, skip_serializing_if = "std::ops::Not::not")]
    pub year_grouped_episodes: bool,
    pub playlists: Vec<PlaylistDefinition>,
}

impl PatternConfig {
    pub fn matches_podcast(&self, guid: Option<&str>, feed_url: &str) -> bool {
        if let Some(ref pg) = self.podcast_guid {
            if guid == Some(pg.as_str()) {
                return true;
            }
        }
        if let Some(ref urls) = self.feed_urls {
            if urls.iter().any(|u| u == feed_url) {
                return true;
            }
        }
        false
    }
}
```

**Step 11: Implement pattern_meta.rs and root_meta.rs**

`pattern_meta.rs`:
```rust
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PatternMeta {
    #[serde(default = "default_one")]
    pub data_version: i32,
    pub id: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub podcast_guid: Option<String>,
    pub feed_urls: Vec<String>,
    #[serde(default, skip_serializing_if = "std::ops::Not::not")]
    pub year_grouped_episodes: bool,
    pub playlists: Vec<String>,
}

fn default_one() -> i32 { 1 }
```

`root_meta.rs`:
```rust
use super::pattern_summary::PatternSummary;

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct RootMeta {
    pub data_version: i32,
    pub schema_version: i32,
    pub patterns: Vec<PatternSummary>,
}
```

Create `pattern_summary.rs`:
```rust
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PatternSummary {
    pub id: String,
    #[serde(default = "default_one")]
    pub data_version: i32,
    pub display_name: String,
    pub feed_url_hint: String,
    pub playlist_count: i32,
}

fn default_one() -> i32 { 1 }
```

**Step 12: Implement preview_grouping.rs**

```rust
use super::playlist::Playlist;
use std::collections::HashMap;

#[derive(Debug, Clone)]
pub struct PlaylistPreviewResult {
    pub definition_id: String,
    pub playlist: Playlist,
    pub claimed_by_others: HashMap<i64, String>,
}

#[derive(Debug, Clone)]
pub struct PreviewGrouping {
    pub playlist_results: Vec<PlaylistPreviewResult>,
    pub ungrouped_episode_ids: Vec<i64>,
    pub resolver_type: String,
}
```

**Step 13: Wire up models/mod.rs**

```rust
pub mod episode_data;
pub mod episode_extractor;
pub mod group_def;
pub mod pattern_config;
pub mod pattern_meta;
pub mod pattern_summary;
pub mod playlist;
pub mod playlist_definition;
pub mod preview_grouping;
pub mod root_meta;
pub mod sort;
pub mod title_extractor;
```

**Step 14: Write JSON round-trip tests for PlaylistDefinition**

Test that a complete PlaylistDefinition serializes/deserializes matching the Dart JSON format exactly.

```rust
#[test]
fn playlist_definition_json_roundtrip() {
    let json_str = r#"{
        "id": "main",
        "displayName": "Main",
        "resolverType": "rss",
        "playlistStructure": "grouped",
        "priority": 1,
        "episodeFilters": {
            "require": [{"title": "S\\d+"}],
            "exclude": [{"title": "Bonus"}]
        },
        "nullSeasonGroupKey": 0,
        "prependSeasonNumber": true
    }"#;
    let def: PlaylistDefinition = serde_json::from_str(json_str).unwrap();
    assert_eq!(def.id, "main");
    assert_eq!(def.priority, 1);
    assert!(def.has_filters());

    let back = serde_json::to_value(&def).unwrap();
    assert_eq!(back["resolverType"], "rss");
    assert_eq!(back["playlistStructure"], "grouped");
}

#[test]
fn playlist_definition_omits_defaults() {
    let json_str = r#"{
        "id": "fallback",
        "displayName": "All",
        "resolverType": "year",
        "playlistStructure": "split"
    }"#;
    let def: PlaylistDefinition = serde_json::from_str(json_str).unwrap();
    assert_eq!(def.priority, 0);
    assert!(!def.has_filters());

    let back = serde_json::to_value(&def).unwrap();
    assert!(back.get("priority").is_none());
    assert!(back.get("prependSeasonNumber").is_none());
}
```

**Step 15: Run tests**

Run: `cargo test -p sp_core`
Expected: All tests pass.

**Step 16: Commit**

```bash
git add crates/sp_core/src/models/ crates/sp_core/tests/
git commit -m "feat: port all domain models to rust"
```

---

## Task 3: Port Resolvers (sp_core/resolvers)

Port the four resolvers from `packages/sp_shared/lib/src/resolvers/`.

**Files:**
- Create: `crates/sp_core/src/resolvers/mod.rs`
- Create: `crates/sp_core/src/resolvers/resolver.rs`
- Create: `crates/sp_core/src/resolvers/rss_resolver.rs`
- Create: `crates/sp_core/src/resolvers/category_resolver.rs`
- Create: `crates/sp_core/src/resolvers/year_resolver.rs`
- Create: `crates/sp_core/src/resolvers/title_appearance_resolver.rs`
- Test: `crates/sp_core/tests/resolvers/`

**Step 1: Write tests for resolver trait and RssResolver**

Reference Dart tests at `packages/sp_shared/test/resolvers/rss_metadata_resolver_test.dart`.

Key test cases:
- Groups episodes by seasonNumber
- Episodes with null season go to ungrouped (or to nullSeasonGroupKey if set)
- Returns None when no episodes have season numbers
- Uses titleExtractor for display names when provided

**Step 2: Run tests to verify they fail**

**Step 3: Implement resolver trait**

```rust
use crate::models::episode_data::EpisodeData;
use crate::models::playlist::Grouping;
use crate::models::playlist_definition::PlaylistDefinition;
use crate::models::sort::SortRule;

pub trait Resolver {
    fn resolver_type(&self) -> &str;
    fn default_sort(&self) -> SortRule;
    fn resolve(
        &self,
        episodes: &[&dyn EpisodeData],
        definition: Option<&PlaylistDefinition>,
    ) -> Option<Grouping>;
}
```

**Step 4: Implement RssResolver**

Port `rss_metadata_resolver.dart` line-for-line:
- Group by `season_number` (skip if < 1 unless nullSeasonGroupKey is set)
- Create `Playlist` per season with id `season_{n}`, sortKey = seasonNumber
- Sort playlists by sortKey ascending
- Use titleExtractor.extract() on first episode for displayName

**Step 5: Write tests for CategoryResolver**

Key test cases:
- Matches episodes against group patterns in order (first match wins)
- Fallback group (no pattern) catches unmatched episodes
- Returns None when definition or groups are missing
- Groups without matches are excluded from output

**Step 6: Implement CategoryResolver**

Port `category_resolver.dart`:
- Build compiled regex per groupDef with pattern
- Iterate episodes, first matching pattern wins
- Unmatched episodes go to fallback group (if exists) or ungrouped
- Assign sortKey sequentially to non-empty groups

**Step 7: Write tests for YearResolver**

Key test cases:
- Groups by publishedAt.year
- Episodes without publishedAt go to ungrouped
- Sorts playlists by year descending
- Returns None when no episodes have dates

**Step 8: Implement YearResolver**

Port `year_resolver.dart`.

**Step 9: Write tests for TitleAppearanceOrderResolver**

Key test cases:
- Extracts playlist names via titleExtractor or group pattern
- Orders playlists by first appearance (earliest publishedAt)
- Episodes without dates sorted after those with dates
- Returns None when definition is missing

**Step 10: Implement TitleAppearanceOrderResolver**

Port `title_appearance_order_resolver.dart`.

**Step 11: Run all resolver tests**

Run: `cargo test -p sp_core -- resolvers`
Expected: All pass.

**Step 12: Commit**

```bash
git add crates/sp_core/src/resolvers/ crates/sp_core/tests/resolvers/
git commit -m "feat: port all resolvers to rust"
```

---

## Task 4: Port Core Services (sp_core/services)

Port `episode_sorter`, `group_sorter`, `config_assembler`, and `resolver_service`.

**Files:**
- Create: `crates/sp_core/src/services/mod.rs`
- Create: `crates/sp_core/src/services/episode_sorter.rs`
- Create: `crates/sp_core/src/services/group_sorter.rs`
- Create: `crates/sp_core/src/services/config_assembler.rs`
- Create: `crates/sp_core/src/services/resolver_service.rs`
- Test: `crates/sp_core/tests/services/`

**Step 1: Write tests for episode_sorter**

Key test cases:
- Sorts by publishedAt ascending (oldest first)
- Episodes with dates sort before those without
- Unknown IDs sort last
- Single or empty lists returned as-is

**Step 2: Implement episode_sorter**

Port `episode_sorter.dart` — three-tier sort: has date (tier 0), no date (tier 1), unknown (tier 2).

**Step 3: Write tests for group_sorter**

Key test cases:
- Sorts by playlistNumber, newestEpisodeDate, alphabetical
- Descending order reverses result
- Null sort rule returns groups unchanged

**Step 4: Implement group_sorter**

Port `group_sorter.dart`.

**Step 5: Write tests for config_assembler**

Key test cases:
- Orders playlists according to meta.playlists list
- Appends playlists not in meta order

**Step 6: Implement config_assembler**

Port `config_assembler.dart`.

**Step 7: Write tests for resolver_service**

This is the most complex service. Key test cases:
- Matches config by GUID
- Matches config by feedUrl
- Filters episodes by require/exclude regexes (case-insensitive)
- Filtered definitions process before fallbacks
- Claimed episodes excluded from later definitions
- Falls back to resolver auto-detect when no config matches
- Returns None when episodes empty
- Preview mode tracks claimedByOthers per definition

Reference: `packages/sp_shared/test/services/smart_playlist_resolver_service_test.dart`

**Step 8: Implement resolver_service**

Port `smart_playlist_resolver_service.dart`:
- `resolve_smart_playlists()` — main entry point
- `resolve_for_preview()` — preview with claimed tracking
- `_filter_episodes()` — require (AND) + exclude (OR) with case-insensitive regex
- `_sort_by_processing_order()` — filtered first, then fallbacks, both sorted by priority

**Step 9: Run all service tests**

Run: `cargo test -p sp_core -- services`
Expected: All pass.

**Step 10: Commit**

```bash
git add crates/sp_core/src/services/ crates/sp_core/tests/services/
git commit -m "feat: port core services to rust"
```

---

## Task 5: Port Schema Validation (sp_core/schema)

**Files:**
- Create: `crates/sp_core/src/schema/mod.rs`
- Create: `crates/sp_core/src/schema/validator.rs`
- Copy: `packages/sp_shared/assets/*.schema.json` -> `crates/sp_core/assets/`
- Test: `crates/sp_core/tests/schema/`

**Step 1: Write tests**

Key test cases:
- Valid playlist definition passes validation
- Missing required field fails
- Invalid enum value fails
- Validates against correct schema based on type

**Step 2: Implement Validator**

```rust
use jsonschema::Validator as JsonSchemaValidator;
use serde_json::Value;
use std::path::Path;

pub enum SchemaType {
    PatternIndex,
    PatternMeta,
    PlaylistDefinition,
}

pub struct Validator {
    pattern_index: JsonSchemaValidator,
    pattern_meta: JsonSchemaValidator,
    playlist_definition: JsonSchemaValidator,
}

impl Validator {
    pub fn from_dir(schema_dir: &Path) -> Result<Self, Box<dyn std::error::Error>> {
        let load = |name: &str| -> Result<JsonSchemaValidator, Box<dyn std::error::Error>> {
            let path = schema_dir.join(name);
            let content = std::fs::read_to_string(&path)?;
            let schema: Value = serde_json::from_str(&content)?;
            Ok(JsonSchemaValidator::new(&schema)?)
        };

        Ok(Self {
            pattern_index: load("pattern-index.schema.json")?,
            pattern_meta: load("pattern-meta.schema.json")?,
            playlist_definition: load("playlist-definition.schema.json")?,
        })
    }

    pub fn validate(&self, schema_type: SchemaType, value: &Value) -> Vec<String> {
        let validator = match schema_type {
            SchemaType::PatternIndex => &self.pattern_index,
            SchemaType::PatternMeta => &self.pattern_meta,
            SchemaType::PlaylistDefinition => &self.playlist_definition,
        };
        validator.iter_errors(value)
            .map(|e| e.to_string())
            .collect()
    }
}
```

**Step 3: Copy schema files to crates/sp_core/assets/**

```bash
mkdir -p crates/sp_core/assets
cp packages/sp_shared/assets/*.schema.json crates/sp_core/assets/
```

**Step 4: Run tests**

Run: `cargo test -p sp_core -- schema`

**Step 5: Commit**

```bash
git add crates/sp_core/src/schema/ crates/sp_core/assets/ crates/sp_core/tests/schema/
git commit -m "feat: port schema validation to rust"
```

---

## Task 6: Port LocalConfigRepository (sp_server/services)

**Files:**
- Create: `crates/sp_server/src/services/mod.rs`
- Create: `crates/sp_server/src/services/local_config_repository.rs`
- Test: `crates/sp_server/tests/services/`

**Step 1: Write tests**

Key test cases:
- `list_patterns()` reads root meta.json and returns summaries
- `get_pattern_meta()` reads pattern-level meta.json
- `get_playlist()` reads playlist JSON and deserializes
- `assemble_config()` combines meta + playlists in correct order
- `save_playlist()` writes atomically (write .tmp, rename)
- `delete_playlist()` removes file
- `create_pattern()` creates directory structure
- Path validation rejects `..` and `/`

Reference: `packages/sp_server/test/services/local_config_repository_test.dart`

**Step 2: Implement LocalConfigRepository**

Key methods:
- All read operations are sync (blocking I/O is fine for local files)
- Write operations use atomic pattern: write to `path.tmp`, then `fs::rename`
- Path segments validated with `^[a-zA-Z0-9_-]+$` regex
- Uses `sp_core::services::config_assembler` for assembly

**Step 3: Run tests**

Run: `cargo test -p sp_server -- services`

**Step 4: Commit**

```bash
git add crates/sp_server/src/services/ crates/sp_server/tests/
git commit -m "feat: port local config repository to rust"
```

---

## Task 7: Port Feed Cache Service (sp_server/services)

**Files:**
- Create: `crates/sp_server/src/services/feed_cache.rs`
- Create: `crates/sp_server/src/services/feed_parser.rs`
- Update: `crates/sp_server/src/services/mod.rs`

**Step 1: Write tests**

Key test cases:
- Returns cached data when fresh
- Fetches and caches when expired or missing
- Parses RSS items into episode maps (title, description, seasonNumber, etc.)
- Handles corrupted cache gracefully (treats as miss)
- SHA-256 hash used for cache filenames

**Step 2: Implement feed_parser using feed-rs**

Map `feed_rs::model::Entry` to the episode JSON format the React app expects:
```rust
fn parse_feed(content: &str) -> Vec<serde_json::Value> {
    // Use feed_rs::parser::parse()
    // Map each entry to {id, title, description, publishedAt, seasonNumber, episodeNumber, imageUrl}
    // Extract iTunes extensions for season/episode numbers
}
```

**Step 3: Implement DiskFeedCacheService**

Port `disk_feed_cache_service.dart`:
- SHA-256 hash URL for filename
- Check meta file for freshness (fetchedAt + TTL)
- Atomic writes: data before meta
- Use `reqwest` for HTTP fetch

**Step 4: Run tests**

**Step 5: Commit**

```bash
git add crates/sp_server/src/services/feed_cache.rs crates/sp_server/src/services/feed_parser.rs
git commit -m "feat: port feed cache and rss parser to rust"
```

---

## Task 8: Port FileWatcherService (sp_server/services)

**Files:**
- Create: `crates/sp_server/src/services/file_watcher.rs`
- Update: `crates/sp_server/src/services/mod.rs`

**Step 1: Write tests**

Key test cases:
- Emits events when files are created/modified/deleted
- Debounces rapid changes (200ms window)
- Ignores .tmp files
- Deduplicates same path in one debounce window

**Step 2: Implement FileWatcherService**

```rust
use notify::{Watcher, RecursiveMode, Event};
use tokio::sync::broadcast;

pub struct FileWatcherService {
    sender: broadcast::Sender<FileChangeEvent>,
}

pub struct FileChangeEvent {
    pub path: String,
    pub change_type: FileChangeType,
}

pub enum FileChangeType {
    Created,
    Modified,
    Deleted,
}
```

Use `notify::recommended_watcher()` with debounce. Filter out `.tmp` files. Broadcast via `tokio::sync::broadcast`.

**Step 3: Run tests**

**Step 4: Commit**

```bash
git add crates/sp_server/src/services/file_watcher.rs
git commit -m "feat: port file watcher service to rust"
```

---

## Task 9: Implement Axum Routes (sp_server/routes)

Port all HTTP routes from `packages/sp_server/lib/src/routes/`.

**Files:**
- Create: `crates/sp_server/src/routes/mod.rs`
- Create: `crates/sp_server/src/routes/health.rs`
- Create: `crates/sp_server/src/routes/schema.rs`
- Create: `crates/sp_server/src/routes/config.rs`
- Create: `crates/sp_server/src/routes/feed.rs`
- Create: `crates/sp_server/src/routes/events.rs`
- Create: `crates/sp_server/src/routes/preview.rs`
- Create: `crates/sp_server/src/app.rs`
- Test: `crates/sp_server/tests/routes/`

**Step 1: Write integration tests**

Use `axum::test_helpers` or direct `tower::ServiceExt::oneshot()`:

```rust
#[tokio::test]
async fn health_returns_ok() {
    let app = create_test_app();
    let resp = app.oneshot(Request::get("/api/health").body(Body::empty()).unwrap()).await.unwrap();
    assert_eq!(resp.status(), StatusCode::OK);
}
```

Key test cases per route:
- Health returns 200 with `{status: "ok"}`
- Schema returns JSON schema
- GET patterns returns list
- GET pattern/{id}/assembled returns combined config
- PUT playlist validates then saves
- POST validate returns errors array
- POST preview returns playlists + ungrouped + debug info
- GET feeds fetches and caches RSS
- GET events returns SSE stream
- DELETE pattern removes directory
- 404 for unknown patterns

**Step 2: Implement shared AppState**

```rust
use std::sync::Arc;

pub struct AppState {
    pub config_repo: LocalConfigRepository,
    pub feed_cache: DiskFeedCacheService,
    pub validator: Validator,
    pub file_watcher: FileWatcherService,
    pub schema_json: serde_json::Value,
}

pub type SharedState = Arc<AppState>;
```

**Step 3: Implement health and schema routes**

**Step 4: Implement config CRUD routes**

Follow the same request/response JSON format as the Dart server:
- Responses use pretty-printed 2-space indent JSON
- Error responses: `{error: "message", errors: [...]}`
- Validate path segments
- Round-trip through typed models for canonical field ordering

**Step 5: Implement preview route**

Port the preview pipeline from `config_routes.dart`:
1. Parse config to `PatternConfig`
2. Fetch feed via cache service
3. Enrich episodes with extracted season/episode numbers
4. Run resolver chain
5. Return structured response

**Step 6: Implement feed route**

**Step 7: Implement SSE events route**

```rust
async fn sse_events(State(state): State<SharedState>) -> Sse<impl Stream<Item = ...>> {
    let rx = state.file_watcher.subscribe();
    // Convert broadcast receiver to SSE stream
}
```

**Step 8: Wire up router in app.rs**

```rust
pub fn create_router(state: SharedState) -> Router {
    Router::new()
        .route("/api/health", get(health))
        .route("/api/schema", get(get_schema))
        // ... all routes ...
        .fallback(static_handler)
        .layer(CorsLayer::permissive())
        .with_state(state)
}
```

**Step 9: Run all route tests**

Run: `cargo test -p sp_server -- routes`

**Step 10: Commit**

```bash
git add crates/sp_server/src/routes/ crates/sp_server/src/app.rs crates/sp_server/tests/routes/
git commit -m "feat: port all axum routes"
```

---

## Task 10: Implement Static File Serving (sp_server)

**Files:**
- Create: `crates/sp_server/src/static_files.rs`

**Step 1: Implement rust-embed static handler**

```rust
use rust_embed::Embed;

#[derive(Embed)]
#[folder = "../../packages/sp_react/dist/"]
struct ReactAssets;

pub async fn static_handler(uri: Uri) -> impl IntoResponse {
    let path = uri.path().trim_start_matches('/');

    // Try exact file match
    if let Some(content) = ReactAssets::get(path) {
        return (content_type(path), content.data.to_vec()).into_response();
    }

    // SPA fallback: serve index.html for non-file paths
    if !path.contains('.') {
        if let Some(content) = ReactAssets::get("index.html") {
            return ([("content-type", "text/html")], content.data.to_vec()).into_response();
        }
    }

    StatusCode::NOT_FOUND.into_response()
}
```

**Step 2: Add --static-dir runtime override**

When `--static-dir` is passed, serve from disk via `tower_http::services::ServeDir` instead of embedded assets.

**Step 3: Test that SPA fallback works**

**Step 4: Commit**

```bash
git add crates/sp_server/src/static_files.rs
git commit -m "feat: add embedded react assets with spa fallback"
```

---

## Task 11: Implement CLI (sp_cli)

**Files:**
- Create: `crates/sp_cli/src/main.rs`
- Create: `crates/sp_cli/src/cmd_serve.rs`
- Create: `crates/sp_cli/src/cmd_validate.rs`
- Create: `crates/sp_cli/src/cmd_format.rs`

**Step 1: Write tests for validate command**

Key test cases:
- Validates all files when no file args
- Validates single file when path given
- Auto-detects schema type from path
- Exit code 0 for valid, 1 for errors
- Errors printed as structured JSON to stderr

**Step 2: Implement clap CLI structure**

```rust
use clap::{Parser, Subcommand};

#[derive(Parser)]
#[command(name = "audiflow-editor", about = "Smart playlist editor")]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    Serve {
        #[arg(long, default_value = ".")]
        data_dir: String,
        #[arg(long, default_value = "8080")]
        port: u16,
        #[arg(long)]
        static_dir: Option<String>,
    },
    Validate {
        #[arg(long, default_value = ".")]
        data_dir: String,
        files: Vec<String>,
    },
    Format {
        #[arg(long, default_value = ".")]
        data_dir: String,
        #[arg(long)]
        check: bool,
        files: Vec<String>,
    },
}
```

**Step 3: Implement cmd_serve**

```rust
pub async fn run(data_dir: &str, port: u16, static_dir: Option<&str>) -> Result<()> {
    // Verify patterns/meta.json exists
    // Create AppState with all services
    // Build router
    // Bind to localhost:port
    // Print startup message
    // Run server
}
```

**Step 4: Implement cmd_validate**

```rust
pub fn run(data_dir: &str, files: &[String]) -> Result<i32> {
    let validator = Validator::from_dir(&schema_dir)?;

    if files.is_empty() {
        // Validate all: root meta.json, each pattern meta.json, each playlist
        validate_all(data_dir, &validator)
    } else {
        // Validate specific files
        validate_files(data_dir, files, &validator)
    }
}

fn detect_schema_type(path: &str) -> SchemaType {
    if path.ends_with("playlists/") || path.contains("/playlists/") {
        SchemaType::PlaylistDefinition
    } else if path.contains("/patterns/") && path.ends_with("meta.json") {
        SchemaType::PatternMeta
    } else {
        SchemaType::PatternIndex
    }
}
```

**Step 5: Implement cmd_format**

```rust
pub fn run(data_dir: &str, check: bool, files: &[String]) -> Result<i32> {
    // For each JSON file:
    // 1. Read file
    // 2. Parse JSON
    // 3. Re-serialize with 2-space indent + trailing newline
    // 4. If --check: compare with original, exit 1 if different
    // 5. If not --check: write formatted version back (only if changed)
}
```

**Step 6: Run CLI tests**

Run: `cargo test -p sp_cli`

**Step 7: Test CLI end-to-end manually**

Run: `cargo run -- validate --data-dir ../audiflow-smartplaylist-dev`
Expected: Validates all configs and reports results.

Run: `cargo run -- format --check --data-dir ../audiflow-smartplaylist-dev`
Expected: Reports whether any files need formatting.

**Step 8: Commit**

```bash
git add crates/sp_cli/
git commit -m "feat: implement cli with serve, validate, and format commands"
```

---

## Task 12: Update Makefile and Build Configuration

**Files:**
- Modify: `Makefile`
- Modify: `Dockerfile`
- Modify: `CLAUDE.md`

**Step 1: Rewrite Makefile**

```makefile
DATA_DIR ?= ../audiflow-smartplaylist
SERVER_PORT ?= 8080

.PHONY: dev-server dev-ui build test validate format

dev-server:
	cargo run -- serve --data-dir $(DATA_DIR) --port $(SERVER_PORT)

dev-ui:
	cd packages/sp_react && pnpm dev

build:
	pnpm --filter sp_react build
	cargo build --release

test:
	cargo test
	cd packages/sp_react && pnpm test

validate:
	cargo run -- validate --data-dir $(DATA_DIR)

format:
	cargo run -- format --data-dir $(DATA_DIR)
```

**Step 2: Rewrite Dockerfile**

```dockerfile
# Stage 1: Build React
FROM node:22-slim AS web-build
WORKDIR /build
RUN corepack enable && corepack prepare pnpm@latest --activate
COPY packages/sp_react/package.json packages/sp_react/pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile
COPY packages/sp_react/ .
RUN pnpm build

# Stage 2: Build Rust
FROM rust:1-bookworm AS rust-build
WORKDIR /build
COPY Cargo.toml Cargo.lock ./
COPY crates/ crates/
COPY --from=web-build /build/dist packages/sp_react/dist/
RUN cargo build --release

# Stage 3: Runtime
FROM debian:bookworm-slim
COPY --from=rust-build /build/target/release/audiflow-editor /usr/local/bin/
EXPOSE 8080
ENTRYPOINT ["audiflow-editor", "serve", "--port", "8080"]
```

**Step 3: Update CLAUDE.md**

Remove references to Dart packages, pubspec.yaml, `flutter analyze`, `flutter test`.
Add Rust commands: `cargo build`, `cargo test`, `cargo clippy`.

**Step 4: Commit**

```bash
git add Makefile Dockerfile CLAUDE.md
git commit -m "chore: update build config for rust"
```

---

## Task 13: Remove Dart Packages

**Files:**
- Delete: `packages/sp_shared/`
- Delete: `packages/sp_server/`
- Delete: `packages/sp_cli/` (the old Dart CLI)
- Delete: `mcp_server/`
- Delete: `pubspec.yaml`
- Delete: `analysis_options.yaml`

**Step 1: Verify Rust tests all pass**

Run: `cargo test`
Expected: All tests pass.

**Step 2: Verify React app still builds**

Run: `cd packages/sp_react && pnpm build`
Expected: Build succeeds.

**Step 3: Remove old Dart packages**

```bash
rm -rf packages/sp_shared packages/sp_server packages/sp_cli mcp_server
rm -f pubspec.yaml analysis_options.yaml
```

**Step 4: Update .claude/rules/project/ files**

Update `architecture.md` and `tech.md` to reflect Rust instead of Dart.

**Step 5: Commit**

```bash
git add -A
git commit -m "chore: remove dart packages, complete rust migration"
```

---

## Task 14: Add GitHub Release Workflow

**Files:**
- Create: `.github/workflows/release.yml`

**Step 1: Create workflow**

```yaml
name: Release
on:
  workflow_dispatch:
    inputs:
      version:
        description: 'Version (e.g. 0.1.0)'
        required: true

jobs:
  build:
    strategy:
      matrix:
        include:
          - target: x86_64-apple-darwin
            os: macos-latest
          - target: aarch64-apple-darwin
            os: macos-latest
          - target: x86_64-unknown-linux-gnu
            os: ubuntu-latest
          - target: aarch64-unknown-linux-gnu
            os: ubuntu-latest
          - target: x86_64-pc-windows-msvc
            os: windows-latest
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 22
      - run: cd packages/sp_react && pnpm install --frozen-lockfile && pnpm build
      - uses: dtolnay/rust-toolchain@stable
        with:
          targets: ${{ matrix.target }}
      - name: Install cross-compilation tools
        if: matrix.target == 'aarch64-unknown-linux-gnu'
        run: |
          sudo apt-get update
          sudo apt-get install -y gcc-aarch64-linux-gnu
      - run: cargo build --release --target ${{ matrix.target }}
      - name: Rename binary
        shell: bash
        run: |
          ext=""
          if [[ "${{ matrix.target }}" == *"windows"* ]]; then ext=".exe"; fi
          mv target/${{ matrix.target }}/release/audiflow-editor${ext} \
             audiflow-editor-${{ matrix.target }}${ext}
      - uses: actions/upload-artifact@v4
        with:
          name: binary-${{ matrix.target }}
          path: audiflow-editor-*

  release:
    needs: build
    runs-on: ubuntu-latest
    permissions:
      contents: write
    steps:
      - uses: actions/download-artifact@v4
        with:
          pattern: binary-*
          merge-multiple: true
      - uses: softprops/action-gh-release@v2
        with:
          tag_name: v${{ github.event.inputs.version }}
          name: v${{ github.event.inputs.version }}
          files: audiflow-editor-*
          generate_release_notes: true
```

**Step 2: Commit**

```bash
git add .github/workflows/release.yml
git commit -m "ci: add github release workflow"
```

---

## Task 15: End-to-End Verification

**Step 1: Run full test suite**

```bash
cargo test
cd packages/sp_react && pnpm test
```

**Step 2: Test server with React app**

```bash
cd packages/sp_react && pnpm build
cargo run -- serve --data-dir ../audiflow-smartplaylist-dev --port 8080
```

Open `http://localhost:8080` in browser. Verify:
- Pattern list loads
- Can navigate to editor
- Preview works (fetch feed + resolve)
- SSE events trigger on file changes

**Step 3: Test CLI commands**

```bash
cargo run -- validate --data-dir ../audiflow-smartplaylist-dev
cargo run -- format --check --data-dir ../audiflow-smartplaylist-dev
```

**Step 4: Build release binary**

```bash
pnpm --filter sp_react build
cargo build --release
ls -la target/release/audiflow-editor
```

Verify single binary works standalone.

**Step 5: Final commit if any fixes needed**

---

## Summary

| Task | Description | Estimated Complexity |
|------|-------------|---------------------|
| 1 | Scaffold Rust workspace | Low |
| 2 | Port core models | Medium |
| 3 | Port resolvers | Medium |
| 4 | Port core services | High |
| 5 | Port schema validation | Low |
| 6 | Port LocalConfigRepository | Medium |
| 7 | Port feed cache service | Medium |
| 8 | Port file watcher | Medium |
| 9 | Implement Axum routes | High |
| 10 | Static file serving | Low |
| 11 | Implement CLI | Medium |
| 12 | Update build config | Low |
| 13 | Remove Dart packages | Low |
| 14 | GitHub release workflow | Low |
| 15 | End-to-end verification | Medium |
