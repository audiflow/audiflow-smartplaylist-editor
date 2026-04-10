use serde::{Deserialize, Deserializer, Serialize};

use super::numbering_extractor::NumberingExtractor;
use super::group_def::GroupDef;
use super::is_zero;
use super::sort::{EpisodeSortRule, SortRule};
use super::title_extractor::TitleExtractor;

/// Deserializes the presentation field, normalizing legacy values.
/// Maps "grouped" -> "combined" and "split" -> "separate".
fn deserialize_presentation<'de, D>(deserializer: D) -> Result<String, D::Error>
where
    D: Deserializer<'de>,
{
    let raw = String::deserialize(deserializer)?;
    Ok(match raw.as_str() {
        "grouped" => "combined".to_owned(),
        "split" => "separate".to_owned(),
        _ => raw,
    })
}

/// Unified per-playlist definition with all fields strongly typed.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PlaylistDefinition {
    pub id: String,
    pub display_name: String,
    pub resolver_type: String,
    /// Accepts legacy `playlistStructure` key and normalizes legacy values
    /// (`grouped` -> `combined`, `split` -> `separate`).
    #[serde(alias = "playlistStructure", deserialize_with = "deserialize_presentation")]
    pub presentation: String,

    /// Episode claiming order among siblings (lower = first, default: 0).
    #[serde(default, skip_serializing_if = "is_zero")]
    pub priority: i32,

    /// Episode filters applied before resolver processing.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub episode_filters: Option<EpisodeFilters>,

    /// Group key to assign to episodes with null season number.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub null_season_group_key: Option<i32>,

    /// Configuration for extracting playlist/group display names.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub title_extractor: Option<TitleExtractor>,

    /// Whether to prepend "S{n}" to resolver result names.
    #[serde(default, skip_serializing_if = "std::ops::Not::not")]
    pub prepend_season_number: bool,

    /// Settings for the group list view (grouped mode only).
    #[serde(skip_serializing_if = "Option::is_none")]
    pub group_list: Option<GroupListSettings>,

    /// Default episode list display and ordering settings.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub episode_list: Option<EpisodeListSettings>,

    /// Configuration for extracting season and episode numbers.
    /// Accepts legacy `episodeExtractor` key for v3 backward compatibility.
    #[serde(skip_serializing_if = "Option::is_none", alias = "episodeExtractor")]
    pub numbering_extractor: Option<NumberingExtractor>,

    /// Static group definitions for titleClassifier-based grouping.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub groups: Option<Vec<GroupDef>>,
}

impl PlaylistDefinition {
    /// Removes fields that are irrelevant to the current `resolver_type`.
    ///
    /// This keeps form-state values safe (the editor preserves them for undo),
    /// but ensures persisted/previewed data is clean.
    ///
    /// Conditional fields by resolver_type:
    /// - `seasonNumber`:      numberingExtractor, titleExtractor, nullSeasonGroupKey
    /// - `titleDiscovery`:    titleExtractor, groups (groups[0].pattern used as fallback)
    /// - `titleClassifier`:   groups
    /// - `year`:              titleExtractor
    /// - others:              none of the above
    pub fn strip_conditional_fields(&mut self) {
        let rt = self.resolver_type.as_str();

        // numberingExtractor + nullSeasonGroupKey: only seasonNumber
        if rt != "seasonNumber" {
            self.numbering_extractor = None;
            self.null_season_group_key = None;
        }

        // titleExtractor (top-level): seasonNumber, titleDiscovery, or year
        if rt != "seasonNumber" && rt != "titleDiscovery" && rt != "year" {
            self.title_extractor = None;
            // Also strip titleExtractor inside episodeList
            if let Some(ref mut el) = self.episode_list {
                el.title_extractor = None;
            }
        }

        // groups: titleClassifier uses full group definitions;
        // titleDiscovery uses groups[0].pattern as a fallback extraction pattern
        if rt != "titleClassifier" && rt != "titleDiscovery" {
            self.groups = None;
        }
    }

    /// Whether this definition has any effective episode filters.
    pub fn has_filters(&self) -> bool {
        match &self.episode_filters {
            None => false,
            Some(f) => {
                let has_require = f
                    .require
                    .as_ref()
                    .is_some_and(|r| !r.is_empty());
                let has_exclude = f
                    .exclude
                    .as_ref()
                    .is_some_and(|e| !e.is_empty());
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
    #[serde(skip_serializing_if = "Option::is_none")]
    pub year_binding: Option<String>,

    /// Allow users to change sort order at runtime.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub user_sortable: Option<bool>,

    /// Show date range on group cards.
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
            "nullSeasonGroupKey": 0,
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
        assert!(def.null_season_group_key.is_some());
        assert!(def.title_extractor.is_some());
        assert!(def.groups.is_none());
    }

    #[test]
    fn title_discovery_keeps_title_extractor_and_groups() {
        let mut def = make_definition("titleDiscovery");
        def.strip_conditional_fields();

        assert!(def.numbering_extractor.is_none());
        assert!(def.null_season_group_key.is_none());
        assert!(def.title_extractor.is_some());
        assert!(def.groups.is_some());
    }

    #[test]
    fn title_classifier_keeps_groups_only() {
        let mut def = make_definition("titleClassifier");
        def.strip_conditional_fields();

        assert!(def.numbering_extractor.is_none());
        assert!(def.null_season_group_key.is_none());
        assert!(def.title_extractor.is_none());
        assert!(def.groups.is_some());
        assert!(def.episode_list.as_ref().unwrap().title_extractor.is_none());
    }

    #[test]
    fn year_keeps_title_extractor_strips_rest() {
        let mut def = make_definition("year");
        def.strip_conditional_fields();

        assert!(def.numbering_extractor.is_none());
        assert!(def.null_season_group_key.is_none());
        assert!(def.title_extractor.is_some());
        assert!(def.groups.is_none());
    }
}
