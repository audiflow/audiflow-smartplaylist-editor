use std::collections::BTreeMap;

use crate::models::{
    EpisodeData, Grouping, Playlist, PlaylistDefinition, PlaylistStructure, SortField, SortOrder,
    SortRule, YearBinding,
};

use super::resolver::Resolver;

/// Resolver that groups episodes using RSS metadata (seasonNumber field).
pub struct RssResolver;

impl Resolver for RssResolver {
    fn resolver_type(&self) -> &str {
        "rss"
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
        let null_season_group_key = definition.and_then(|d| d.null_season_group_key);
        let title_extractor = definition.and_then(|d| d.title_extractor.as_ref());

        let mut grouped: BTreeMap<i32, Vec<&dyn EpisodeData>> = BTreeMap::new();
        let mut ungrouped: Vec<i64> = Vec::new();

        for &episode in episodes {
            let season_num = episode.season_number();
            match season_num {
                Some(n) if 1 <= n => {
                    grouped.entry(n).or_default().push(episode);
                }
                _ => {
                    if let Some(key) = null_season_group_key {
                        grouped.entry(key).or_default().push(episode);
                    } else {
                        ungrouped.push(episode.id());
                    }
                }
            }
        }

        if grouped.is_empty() {
            return None;
        }

        let mut playlists: Vec<Playlist> = grouped
            .iter()
            .map(|(&season_number, eps)| {
                let display_name = extract_display_name(season_number, eps, title_extractor);
                Playlist {
                    id: format!("season_{}", season_number),
                    display_name,
                    sort_key: season_number,
                    episode_ids: eps.iter().map(|e| e.id()).collect(),
                    thumbnail_url: None,
                    playlist_structure: PlaylistStructure::Split,
                    year_binding: YearBinding::None,
                    show_year_headers: false,
                    show_date_range: false,
                    groups: None,
                }
            })
            .collect();

        playlists.sort_by(|a, b| a.sort_key.cmp(&b.sort_key));

        Some(Grouping {
            playlists,
            ungrouped_episode_ids: ungrouped,
            resolver_type: self.resolver_type().to_string(),
        })
    }
}

fn extract_display_name(
    season_number: i32,
    episodes: &[&dyn EpisodeData],
    title_extractor: Option<&crate::models::TitleExtractor>,
) -> String {
    let fallback = format!("Season {}", season_number);

    let extractor = match title_extractor {
        Some(e) => e,
        None => return fallback,
    };

    if episodes.is_empty() {
        return fallback;
    }

    extractor.extract(episodes[0]).unwrap_or(fallback)
}
