use std::collections::{HashMap, HashSet};

use regex::{Regex, RegexBuilder};

use crate::models::{
    EpisodeData, EpisodeFilterEntry, Grouping, PatternConfig, Playlist, PlaylistDefinition,
    PlaylistGroup, PlaylistPreviewResult, PlaylistStructure, PreviewGrouping, SimpleEpisodeData,
};

/// Precompiled filter entry for efficient per-episode matching.
struct CompiledFilterEntry {
    title: Option<Regex>,
    description: Option<Regex>,
}

impl CompiledFilterEntry {
    fn compile(entry: &EpisodeFilterEntry) -> Self {
        Self {
            title: entry
                .title
                .as_ref()
                .and_then(|p| RegexBuilder::new(p).case_insensitive(true).build().ok()),
            description: entry
                .description
                .as_ref()
                .and_then(|p| RegexBuilder::new(p).case_insensitive(true).build().ok()),
        }
    }

    fn matches(&self, episode: &dyn EpisodeData) -> bool {
        if let Some(ref regex) = self.title
            && !regex.is_match(episode.title())
        {
            return false;
        }
        if let Some(ref regex) = self.description
            && !regex.is_match(episode.description().unwrap_or(""))
        {
            return false;
        }
        true
    }
}

/// Precompiled require/exclude filters for a playlist definition.
struct CompiledFilters {
    require: Vec<CompiledFilterEntry>,
    exclude: Vec<CompiledFilterEntry>,
}

impl CompiledFilters {
    fn compile(definition: &PlaylistDefinition) -> Option<Self> {
        let filters = definition.episode_filters.as_ref()?;
        Some(Self {
            require: filters
                .require
                .as_deref()
                .unwrap_or(&[])
                .iter()
                .map(CompiledFilterEntry::compile)
                .collect(),
            exclude: filters
                .exclude
                .as_deref()
                .unwrap_or(&[])
                .iter()
                .map(CompiledFilterEntry::compile)
                .collect(),
        })
    }

    fn matches(&self, episode: &dyn EpisodeData) -> bool {
        let require_ok = self.require.is_empty()
            || self.require.iter().all(|f| f.matches(episode));
        let exclude_ok = self.exclude.is_empty()
            || !self.exclude.iter().any(|f| f.matches(episode));
        require_ok && exclude_ok
    }
}
use crate::resolvers::Resolver;
use crate::services::episode_sorter::sort_episode_ids_by_published_at;
use crate::services::group_sorter::sort_groups;
use crate::services::helpers::{parse_playlist_structure, parse_year_binding};

/// Service that orchestrates the smart playlist resolver chain.
///
/// When a PatternConfig matches the podcast, its playlist definitions
/// are used to route episodes through the appropriate resolvers.
/// Otherwise, resolvers are tried in order with no definition
/// (auto-detect mode).
pub struct ResolverService {
    resolvers: Vec<Box<dyn Resolver>>,
    patterns: Vec<PatternConfig>,
}

impl ResolverService {
    pub fn new(resolvers: Vec<Box<dyn Resolver>>, patterns: Vec<PatternConfig>) -> Self {
        Self {
            resolvers,
            patterns,
        }
    }

    /// Attempts to group episodes into smart playlists.
    ///
    /// Returns None if no resolver succeeds or episodes are empty.
    pub fn resolve_smart_playlists(
        &self,
        podcast_guid: Option<&str>,
        feed_url: &str,
        episodes: &[&dyn EpisodeData],
    ) -> Option<Grouping> {
        if episodes.is_empty() {
            return None;
        }

        let episode_by_id: HashMap<i64, &dyn EpisodeData> =
            episodes.iter().map(|&e| (e.id(), e)).collect();

        if let Some(config) = self.find_matching_config(podcast_guid, feed_url) {
            let result = self.resolve_with_config(config, episodes, &episode_by_id);
            return result.map(|r| self.sort_grouping_episodes(&r, &episode_by_id));
        }

        // Fallback: try resolvers in order with no definition
        for resolver in &self.resolvers {
            if let Some(result) = resolver.resolve(episodes, None) {
                return Some(self.sort_grouping_episodes(&result, &episode_by_id));
            }
        }

        None
    }

    /// Resolves smart playlists for preview, tracking which episodes
    /// each definition lost to higher-priority definitions.
    ///
    /// Returns None if no config matches or episodes are empty.
    pub fn resolve_for_preview(
        &self,
        podcast_guid: Option<&str>,
        feed_url: &str,
        episodes: &[&dyn EpisodeData],
    ) -> Option<PreviewGrouping> {
        if episodes.is_empty() {
            return None;
        }

        let config = self.find_matching_config(podcast_guid, feed_url)?;
        let episode_by_id: HashMap<i64, &dyn EpisodeData> =
            episodes.iter().map(|&e| (e.id(), e)).collect();

        let result = self.resolve_with_config_for_preview(config, episodes, &episode_by_id)?;
        Some(self.sort_preview_grouping(&result, &episode_by_id))
    }

    fn resolve_with_config(
        &self,
        config: &PatternConfig,
        episodes: &[&dyn EpisodeData],
        episode_by_id: &HashMap<i64, &dyn EpisodeData>,
    ) -> Option<Grouping> {
        let mut all_playlists: Vec<Playlist> = Vec::new();
        let mut all_ungrouped_ids: HashSet<i64> = HashSet::new();
        let mut claimed_ids: HashSet<i64> = HashSet::new();
        let mut resolver_type: Option<String> = None;

        let sorted = Self::sort_by_processing_order(&config.playlists);

        for definition in &sorted {
            let compiled_filters = CompiledFilters::compile(definition);
            let filtered = Self::filter_episodes(episodes, &compiled_filters, &claimed_ids);
            if filtered.is_empty() {
                continue;
            }

            let resolver = match self.find_resolver_by_type(&definition.resolver_type) {
                Some(r) => r,
                None => continue,
            };

            let result = match resolver.resolve(&filtered, Some(definition)) {
                Some(r) => r,
                None => continue,
            };

            if resolver_type.is_none() {
                resolver_type = Some(result.resolver_type.clone());
            }

            let structure = parse_playlist_structure(&definition.playlist_structure);

            if structure == PlaylistStructure::Grouped {
                self.add_grouped_playlist(
                    &mut all_playlists,
                    definition,
                    &result,
                    episode_by_id,
                );
            } else {
                Self::add_split_playlists(
                    &mut all_playlists,
                    definition,
                    &result,
                );
            }

            all_ungrouped_ids.extend(&result.ungrouped_episode_ids);

            if definition.has_filters() {
                for p in &result.playlists {
                    for &id in &p.episode_ids {
                        claimed_ids.insert(id);
                    }
                }
            }
        }

        if all_playlists.is_empty() {
            return None;
        }

        for &id in &claimed_ids {
            all_ungrouped_ids.remove(&id);
        }

        Some(Grouping {
            playlists: all_playlists,
            ungrouped_episode_ids: all_ungrouped_ids.into_iter().collect(),
            resolver_type: resolver_type.unwrap_or_else(|| "config".to_string()),
        })
    }

    fn resolve_with_config_for_preview(
        &self,
        config: &PatternConfig,
        episodes: &[&dyn EpisodeData],
        episode_by_id: &HashMap<i64, &dyn EpisodeData>,
    ) -> Option<PreviewGrouping> {
        let mut playlist_results: Vec<PlaylistPreviewResult> = Vec::new();
        let mut all_ungrouped_ids: HashSet<i64> = HashSet::new();
        let mut claimed_ids: HashSet<i64> = HashSet::new();
        let mut claimed_by_map: HashMap<i64, String> = HashMap::new();
        let mut resolver_type: Option<String> = None;

        let sorted = Self::sort_by_processing_order(&config.playlists);

        for definition in &sorted {
            let compiled_filters = CompiledFilters::compile(definition);
            let claimed_by_others = Self::compute_claimed_by_others(
                definition,
                episodes,
                &compiled_filters,
                &claimed_ids,
                &claimed_by_map,
            );

            let filtered = Self::filter_episodes(episodes, &compiled_filters, &claimed_ids);

            if filtered.is_empty() {
                self.add_empty_preview_result(
                    &mut playlist_results,
                    definition,
                    claimed_by_others,
                );
                continue;
            }

            let resolver = match self.find_resolver_by_type(&definition.resolver_type) {
                Some(r) => r,
                None => continue,
            };

            // Per-definition enrichment: apply this definition's episode
            // extractor so each resolver sees correctly extracted
            // season/episode numbers for its own definition.
            let enriched_storage = Self::enrich_for_definition(definition, &filtered);
            let resolve_slice: Vec<&dyn EpisodeData> = match &enriched_storage {
                Some(enriched) => enriched.iter().map(|e| e as &dyn EpisodeData).collect(),
                None => filtered,
            };

            let result = match resolver.resolve(&resolve_slice, Some(definition)) {
                Some(r) => r,
                None => continue,
            };

            if resolver_type.is_none() {
                resolver_type = Some(result.resolver_type.clone());
            }

            let playlist = self.build_preview_playlist(
                definition,
                &result,
                playlist_results.len() as i32,
                episode_by_id,
            );

            playlist_results.push(PlaylistPreviewResult {
                definition_id: definition.id.clone(),
                playlist,
                claimed_by_others,
            });

            all_ungrouped_ids.extend(&result.ungrouped_episode_ids);

            if definition.has_filters() {
                self.claim_episodes(&result, &definition.id, &mut claimed_ids, &mut claimed_by_map);
            }
        }

        if playlist_results.is_empty() {
            return None;
        }

        for &id in &claimed_ids {
            all_ungrouped_ids.remove(&id);
        }

        Some(PreviewGrouping {
            playlist_results,
            ungrouped_episode_ids: all_ungrouped_ids.into_iter().collect(),
            resolver_type: resolver_type.unwrap_or_else(|| "config".to_string()),
        })
    }

    fn compute_claimed_by_others(
        definition: &PlaylistDefinition,
        episodes: &[&dyn EpisodeData],
        compiled_filters: &Option<CompiledFilters>,
        claimed_ids: &HashSet<i64>,
        claimed_by_map: &HashMap<i64, String>,
    ) -> HashMap<i64, String> {
        let mut claimed_by_others: HashMap<i64, String> = HashMap::new();
        if !definition.has_filters() {
            return claimed_by_others;
        }

        let all_candidates = Self::filter_episodes(episodes, compiled_filters, &HashSet::new());
        for ep in &all_candidates {
            let id = ep.id();
            if claimed_ids.contains(&id)
                && let Some(claimer) = claimed_by_map.get(&id)
            {
                claimed_by_others.insert(id, claimer.clone());
            }
        }
        claimed_by_others
    }

    fn add_empty_preview_result(
        &self,
        results: &mut Vec<PlaylistPreviewResult>,
        definition: &PlaylistDefinition,
        claimed_by_others: HashMap<i64, String>,
    ) {
        results.push(PlaylistPreviewResult {
            definition_id: definition.id.clone(),
            playlist: Playlist::new(
                definition.id.clone(),
                definition.display_name.clone(),
                results.len() as i32,
                Vec::new(),
            ),
            claimed_by_others,
        });
    }

    fn build_preview_playlist(
        &self,
        definition: &PlaylistDefinition,
        result: &Grouping,
        sort_key: i32,
        episode_by_id: &HashMap<i64, &dyn EpisodeData>,
    ) -> Playlist {
        let structure = parse_playlist_structure(&definition.playlist_structure);
        let year_binding = parse_year_binding(
            definition
                .group_list
                .as_ref()
                .and_then(|gl| gl.year_binding.as_deref()),
        );

        let unsorted_groups: Vec<PlaylistGroup> = result
            .playlists
            .iter()
            .map(|p| PlaylistGroup {
                id: p.id.clone(),
                display_name: p.display_name.clone(),
                sort_key: p.sort_key,
                episode_ids: p.episode_ids.clone(),
                thumbnail_url: p.thumbnail_url.clone(),
                year_override: None,
                show_year_headers: None,
                show_date_range: false,
                earliest_date: None,
                latest_date: None,
                total_duration_ms: None,
            })
            .collect();

        let sort_rule = definition
            .group_list
            .as_ref()
            .and_then(|gl| gl.sort.as_ref());
        let groups = sort_groups(&unsorted_groups, sort_rule, episode_by_id);
        let all_episode_ids: Vec<i64> = groups.iter().flat_map(|g| g.episode_ids.iter()).copied().collect();

        Playlist {
            id: definition.id.clone(),
            display_name: definition.display_name.clone(),
            sort_key,
            episode_ids: all_episode_ids,
            thumbnail_url: None,
            playlist_structure: structure,
            year_binding,
            show_year_headers: definition
                .episode_list
                .as_ref()
                .and_then(|el| el.show_year_headers)
                .unwrap_or(false),
            show_date_range: definition
                .group_list
                .as_ref()
                .and_then(|gl| gl.show_date_range)
                .unwrap_or(false),
            groups: Some(groups),
        }
    }

    fn claim_episodes(
        &self,
        result: &Grouping,
        definition_id: &str,
        claimed_ids: &mut HashSet<i64>,
        claimed_by_map: &mut HashMap<i64, String>,
    ) {
        for p in &result.playlists {
            for &id in &p.episode_ids {
                claimed_ids.insert(id);
                claimed_by_map.insert(id, definition_id.to_string());
            }
        }
    }

    fn add_grouped_playlist(
        &self,
        all_playlists: &mut Vec<Playlist>,
        definition: &PlaylistDefinition,
        result: &Grouping,
        episode_by_id: &HashMap<i64, &dyn EpisodeData>,
    ) {
        let structure = parse_playlist_structure(&definition.playlist_structure);
        let year_binding = parse_year_binding(
            definition
                .group_list
                .as_ref()
                .and_then(|gl| gl.year_binding.as_deref()),
        );
        let group_def_map: HashMap<&str, &crate::models::GroupDef> = definition
            .groups
            .as_ref()
            .map(|gs| gs.iter().map(|g| (g.id.as_str(), g)).collect())
            .unwrap_or_default();

        let unsorted_groups: Vec<PlaylistGroup> = result
            .playlists
            .iter()
            .map(|p| {
                let g_def = group_def_map.get(p.id.as_str());
                PlaylistGroup {
                    id: p.id.clone(),
                    display_name: p.display_name.clone(),
                    sort_key: p.sort_key,
                    episode_ids: p.episode_ids.clone(),
                    thumbnail_url: p.thumbnail_url.clone(),
                    year_override: None,
                    show_year_headers: g_def.and_then(|d| {
                        d.episode_list.as_ref().and_then(|el| el.show_year_headers)
                    }),
                    show_date_range: g_def
                        .and_then(|d| d.display.as_ref().and_then(|disp| disp.show_date_range))
                        .unwrap_or_else(|| {
                            definition
                                .group_list
                                .as_ref()
                                .and_then(|gl| gl.show_date_range)
                                .unwrap_or(false)
                        }),
                    earliest_date: None,
                    latest_date: None,
                    total_duration_ms: None,
                }
            })
            .collect();

        let sort_rule = definition
            .group_list
            .as_ref()
            .and_then(|gl| gl.sort.as_ref());
        let groups = sort_groups(&unsorted_groups, sort_rule, episode_by_id);
        let all_episode_ids: Vec<i64> = groups.iter().flat_map(|g| g.episode_ids.iter()).copied().collect();

        all_playlists.push(Playlist {
            id: definition.id.clone(),
            display_name: definition.display_name.clone(),
            sort_key: all_playlists.len() as i32,
            episode_ids: all_episode_ids,
            thumbnail_url: None,
            playlist_structure: structure.clone(),
            year_binding: year_binding.clone(),
            show_year_headers: definition
                .episode_list
                .as_ref()
                .and_then(|el| el.show_year_headers)
                .unwrap_or(false),
            show_date_range: definition
                .group_list
                .as_ref()
                .and_then(|gl| gl.show_date_range)
                .unwrap_or(false),
            groups: Some(groups),
        });
    }

    fn add_split_playlists(
        all_playlists: &mut Vec<Playlist>,
        definition: &PlaylistDefinition,
        result: &Grouping,
    ) {
        let structure = parse_playlist_structure(&definition.playlist_structure);
        let year_binding = parse_year_binding(
            definition
                .group_list
                .as_ref()
                .and_then(|gl| gl.year_binding.as_deref()),
        );

        let decorated: Vec<Playlist> = result
            .playlists
            .iter()
            .map(|playlist| Playlist {
                id: playlist.id.clone(),
                display_name: playlist.display_name.clone(),
                sort_key: playlist.sort_key,
                episode_ids: playlist.episode_ids.clone(),
                thumbnail_url: playlist.thumbnail_url.clone(),
                playlist_structure: structure.clone(),
                year_binding: year_binding.clone(),
                show_year_headers: definition
                    .episode_list
                    .as_ref()
                    .and_then(|el| el.show_year_headers)
                    .unwrap_or(false),
                show_date_range: definition
                    .group_list
                    .as_ref()
                    .and_then(|gl| gl.show_date_range)
                    .unwrap_or(false),
                groups: None,
            })
            .collect();
        all_playlists.extend(decorated);
    }

    fn sort_grouping_episodes(
        &self,
        grouping: &Grouping,
        episode_by_id: &HashMap<i64, &dyn EpisodeData>,
    ) -> Grouping {
        let sorted_playlists: Vec<Playlist> = grouping
            .playlists
            .iter()
            .map(|playlist| {
                let sorted_groups = playlist.groups.as_ref().map(|gs| {
                    gs.iter()
                        .map(|group| PlaylistGroup {
                            episode_ids: sort_episode_ids_by_published_at(
                                &group.episode_ids,
                                episode_by_id,
                            ),
                            ..group.clone()
                        })
                        .collect()
                });

                Playlist {
                    episode_ids: sort_episode_ids_by_published_at(
                        &playlist.episode_ids,
                        episode_by_id,
                    ),
                    groups: sorted_groups,
                    ..playlist.clone()
                }
            })
            .collect();

        Grouping {
            playlists: sorted_playlists,
            ungrouped_episode_ids: sort_episode_ids_by_published_at(
                &grouping.ungrouped_episode_ids,
                episode_by_id,
            ),
            resolver_type: grouping.resolver_type.clone(),
        }
    }

    fn sort_preview_grouping(
        &self,
        grouping: &PreviewGrouping,
        episode_by_id: &HashMap<i64, &dyn EpisodeData>,
    ) -> PreviewGrouping {
        let sorted_results: Vec<PlaylistPreviewResult> = grouping
            .playlist_results
            .iter()
            .map(|preview_result| {
                let playlist = &preview_result.playlist;
                let sorted_groups = playlist.groups.as_ref().map(|gs| {
                    gs.iter()
                        .map(|group| PlaylistGroup {
                            episode_ids: sort_episode_ids_by_published_at(
                                &group.episode_ids,
                                episode_by_id,
                            ),
                            ..group.clone()
                        })
                        .collect()
                });

                PlaylistPreviewResult {
                    definition_id: preview_result.definition_id.clone(),
                    playlist: Playlist {
                        episode_ids: sort_episode_ids_by_published_at(
                            &playlist.episode_ids,
                            episode_by_id,
                        ),
                        groups: sorted_groups,
                        ..playlist.clone()
                    },
                    claimed_by_others: preview_result.claimed_by_others.clone(),
                }
            })
            .collect();

        PreviewGrouping {
            playlist_results: sorted_results,
            ungrouped_episode_ids: sort_episode_ids_by_published_at(
                &grouping.ungrouped_episode_ids,
                episode_by_id,
            ),
            resolver_type: grouping.resolver_type.clone(),
        }
    }

    /// Filters episodes based on precompiled definition filters.
    ///
    /// Episodes already claimed by a higher-priority definition are excluded.
    /// A definition with no filters acts as a fallback, receiving all
    /// unclaimed episodes.
    fn filter_episodes<'a>(
        episodes: &[&'a dyn EpisodeData],
        compiled_filters: &Option<CompiledFilters>,
        claimed_ids: &HashSet<i64>,
    ) -> Vec<&'a dyn EpisodeData> {
        let unclaimed: Vec<&'a dyn EpisodeData> = episodes
            .iter()
            .filter(|e| !claimed_ids.contains(&e.id()))
            .copied()
            .collect();

        match compiled_filters {
            Some(filters) => unclaimed
                .into_iter()
                .filter(|episode| filters.matches(*episode))
                .collect(),
            None => unclaimed,
        }
    }

    fn find_matching_config(
        &self,
        guid: Option<&str>,
        feed_url: &str,
    ) -> Option<&PatternConfig> {
        self.patterns
            .iter()
            .find(|config| config.matches_podcast(guid, feed_url))
    }

    /// Enriches episodes using the definition's own episode extractor.
    /// Group-level extractors are intentionally excluded: they are
    /// per-group display concerns (applied after grouping), not inputs
    /// to the resolver's grouping logic.  Returns `None` when the
    /// definition has no extractor, letting callers skip the copy.
    fn enrich_for_definition(
        definition: &PlaylistDefinition,
        episodes: &[&dyn EpisodeData],
    ) -> Option<Vec<SimpleEpisodeData>> {
        let extractor = definition.numbering_extractor.as_ref()?;

        let compiled = extractor.compile();
        Some(
            episodes
                .iter()
                .map(|ep| {
                    let result = compiled.extract(*ep);
                    SimpleEpisodeData {
                        id: ep.id(),
                        title: ep.title().to_string(),
                        description: ep.description().map(|s| s.to_string()),
                        season_number: if result.has_values() {
                            result.season_number.or(ep.season_number())
                        } else {
                            ep.season_number()
                        },
                        episode_number: if result.has_values() {
                            result.episode_number.or(ep.episode_number())
                        } else {
                            ep.episode_number()
                        },
                        published_at: ep.published_at(),
                        image_url: ep.image_url().map(|s| s.to_string()),
                    }
                })
                .collect(),
        )
    }

    fn find_resolver_by_type(&self, resolver_type: &str) -> Option<&dyn Resolver> {
        self.resolvers
            .iter()
            .find(|r| r.resolver_type() == resolver_type)
            .map(|r| r.as_ref())
    }

    /// Sorts definitions so filtered definitions process before fallbacks.
    /// Within each group, sorts by priority ascending (lower number first).
    fn sort_by_processing_order(definitions: &[PlaylistDefinition]) -> Vec<&PlaylistDefinition> {
        let mut filtered: Vec<&PlaylistDefinition> = Vec::new();
        let mut fallbacks: Vec<&PlaylistDefinition> = Vec::new();

        for def in definitions {
            if def.has_filters() {
                filtered.push(def);
            } else {
                fallbacks.push(def);
            }
        }

        filtered.sort_by(|a, b| a.priority.cmp(&b.priority));
        fallbacks.sort_by(|a, b| a.priority.cmp(&b.priority));

        filtered.extend(fallbacks);
        filtered
    }
}
