use regex::Regex;

use crate::models::{
    EpisodeData, GroupDef, Grouping, Playlist, PlaylistDefinition, SortField, SortOrder, SortRule,
};

use super::resolver::Resolver;

/// Resolver that groups episodes into predefined categories by title pattern.
///
/// Reads group definitions from the definition's `groups` field.
/// Each group has a regex pattern, display name, and sort key.
/// Episodes are matched against groups in order (first match wins).
/// Groups without a pattern act as catch-all fallbacks.
pub struct CategoryResolver;

struct PatternGroup {
    regex: Regex,
    id: String,
    display_name: String,
    show_year_headers: Option<bool>,
}

impl Resolver for CategoryResolver {
    fn resolver_type(&self) -> &str {
        "titleClassifier"
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
        let group_defs = definition.effective_static_classifiers()?;
        if group_defs.is_empty() {
            return None;
        }

        resolve_with_groups(episodes, group_defs, self.resolver_type())
    }
}

fn resolve_with_groups(
    episodes: &[&dyn EpisodeData],
    group_defs: &[GroupDef],
    resolver_type: &str,
) -> Option<Grouping> {
    let pattern_groups = build_pattern_groups(group_defs);

    // Find the first fallback group (no pattern)
    let fallback = group_defs.iter().find(|g| g.pattern.is_none());
    let fallback_id = fallback.map(|g| g.id.as_str());
    let fallback_display_name = fallback.map(|g| g.display_name.as_str());
    let fallback_show_year_headers = fallback
        .and_then(|g| g.episode_list.as_ref())
        .and_then(|el| el.show_year_headers);

    // Map from pattern group id -> list of episode ids
    let mut grouped: std::collections::HashMap<String, Vec<i64>> = std::collections::HashMap::new();
    let mut fallback_ids: Vec<i64> = Vec::new();
    let mut ungrouped: Vec<i64> = Vec::new();

    for &episode in episodes {
        let mut matched = false;
        for pg in &pattern_groups {
            if pg.regex.is_match(episode.title()) {
                grouped
                    .entry(pg.id.clone())
                    .or_default()
                    .push(episode.id());
                matched = true;
                break;
            }
        }
        if !matched {
            if fallback_id.is_some() {
                fallback_ids.push(episode.id());
            } else {
                ungrouped.push(episode.id());
            }
        }
    }

    // Build playlists in definition order, assigning sequential sortKeys
    // to non-empty groups only
    let mut playlists: Vec<Playlist> = Vec::new();
    let mut sort_key = 1;

    for pg in &pattern_groups {
        if let Some(ids) = grouped.get(&pg.id)
            && !ids.is_empty()
        {
            let mut playlist = Playlist::new(
                pg.id.clone(),
                pg.display_name.clone(),
                sort_key,
                ids.clone(),
            );
            playlist.show_year_headers = pg.show_year_headers.unwrap_or(false);
            playlists.push(playlist);
            sort_key += 1;
        }
    }

    // Add fallback group last
    if !fallback_ids.is_empty() {
        let mut playlist = Playlist::new(
            fallback_id.unwrap().to_string(),
            fallback_display_name.unwrap().to_string(),
            playlists.len() as i32 + 1,
            fallback_ids,
        );
        playlist.show_year_headers = fallback_show_year_headers.unwrap_or(false);
        playlists.push(playlist);
    }

    if playlists.is_empty() {
        return None;
    }

    Some(Grouping {
        playlists,
        ungrouped_episode_ids: ungrouped,
        resolver_type: resolver_type.to_string(),
    })
}

fn build_pattern_groups(group_defs: &[GroupDef]) -> Vec<PatternGroup> {
    group_defs
        .iter()
        .filter_map(|g| {
            let pattern = g.pattern.as_ref()?;
            let regex = Regex::new(pattern).ok()?;
            Some(PatternGroup {
                regex,
                id: g.id.clone(),
                display_name: g.display_name.clone(),
                show_year_headers: g.episode_list.as_ref().and_then(|el| el.show_year_headers),
            })
        })
        .collect()
}
