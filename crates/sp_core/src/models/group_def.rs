use serde::{Deserialize, Serialize};

use super::numbering_extractor::NumberingExtractor;
use super::sort::EpisodeSortRule;
use super::title_extractor::TitleExtractor;

/// Matches episode content by regex against a selected source field.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Matcher {
    pub source: String,
    pub pattern: String,
}

/// Static group definition within a playlist.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct GroupDef {
    pub id: String,
    pub display_name: String,

    #[serde(skip_serializing_if = "Option::is_none")]
    pub pattern: Option<Matcher>,

    #[serde(skip_serializing_if = "Option::is_none")]
    pub group_listing: Option<GroupDefGroupListing>,

    #[serde(skip_serializing_if = "Option::is_none")]
    pub group_item: Option<GroupDefGroupItem>,

    #[serde(skip_serializing_if = "Option::is_none")]
    pub episode_listing: Option<GroupDefEpisodeListing>,

    #[serde(skip_serializing_if = "Option::is_none")]
    pub episode_item: Option<GroupDefEpisodeItem>,

    #[serde(skip_serializing_if = "Option::is_none")]
    pub numbering_extractor: Option<NumberingExtractor>,
}

/// Per-group overrides for the group list section.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct GroupDefGroupListing {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub year_binding: Option<String>,
}

/// Per-group overrides for the group card.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct GroupDefGroupItem {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub show_date_range: Option<bool>,

    /// Per-group override for the group card thumbnail. None = inherit playlist default.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub show_thumbnail: Option<bool>,
}

/// Per-group overrides for the episode list.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct GroupDefEpisodeListing {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub show_year_headers: Option<bool>,

    #[serde(skip_serializing_if = "Option::is_none")]
    pub sort: Option<EpisodeSortRule>,
}

/// Per-group overrides for individual episode rows.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct GroupDefEpisodeItem {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub title_extractor: Option<TitleExtractor>,

    /// Per-group override for in-group episode row thumbnails. None = inherit playlist default.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub show_thumbnail: Option<bool>,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn show_thumbnail_round_trips_on_per_group_overrides() {
        let json = serde_json::json!({
            "id": "g1",
            "displayName": "G1",
            "groupItem": { "showThumbnail": false },
            "episodeItem": { "showThumbnail": true }
        });
        let g: GroupDef = serde_json::from_value(json).unwrap();
        assert_eq!(g.group_item.as_ref().unwrap().show_thumbnail, Some(false));
        assert_eq!(g.episode_item.as_ref().unwrap().show_thumbnail, Some(true));

        let out = serde_json::to_value(&g).unwrap();
        assert_eq!(out["groupItem"]["showThumbnail"], serde_json::json!(false));
        assert_eq!(out["episodeItem"]["showThumbnail"], serde_json::json!(true));
    }

    #[test]
    fn show_thumbnail_absent_omitted() {
        let json = serde_json::json!({
            "id": "g1",
            "displayName": "G1",
            "groupItem": { "showDateRange": true }
        });
        let g: GroupDef = serde_json::from_value(json).unwrap();
        assert!(g.group_item.as_ref().unwrap().show_thumbnail.is_none());
        let out = serde_json::to_value(&g).unwrap();
        assert!(out["groupItem"].get("showThumbnail").is_none());
    }
}
