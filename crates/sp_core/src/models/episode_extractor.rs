use regex::Regex;
use serde::{Deserialize, Serialize};

use super::episode_data::EpisodeData;

fn is_default_fallback_capture_group(v: &i32) -> bool {
    *v == 1
}

/// Custom deserializer for seasonGroup that distinguishes between
/// absent (default to Some(1)) and explicit null (None).
mod season_group_serde {
    use serde::{self, Deserialize, Deserializer, Serializer};

    pub fn serialize<S>(value: &Option<i32>, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: Serializer,
    {
        match value {
            Some(v) => serializer.serialize_i32(*v),
            None => serializer.serialize_none(),
        }
    }

    pub fn deserialize<'de, D>(deserializer: D) -> Result<Option<i32>, D::Error>
    where
        D: Deserializer<'de>,
    {
        // This handles both explicit null and present values.
        // Missing fields are handled by the default attribute.
        Option::<i32>::deserialize(deserializer)
    }
}

fn default_season_group() -> Option<i32> {
    Some(1)
}

/// Result of extracting season and episode numbers from episode data.
#[derive(Debug, Clone, Default)]
pub struct EpisodeExtractionResult {
    pub season_number: Option<i32>,
    pub episode_number: Option<i32>,
}

impl EpisodeExtractionResult {
    /// Returns true if at least one value was extracted.
    pub fn has_values(&self) -> bool {
        self.season_number.is_some() || self.episode_number.is_some()
    }
}

/// Extracts both season and episode numbers from episode title.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct EpisodeExtractor {
    /// Episode field to extract from ("title" or "description").
    pub source: String,

    /// Primary regex pattern to extract both season and episode.
    pub pattern: String,

    /// Capture group index for season number (default: 1, null to skip).
    #[serde(
        default = "default_season_group",
        skip_serializing_if = "Option::is_none",
        with = "season_group_serde"
    )]
    pub season_group: Option<i32>,

    /// Capture group index for episode number (default: 2).
    #[serde(default = "default_episode_group")]
    pub episode_group: i32,

    /// Season number to use when primary pattern fails but fallback matches.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub fallback_season_number: Option<i32>,

    /// Fallback regex pattern for special episodes.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub fallback_episode_pattern: Option<String>,

    /// Capture group index for episode number in fallback pattern (default: 1).
    #[serde(
        default = "default_fallback_capture_group",
        skip_serializing_if = "is_default_fallback_capture_group"
    )]
    pub fallback_episode_capture_group: i32,

    /// Whether to fall back to RSS episodeNumber when no pattern matches.
    #[serde(default, skip_serializing_if = "std::ops::Not::not")]
    pub fallback_to_rss: bool,
}

fn default_episode_group() -> i32 {
    2
}

fn default_fallback_capture_group() -> i32 {
    1
}

impl EpisodeExtractor {
    /// Extracts season and episode numbers from episode data.
    pub fn extract(&self, episode: &dyn EpisodeData) -> EpisodeExtractionResult {
        let source_value = self.get_source_value(episode);
        let source_value = match source_value {
            Some(v) => v,
            None => return self.rss_fallback(episode),
        };

        // Try primary pattern first
        let primary_result = self.extract_from_primary(&source_value);
        if primary_result.has_values() {
            return primary_result;
        }

        // Try fallback pattern if configured
        if self.fallback_episode_pattern.is_some() {
            let fallback_result = self.extract_from_fallback(&source_value);
            if fallback_result.has_values() {
                return fallback_result;
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

    fn get_source_value(&self, episode: &dyn EpisodeData) -> Option<String> {
        match self.source.as_str() {
            "title" => Some(episode.title().to_string()),
            "description" => episode.description().map(|s| s.to_string()),
            _ => None,
        }
    }

    fn extract_from_primary(&self, value: &str) -> EpisodeExtractionResult {
        let regex = match Regex::new(&self.pattern) {
            Ok(r) => r,
            Err(_) => return EpisodeExtractionResult::default(),
        };
        let captures = match regex.captures(value) {
            Some(c) => c,
            None => return EpisodeExtractionResult::default(),
        };

        let season = self.season_group.and_then(|sg| {
            let sg_usize = sg as usize;
            if sg_usize < captures.len() {
                captures
                    .get(sg_usize)
                    .and_then(|m| m.as_str().parse::<i32>().ok())
            } else {
                None
            }
        });

        let episode_group_usize = self.episode_group as usize;
        let episode = if episode_group_usize < captures.len() {
            captures
                .get(episode_group_usize)
                .and_then(|m| m.as_str().parse::<i32>().ok())
        } else {
            None
        };

        EpisodeExtractionResult {
            season_number: season,
            episode_number: episode,
        }
    }

    fn extract_from_fallback(&self, value: &str) -> EpisodeExtractionResult {
        let pattern = match &self.fallback_episode_pattern {
            Some(p) => p,
            None => return EpisodeExtractionResult::default(),
        };
        let regex = match Regex::new(pattern) {
            Ok(r) => r,
            Err(_) => return EpisodeExtractionResult::default(),
        };
        let captures = match regex.captures(value) {
            Some(c) => c,
            None => return EpisodeExtractionResult::default(),
        };

        let capture_group = self.fallback_episode_capture_group as usize;
        let episode = if capture_group < captures.len() {
            captures
                .get(capture_group)
                .and_then(|m| m.as_str().parse::<i32>().ok())
        } else {
            None
        };

        EpisodeExtractionResult {
            season_number: self.fallback_season_number,
            episode_number: episode,
        }
    }
}
