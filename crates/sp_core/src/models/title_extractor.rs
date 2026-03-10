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

/// A `TitleExtractor` with its regex pattern precompiled.
///
/// Use `TitleExtractor::compile()` to build one before iterating
/// over episodes, avoiding per-episode regex compilation.
pub struct CompiledTitleExtractor<'a> {
    extractor: &'a TitleExtractor,
    regex: Option<Regex>,
    fallback: Option<Box<CompiledTitleExtractor<'a>>>,
}

impl TitleExtractor {
    /// Precompiles the regex pattern (and any fallback chain) for reuse
    /// across many episodes.
    pub fn compile(&self) -> CompiledTitleExtractor<'_> {
        let regex = self.pattern.as_ref().and_then(|p| Regex::new(p).ok());
        let fallback = self
            .fallback
            .as_ref()
            .map(|f| Box::new(f.compile()));
        CompiledTitleExtractor {
            extractor: self,
            regex,
            fallback,
        }
    }

    /// Extracts the smart playlist title from an episode.
    /// Returns None if extraction fails and no fallback is available.
    ///
    /// Compiles the regex on every call. For batch use, prefer
    /// `compile()` + `CompiledTitleExtractor::extract()`.
    pub fn extract(&self, episode: &dyn EpisodeData) -> Option<String> {
        self.compile().extract(episode)
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
}

impl<'a> CompiledTitleExtractor<'a> {
    /// Extracts the smart playlist title using the precompiled regex.
    pub fn extract(&self, episode: &dyn EpisodeData) -> Option<String> {
        let ext = self.extractor;

        // For null/zero seasonNumber, use fallback_value if available
        let season_num = episode.season_number();
        if ext.fallback_value.is_some()
            && (season_num.is_none() || season_num.is_some_and(|n| n < 1))
        {
            return ext.fallback_value.clone();
        }

        let source_value = ext.get_source_value(episode);

        let source_value = match source_value {
            Some(v) => v,
            None => return self.fallback.as_ref().and_then(|f| f.extract(episode)),
        };

        let result = if self.regex.is_some() {
            self.extract_with_regex(&source_value)
        } else {
            Some(source_value)
        };

        let result = match result {
            Some(v) => v,
            None => return self.fallback.as_ref().and_then(|f| f.extract(episode)),
        };

        if let Some(ref tmpl) = ext.template {
            Some(tmpl.replace("{value}", &result))
        } else {
            Some(result)
        }
    }

    fn extract_with_regex(&self, value: &str) -> Option<String> {
        let regex = self.regex.as_ref()?;
        let captures = regex.captures(value)?;

        if self.extractor.group == 0 {
            return captures.get(0).map(|m| m.as_str().to_string());
        }

        let group_usize = self.extractor.group as usize;
        if captures.len() < group_usize + 1 {
            return None;
        }

        captures.get(group_usize).map(|m| m.as_str().to_string())
    }
}
