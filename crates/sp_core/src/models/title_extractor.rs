use regex::Regex;
use serde::{Deserialize, Serialize};

use super::episode_data::EpisodeData;

fn is_zero(v: &i32) -> bool {
    *v == 0
}

/// Configuration for extracting smart playlist display names from episode data.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct TitleExtractor {
    /// Episode field to extract from: "title", "description", "seasonNumber", "episodeNumber".
    pub source: String,

    /// Regex pattern to extract value (optional).
    #[serde(skip_serializing_if = "Option::is_none")]
    pub pattern: Option<String>,

    /// Capture group to use from regex match (default: 0 = full match).
    #[serde(default, skip_serializing_if = "is_zero")]
    pub group: i32,

    /// Template for formatting the extracted value. Use `{value}` as placeholder.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub template: Option<String>,

    /// Fallback extractor to use when this one fails.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub fallback: Option<Box<TitleExtractor>>,

    /// Fallback string value for null/zero seasonNumber episodes.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub fallback_value: Option<String>,
}

impl TitleExtractor {
    /// Extracts the smart playlist title from an episode.
    /// Returns None if extraction fails and no fallback is available.
    pub fn extract(&self, episode: &dyn EpisodeData) -> Option<String> {
        // For null/zero seasonNumber, use fallback_value if available
        let season_num = episode.season_number();
        if self.fallback_value.is_some() && (season_num.is_none() || season_num == Some(0)) {
            return self.fallback_value.clone();
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
            Some(v) => v,
            None => return self.fallback.as_ref().and_then(|f| f.extract(episode)),
        };

        if let Some(ref tmpl) = self.template {
            Some(tmpl.replace("{value}", &result))
        } else {
            Some(result)
        }
    }

    fn get_source_value(&self, episode: &dyn EpisodeData) -> Option<String> {
        match self.source.as_str() {
            "title" => Some(episode.title().to_string()),
            "description" => episode.description().map(|s| s.to_string()),
            "seasonNumber" => episode.season_number().map(|n| n.to_string()),
            "episodeNumber" => episode.episode_number().map(|n| n.to_string()),
            _ => None,
        }
    }

    fn extract_with_pattern(&self, value: &str, pattern: &str) -> Option<String> {
        let regex = Regex::new(pattern).ok()?;
        let captures = regex.captures(value)?;

        if self.group == 0 {
            return captures.get(0).map(|m| m.as_str().to_string());
        }

        let group_usize = self.group as usize;
        if captures.len() < group_usize + 1 {
            return None;
        }

        captures.get(group_usize).map(|m| m.as_str().to_string())
    }
}
