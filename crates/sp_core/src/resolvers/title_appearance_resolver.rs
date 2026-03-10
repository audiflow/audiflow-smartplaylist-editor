use regex::Regex;

use crate::models::{
    CompiledTitleExtractor, EpisodeData, Grouping, Playlist, PlaylistDefinition, SortField,
    SortOrder, SortRule, TitleExtractor,
};

use super::resolver::Resolver;

/// Resolver that groups by title pattern with playlist order by first appearance.
///
/// Useful for podcasts like:
/// - [Rome 1] First Steps
/// - [Rome 2] The Colosseum
/// - [Venezia 1] Arrival
///
/// Where "Rome" becomes playlist 1 (appeared first), "Venezia" becomes playlist 2.
pub struct TitleAppearanceResolver;

impl Resolver for TitleAppearanceResolver {
    fn resolver_type(&self) -> &str {
        "title_appearance"
    }

    fn default_sort(&self) -> SortRule {
        SortRule {
            field: SortField::PlaylistNumber,
            order: SortOrder::Ascending,
        }
    }

    fn resolve(
        &self,
        episodes: &[&dyn EpisodeData],
        definition: Option<&PlaylistDefinition>,
    ) -> Option<Grouping> {
        let definition = definition?;

        let title_extractor = definition.title_extractor.as_ref();
        let pattern_str = definition
            .groups
            .as_ref()
            .and_then(|g| g.first())
            .and_then(|g| g.pattern.as_deref());

        // Need either a titleExtractor or a group pattern
        if title_extractor.is_none() && pattern_str.is_none() {
            return None;
        }

        resolve_by_appearance(episodes, title_extractor, pattern_str, self.resolver_type())
    }
}

fn resolve_by_appearance(
    episodes: &[&dyn EpisodeData],
    title_extractor: Option<&TitleExtractor>,
    pattern_str: Option<&str>,
    resolver_type: &str,
) -> Option<Grouping> {
    // Sort episodes by publish date (oldest first) to determine appearance order
    let mut with_date: Vec<&dyn EpisodeData> = episodes
        .iter()
        .filter(|e| e.published_at().is_some())
        .copied()
        .collect();
    with_date.sort_by_key(|a| a.published_at().unwrap());

    let without_date: Vec<&dyn EpisodeData> = episodes
        .iter()
        .filter(|e| e.published_at().is_none())
        .copied()
        .collect();

    // Process all episodes: dated first (oldest to newest), then undated
    let all_episodes: Vec<&dyn EpisodeData> = with_date
        .into_iter()
        .chain(without_date)
        .collect();

    // Pre-compile regexes once before the episode loop
    let compiled_group_regex = pattern_str.and_then(|p| Regex::new(p).ok());
    let compiled_title_extractor = title_extractor.map(|e| e.compile());

    let mut playlist_order: Vec<String> = Vec::new();
    let mut seen: std::collections::HashSet<String> = std::collections::HashSet::new();
    let mut grouped: std::collections::HashMap<String, Vec<&dyn EpisodeData>> =
        std::collections::HashMap::new();
    let mut ungrouped: Vec<i64> = Vec::new();

    for episode in &all_episodes {
        let playlist_name = extract_playlist_name(
            *episode,
            compiled_title_extractor.as_ref(),
            compiled_group_regex.as_ref(),
        );

        match playlist_name {
            Some(name) => {
                if seen.insert(name.clone()) {
                    playlist_order.push(name.clone());
                }
                grouped.entry(name).or_default().push(*episode);
            }
            None => {
                ungrouped.push(episode.id());
            }
        }
    }

    if grouped.is_empty() {
        return None;
    }

    let mut playlists: Vec<Playlist> = Vec::new();
    for (i, name) in playlist_order.iter().enumerate() {
        let playlist_episodes = &grouped[name];
        let sort_key = (i as i32) + 1;
        playlists.push(Playlist::new(
            format!("season_{}", sort_key),
            name.clone(),
            sort_key,
            playlist_episodes.iter().map(|e| e.id()).collect(),
        ));
    }

    Some(Grouping {
        playlists,
        ungrouped_episode_ids: ungrouped,
        resolver_type: resolver_type.to_string(),
    })
}

fn extract_playlist_name(
    episode: &dyn EpisodeData,
    compiled_extractor: Option<&CompiledTitleExtractor<'_>>,
    compiled_regex: Option<&Regex>,
) -> Option<String> {
    // Try precompiled titleExtractor first if available
    if let Some(extractor) = compiled_extractor {
        return extractor.extract(episode);
    }

    // Fall back to pre-compiled group pattern regex
    if let Some(regex) = compiled_regex {
        let captures = regex.captures(episode.title())?;
        if 1 <= captures.len() {
            // captures.len() includes the full match at index 0,
            // so len() >= 2 means there is at least one capture group
            if let Some(m) = captures.get(1) {
                return Some(m.as_str().to_string());
            }
        }
    }

    None
}
