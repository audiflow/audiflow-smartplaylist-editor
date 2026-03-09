use std::collections::BTreeMap;

use chrono::Datelike;

use crate::models::{
    EpisodeData, Grouping, Playlist, PlaylistDefinition, PlaylistStructure, SortField, SortOrder,
    SortRule, YearBinding,
};

use super::resolver::Resolver;

/// Resolver that groups episodes by publication year.
pub struct YearResolver;

impl Resolver for YearResolver {
    fn resolver_type(&self) -> &str {
        "year"
    }

    fn default_sort(&self) -> SortRule {
        SortRule {
            field: SortField::PlaylistNumber,
            order: SortOrder::Descending, // Newest years first
        }
    }

    fn resolve(
        &self,
        episodes: &[&dyn EpisodeData],
        definition: Option<&PlaylistDefinition>,
    ) -> Option<Grouping> {
        let title_extractor = definition.and_then(|d| d.title_extractor.as_ref());

        let mut grouped: BTreeMap<i32, Vec<&dyn EpisodeData>> = BTreeMap::new();
        let mut ungrouped: Vec<i64> = Vec::new();

        for &episode in episodes {
            match episode.published_at() {
                Some(pub_date) => {
                    let year = pub_date.year() as i32;
                    grouped.entry(year).or_default().push(episode);
                }
                None => {
                    ungrouped.push(episode.id());
                }
            }
        }

        if grouped.is_empty() {
            return None;
        }

        let mut playlists: Vec<Playlist> = grouped
            .iter()
            .map(|(&year, eps)| {
                let display_name = extract_display_name(year, eps, title_extractor);
                Playlist {
                    id: format!("year_{}", year),
                    display_name,
                    sort_key: year,
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

        // Sort by year descending (newest first)
        playlists.sort_by(|a, b| b.sort_key.cmp(&a.sort_key));

        Some(Grouping {
            playlists,
            ungrouped_episode_ids: ungrouped,
            resolver_type: self.resolver_type().to_string(),
        })
    }
}

fn extract_display_name(
    year: i32,
    episodes: &[&dyn EpisodeData],
    title_extractor: Option<&crate::models::TitleExtractor>,
) -> String {
    let fallback = year.to_string();

    let extractor = match title_extractor {
        Some(e) => e,
        None => return fallback,
    };

    if episodes.is_empty() {
        return fallback;
    }

    extractor.extract(episodes[0]).unwrap_or(fallback)
}
