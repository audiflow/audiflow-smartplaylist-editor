use serde::{Deserialize, Deserializer, Serialize};

use super::group_def::GroupDef;
use super::is_zero;
use super::numbering_extractor::NumberingExtractor;
use super::sort::{EpisodeSortRule, SortRule};
use super::title_extractor::TitleExtractor;

/// Configuration for the selector dropdown in the app UI.
///
/// Controls how resolver groups map to selector entries:
/// - No `partitionBy` -> single entry (was `presentation: "combined"`)
/// - `partitionBy: "group"` -> one entry per group (was `presentation: "separate"`)
/// - `partitionBy: "seasonNumber"` -> one entry per season, groups as cards within
/// - `partitionBy: "year"` -> one entry per year, groups as cards within
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SelectorConfig {
    /// How to partition groups into selector entries.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub partition_by: Option<String>,

    /// Generates display names for partitioned selector entries.
    /// Used when partitionBy is "seasonNumber" or "year".
    #[serde(skip_serializing_if = "Option::is_none")]
    pub title_extractor: Option<TitleExtractor>,
}

/// v5 grouping configuration: how episodes are organized into groups.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct GroupingConfig {
    /// The grouping strategy (was `resolverType`).
    /// Values: "seasonNumber", "year", "titleDiscovery", "titleClassifier".
    #[serde(rename = "by")]
    pub by: String,

    /// Regex hint for titleDiscovery fallback (replaces groups[0].pattern overload).
    #[serde(skip_serializing_if = "Option::is_none")]
    pub discovery_hint: Option<String>,

    /// Configuration for extracting season and episode numbers.
    #[serde(skip_serializing_if = "Option::is_none", alias = "episodeExtractor")]
    pub numbering_extractor: Option<NumberingExtractor>,

    /// Static group definitions for titleClassifier-based grouping.
    /// Also used by titleDiscovery for extraction pattern.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub static_classifiers: Option<Vec<GroupDef>>,
}

/// v5 group item display defaults.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct GroupItemConfig {
    /// Show date range on group cards.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub show_date_range: Option<bool>,

    /// Pin group to its earliest year's section.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub pin_to_year: Option<bool>,

    /// Whether to prepend "S{n}" to resolver result names.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub prepend_season_number: Option<bool>,

    /// Configuration for extracting playlist/group display names.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub title_extractor: Option<TitleExtractor>,
}

/// v5 episode item display defaults.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct EpisodeItemConfig {
    /// Configuration for extracting episode display names.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub title_extractor: Option<TitleExtractor>,
}

/// Deserializes the presentation field, normalizing legacy values.
/// Maps "grouped" -> "combined" and "split" -> "separate".
fn deserialize_presentation_optional<'de, D>(deserializer: D) -> Result<Option<String>, D::Error>
where
    D: Deserializer<'de>,
{
    let raw: Option<String> = Option::deserialize(deserializer)?;
    Ok(raw.map(|s| match s.as_str() {
        "grouped" => "combined".to_owned(),
        "split" => "separate".to_owned(),
        _ => s,
    }))
}

/// Unified per-playlist definition with all fields strongly typed.
///
/// v5 fields coexist with v4 legacy fields. The v4 fields are kept as
/// serde aliases so old JSON files still deserialize correctly.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PlaylistDefinition {
    pub id: String,
    pub display_name: String,

    // -- v5 fields --

    /// v5 grouping block: how episodes are organized into groups.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub grouping: Option<GroupingConfig>,

    /// v5 group listing settings.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub group_listing: Option<GroupListSettings>,

    /// v5 group item display defaults.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub group_item: Option<GroupItemConfig>,

    /// v5 episode listing settings.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub episode_listing: Option<EpisodeListSettings>,

    /// v5 episode item display defaults.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub episode_item: Option<EpisodeItemConfig>,

    // -- v4 legacy fields (aliases for backward compat) --

    /// Legacy v4 resolver type. Use `grouping.by` in v5.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub resolver_type: Option<String>,

    /// Accepts legacy `playlistStructure` key and normalizes legacy values
    /// (`grouped` -> `combined`, `split` -> `separate`).
    /// Deprecated in v5: use `selector` instead.
    #[serde(
        default,
        alias = "playlistStructure",
        deserialize_with = "deserialize_presentation_optional",
        skip_serializing_if = "Option::is_none"
    )]
    pub presentation: Option<String>,

    /// Selector configuration controlling how groups map to dropdown entries.
    /// Replaces `presentation` in v5.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub selector: Option<SelectorConfig>,

    /// Episode claiming order among siblings (lower = first, default: 0).
    #[serde(default, skip_serializing_if = "is_zero")]
    pub priority: i32,

    /// Episode filters applied before resolver processing.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub episode_filters: Option<EpisodeFilters>,

    /// Legacy v4 top-level titleExtractor. Use `groupItem.titleExtractor` in v5.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub title_extractor: Option<TitleExtractor>,

    /// Legacy v4 prependSeasonNumber. Use `groupItem.prependSeasonNumber` in v5.
    #[serde(default, skip_serializing_if = "std::ops::Not::not")]
    pub prepend_season_number: bool,

    /// Legacy v4 groupList. Use `groupListing` in v5.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub group_list: Option<GroupListSettings>,

    /// Legacy v4 episodeList. Use `episodeListing` + `episodeItem` in v5.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub episode_list: Option<EpisodeListSettings>,

    /// Legacy v4 numberingExtractor. Use `grouping.numberingExtractor` in v5.
    #[serde(skip_serializing_if = "Option::is_none", alias = "episodeExtractor")]
    pub numbering_extractor: Option<NumberingExtractor>,

    /// Legacy v4 groups. Use `grouping.staticClassifiers` in v5.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub groups: Option<Vec<GroupDef>>,
}

impl PlaylistDefinition {
    /// Returns the effective resolver type, preferring v5 `grouping.by`
    /// and falling back to legacy `resolver_type`.
    pub fn effective_resolver_type(&self) -> &str {
        if let Some(g) = &self.grouping {
            return g.by.as_str();
        }
        self.resolver_type.as_deref().unwrap_or("seasonNumber")
    }

    /// Returns the effective numbering extractor, preferring v5 `grouping`
    /// and falling back to legacy top-level field.
    pub fn effective_numbering_extractor(&self) -> Option<&NumberingExtractor> {
        self.grouping
            .as_ref()
            .and_then(|g| g.numbering_extractor.as_ref())
            .or(self.numbering_extractor.as_ref())
    }

    /// Returns the effective title extractor for group display names,
    /// preferring v5 `groupItem` and falling back to legacy top-level field.
    pub fn effective_title_extractor(&self) -> Option<&TitleExtractor> {
        self.group_item
            .as_ref()
            .and_then(|gi| gi.title_extractor.as_ref())
            .or(self.title_extractor.as_ref())
    }

    /// Returns the effective static classifiers (groups), preferring v5
    /// `grouping.staticClassifiers` and falling back to legacy `groups`.
    pub fn effective_static_classifiers(&self) -> Option<&Vec<GroupDef>> {
        self.grouping
            .as_ref()
            .and_then(|g| g.static_classifiers.as_ref())
            .or(self.groups.as_ref())
    }

    /// Returns the effective episode list title extractor, preferring v5
    /// `episodeItem` and falling back to legacy `episodeList.titleExtractor`.
    pub fn effective_episode_title_extractor(&self) -> Option<&TitleExtractor> {
        self.episode_item
            .as_ref()
            .and_then(|ei| ei.title_extractor.as_ref())
            .or_else(|| {
                self.episode_list
                    .as_ref()
                    .and_then(|el| el.title_extractor.as_ref())
            })
    }

    /// Returns effective group list settings, preferring v5 `groupListing`
    /// and falling back to legacy `groupList`.
    pub fn effective_group_listing(&self) -> Option<&GroupListSettings> {
        self.group_listing.as_ref().or(self.group_list.as_ref())
    }

    /// Returns effective episode list settings, preferring v5 `episodeListing`
    /// and falling back to legacy `episodeList`.
    pub fn effective_episode_listing(&self) -> Option<&EpisodeListSettings> {
        self.episode_listing.as_ref().or(self.episode_list.as_ref())
    }

    /// Returns effective show_date_range, preferring v5 `groupItem`
    /// and falling back to legacy `groupList.showDateRange`.
    pub fn effective_show_date_range(&self) -> bool {
        self.group_item
            .as_ref()
            .and_then(|gi| gi.show_date_range)
            .or_else(|| {
                self.group_list
                    .as_ref()
                    .and_then(|gl| gl.show_date_range)
            })
            .unwrap_or(false)
    }

    /// Returns effective show_year_headers, preferring v5 `episodeListing`
    /// and falling back to legacy `episodeList`.
    pub fn effective_show_year_headers(&self) -> bool {
        self.effective_episode_listing()
            .and_then(|el| el.show_year_headers)
            .unwrap_or(false)
    }

    /// Returns the effective partition mode derived from `selector` or
    /// legacy `presentation`.
    ///
    /// - `selector.partitionBy: "group"` or `presentation: "separate"` -> `"group"`
    /// - `selector.partitionBy: "seasonNumber"` -> `"seasonNumber"`
    /// - `selector.partitionBy: "year"` -> `"year"`
    /// - otherwise -> `None` (single entry, was `"combined"`)
    pub fn effective_partition_by(&self) -> Option<&str> {
        if let Some(sel) = &self.selector {
            return sel.partition_by.as_deref();
        }
        // Legacy: presentation: "separate" maps to partitionBy: "group"
        match self.presentation.as_deref() {
            Some("separate") => Some("group"),
            _ => None,
        }
    }

    /// Returns the effective prepend_season_number, preferring v5
    /// `groupItem` and falling back to legacy top-level field.
    pub fn effective_prepend_season_number(&self) -> bool {
        self.group_item
            .as_ref()
            .and_then(|gi| gi.prepend_season_number)
            .unwrap_or(self.prepend_season_number)
    }

    /// Returns effective year_binding from group listing.
    pub fn effective_year_binding(&self) -> Option<&str> {
        self.effective_group_listing()
            .and_then(|gl| gl.year_binding.as_deref())
    }

    /// Returns effective sort rule from group listing.
    pub fn effective_group_sort(&self) -> Option<&SortRule> {
        self.effective_group_listing()
            .and_then(|gl| gl.sort.as_ref())
    }

    /// Removes fields that are irrelevant to the current resolver type.
    ///
    /// This keeps form-state values safe (the editor preserves them for undo),
    /// but ensures persisted/previewed data is clean.
    ///
    /// Conditional fields by resolver_type:
    /// - `seasonNumber`:      numberingExtractor, titleExtractor
    /// - `titleDiscovery`:    titleExtractor, groups (groups[0].pattern used as fallback)
    /// - `titleClassifier`:   groups
    /// - `year`:              titleExtractor
    /// - others:              none of the above
    pub fn strip_conditional_fields(&mut self) {
        let rt = self.effective_resolver_type().to_owned();

        // numberingExtractor: only seasonNumber
        if rt != "seasonNumber" {
            self.numbering_extractor = None;
            if let Some(g) = &mut self.grouping {
                g.numbering_extractor = None;
            }
        }

        // titleExtractor (group-level only): seasonNumber, titleDiscovery, or year
        if rt != "seasonNumber" && rt != "titleDiscovery" && rt != "year" {
            self.title_extractor = None;
            if let Some(gi) = &mut self.group_item {
                gi.title_extractor = None;
            }
        }

        // groups/staticClassifiers: titleClassifier or titleDiscovery
        if rt != "titleClassifier" && rt != "titleDiscovery" {
            self.groups = None;
            if let Some(g) = &mut self.grouping {
                g.static_classifiers = None;
            }
        }
    }

    /// Whether this definition has any effective episode filters.
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

/// Episode filters applied before resolver processing.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EpisodeFilters {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub require: Option<Vec<EpisodeFilterEntry>>,

    #[serde(skip_serializing_if = "Option::is_none")]
    pub exclude: Option<Vec<EpisodeFilterEntry>>,
}

/// A single filter condition matched against episode fields.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EpisodeFilterEntry {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub title: Option<String>,

    #[serde(skip_serializing_if = "Option::is_none")]
    pub description: Option<String>,
}

/// Settings for the group list view (grouped mode only).
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct GroupListSettings {
    /// How groups relate to year headers.
    /// v5: use `sectionBy` in `groupListing` instead.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub year_binding: Option<String>,

    /// Allow users to change sort order at runtime.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub user_sortable: Option<bool>,

    /// Show date range on group cards.
    /// v5: moved to `groupItem.showDateRange`.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub show_date_range: Option<bool>,

    /// Sort rule for ordering groups.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub sort: Option<SortRule>,
}

/// Default episode list display and ordering settings.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct EpisodeListSettings {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub show_year_headers: Option<bool>,

    #[serde(skip_serializing_if = "Option::is_none")]
    pub sort: Option<EpisodeSortRule>,

    /// v4: episode-level title extractor. v5: moved to `episodeItem.titleExtractor`.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub title_extractor: Option<TitleExtractor>,
}

#[cfg(test)]
mod tests {
    use super::*;

    fn make_definition(resolver_type: &str) -> PlaylistDefinition {
        let json = serde_json::json!({
            "id": "test",
            "displayName": "Test",
            "resolverType": resolver_type,
            "presentation": "combined",
            "numberingExtractor": {
                "source": "title",
                "pattern": "(\\d+)",
                "seasonGroup": 0,
                "episodeGroup": 1
            },
            "titleExtractor": {
                "source": "title",
                "pattern": "(.+)",
                "group": 1
            },
            "groups": [{ "id": "g1", "displayName": "G1", "pattern": ".*" }],
            "episodeList": {
                "titleExtractor": {
                    "source": "title",
                    "pattern": "(.+)",
                    "group": 1
                }
            }
        });
        serde_json::from_value(json).unwrap()
    }

    #[test]
    fn season_number_keeps_numbering_and_title_extractor() {
        let mut def = make_definition("seasonNumber");
        def.strip_conditional_fields();

        assert!(def.numbering_extractor.is_some());
        assert!(def.title_extractor.is_some());
        assert!(def.groups.is_none());
    }

    #[test]
    fn title_discovery_keeps_title_extractor_and_groups() {
        let mut def = make_definition("titleDiscovery");
        def.strip_conditional_fields();

        assert!(def.numbering_extractor.is_none());
        assert!(def.title_extractor.is_some());
        assert!(def.groups.is_some());
    }

    #[test]
    fn title_classifier_keeps_groups_only() {
        let mut def = make_definition("titleClassifier");
        def.strip_conditional_fields();

        assert!(def.numbering_extractor.is_none());
        assert!(def.title_extractor.is_none());
        assert!(def.groups.is_some());
        // episodeList.titleExtractor is NOT stripped (independent of resolver)
        assert!(def.episode_list.as_ref().unwrap().title_extractor.is_some());
    }

    #[test]
    fn year_keeps_title_extractor_strips_rest() {
        let mut def = make_definition("year");
        def.strip_conditional_fields();

        assert!(def.numbering_extractor.is_none());
        assert!(def.title_extractor.is_some());
        assert!(def.groups.is_none());
    }

    #[test]
    fn v5_grouping_deserializes() {
        let json = serde_json::json!({
            "id": "test",
            "displayName": "Test",
            "grouping": {
                "by": "seasonNumber",
                "numberingExtractor": {
                    "source": "title",
                    "pattern": "(\\d+)",
                    "seasonGroup": 0,
                    "episodeGroup": 1
                }
            },
            "groupItem": {
                "showDateRange": true,
                "titleExtractor": {
                    "source": "title",
                    "pattern": "(.+)",
                    "group": 1
                }
            },
            "episodeItem": {
                "titleExtractor": {
                    "source": "title",
                    "pattern": "(.+)",
                    "group": 1
                }
            }
        });
        let def: PlaylistDefinition = serde_json::from_value(json).unwrap();
        assert_eq!(def.effective_resolver_type(), "seasonNumber");
        assert!(def.effective_numbering_extractor().is_some());
        assert!(def.effective_title_extractor().is_some());
        assert!(def.effective_episode_title_extractor().is_some());
        assert!(def.effective_show_date_range());
    }

    #[test]
    fn effective_resolver_type_prefers_v5() {
        let json = serde_json::json!({
            "id": "test",
            "displayName": "Test",
            "resolverType": "year",
            "grouping": { "by": "seasonNumber" }
        });
        let def: PlaylistDefinition = serde_json::from_value(json).unwrap();
        assert_eq!(def.effective_resolver_type(), "seasonNumber");
    }

    #[test]
    fn effective_resolver_type_falls_back_to_legacy() {
        let json = serde_json::json!({
            "id": "test",
            "displayName": "Test",
            "resolverType": "year"
        });
        let def: PlaylistDefinition = serde_json::from_value(json).unwrap();
        assert_eq!(def.effective_resolver_type(), "year");
    }
}
