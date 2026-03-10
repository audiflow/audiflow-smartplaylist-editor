use std::collections::{HashMap, HashSet};

use axum::extract::State;
use axum::Json;
use serde_json::Value;

use crate::app::{AppError, SharedState};
use sp_core::models::{
    EpisodeData, PatternConfig, Playlist, PlaylistGroup, PlaylistPreviewResult, PreviewGrouping,
    SimpleEpisodeData,
};
use sp_core::resolvers::{CategoryResolver, Resolver, RssResolver, TitleAppearanceResolver, YearResolver};
use sp_core::services::ResolverService;

/// POST /api/configs/preview -- previews smart playlists from config + feed.
pub async fn preview_config(
    State(state): State<SharedState>,
    Json(body): Json<Value>,
) -> Result<Json<Value>, AppError> {
    let obj = body
        .as_object()
        .ok_or_else(|| AppError::bad_request("Request body must be a JSON object"))?;

    let config_json = obj
        .get("config")
        .and_then(|v| v.as_object())
        .ok_or_else(|| AppError::bad_request("Missing or invalid \"config\" field"))?;

    let feed_url = obj
        .get("feedUrl")
        .and_then(|v| v.as_str())
        .filter(|s| !s.is_empty())
        .ok_or_else(|| AppError::bad_request("Missing or invalid \"feedUrl\" field"))?;

    let config: PatternConfig =
        serde_json::from_value(Value::Object(config_json.clone()))
            .map_err(|e| AppError::bad_request(format!("Invalid config: {e}")))?;

    let episode_maps = state
        .feed_cache
        .fetch_feed(feed_url, &state.http_client)
        .await
        .map_err(|e| AppError::bad_gateway(format!("Failed to fetch feed: {e}")))?;

    let mut episodes: Vec<SimpleEpisodeData> = Vec::with_capacity(episode_maps.len());
    let mut parse_failures = 0usize;
    for v in &episode_maps {
        match serde_json::from_value(v.clone()) {
            Ok(ep) => episodes.push(ep),
            Err(_) => parse_failures += 1,
        }
    }

    let enriched = enrich_episodes(&config, &episodes);
    let mut result = run_preview(&config, &enriched, feed_url);

    if 0 < parse_failures
        && let Some(debug) = result.get_mut("debug").and_then(|d| d.as_object_mut())
    {
        debug.insert(
            "parseFailures".to_string(),
            Value::from(parse_failures),
        );
    }

    Ok(Json(result))
}

/// Collects all episode extractors from definitions and their group
/// overrides, compiles them, and applies each to every episode.  The
/// first extractor that produces values wins for a given episode.
fn enrich_episodes(
    config: &PatternConfig,
    episodes: &[SimpleEpisodeData],
) -> Vec<SimpleEpisodeData> {
    use sp_core::models::CompiledEpisodeExtractor;

    let mut compiled_extractors: Vec<CompiledEpisodeExtractor> = Vec::new();
    for def in &config.playlists {
        if let Some(ext) = &def.episode_extractor {
            compiled_extractors.push(ext.compile());
        }
        if let Some(groups) = &def.groups {
            for group in groups {
                if let Some(ext) = &group.episode_extractor {
                    compiled_extractors.push(ext.compile());
                }
            }
        }
    }

    if compiled_extractors.is_empty() {
        return episodes.to_vec();
    }

    episodes
        .iter()
        .map(|episode| {
            for compiled in &compiled_extractors {
                let result = compiled.extract(episode);
                if result.has_values() {
                    return SimpleEpisodeData {
                        id: episode.id,
                        title: episode.title.clone(),
                        description: episode.description.clone(),
                        season_number: result.season_number.or(episode.season_number),
                        episode_number: result.episode_number.or(episode.episode_number),
                        published_at: episode.published_at,
                        image_url: episode.image_url.clone(),
                    };
                }
            }
            episode.clone()
        })
        .collect()
}

fn run_preview(config: &PatternConfig, episodes: &[SimpleEpisodeData], request_feed_url: &str) -> Value {
    let episode_refs: Vec<&dyn EpisodeData> = episodes
        .iter()
        .map(|e| e as &dyn EpisodeData)
        .collect();

    let resolvers: Vec<Box<dyn Resolver>> = vec![
        Box::new(RssResolver),
        Box::new(CategoryResolver),
        Box::new(YearResolver),
        Box::new(TitleAppearanceResolver),
    ];

    let service = ResolverService::new(resolvers, vec![config.clone()]);
    let result = service.resolve_for_preview(
        config.podcast_guid.as_deref(),
        config.feed_urls.as_ref().and_then(|u| u.first()).map(|s| s.as_str()).unwrap_or(request_feed_url),
        &episode_refs,
    );

    let result = match result {
        Some(r) => r,
        None => {
            return serde_json::json!({
                "playlists": [],
                "ungrouped": [],
                "excluded": [],
                "resolverType": null,
            });
        }
    };

    let episode_by_id: HashMap<i64, &SimpleEpisodeData> =
        episodes.iter().map(|e| (e.id, e)).collect();

    // Pre-compute extracted display names per definition
    let extracted_display_names = compute_extracted_display_names(config, episodes);

    let grouped_ids = collect_grouped_ids(&result);
    let ungrouped_set: HashSet<i64> = result.ungrouped_episode_ids.iter().copied().collect();

    let excluded_episodes: Vec<Value> = episodes
        .iter()
        .filter(|e| !grouped_ids.contains(&e.id) && !ungrouped_set.contains(&e.id))
        .map(|e| serialize_episode(e, None))
        .collect();

    let playlists: Vec<Value> = result
        .playlist_results
        .iter()
        .map(|pr| {
            serialize_preview_result(
                pr,
                result.resolver_type.as_str(),
                &episode_by_id,
                extracted_display_names.get(&pr.definition_id),
            )
        })
        .collect();

    let ungrouped: Vec<Value> = result
        .ungrouped_episode_ids
        .iter()
        .filter_map(|id| episode_by_id.get(id))
        .map(|e| serialize_episode(e, None))
        .collect();

    serde_json::json!({
        "playlists": playlists,
        "ungrouped": ungrouped,
        "excluded": excluded_episodes,
        "resolverType": result.resolver_type,
        "debug": {
            "totalEpisodes": episodes.len(),
            "groupedEpisodes": grouped_ids.len(),
            "ungroupedEpisodes": result.ungrouped_episode_ids.len(),
            "excludedEpisodes": excluded_episodes.len(),
        },
    })
}

fn compute_extracted_display_names(
    config: &PatternConfig,
    episodes: &[SimpleEpisodeData],
) -> HashMap<String, HashMap<i64, String>> {
    let mut result = HashMap::new();
    for definition in &config.playlists {
        let extractor = match &definition.title_extractor {
            Some(e) => e,
            None => continue,
        };
        let compiled = extractor.compile();
        let mut names = HashMap::new();
        for episode in episodes {
            if let Some(name) = compiled.extract(episode) {
                names.insert(episode.id, name);
            }
        }
        result.insert(definition.id.clone(), names);
    }
    result
}

fn collect_grouped_ids(result: &PreviewGrouping) -> HashSet<i64> {
    let mut ids = HashSet::new();
    for pr in &result.playlist_results {
        for &id in &pr.playlist.episode_ids {
            ids.insert(id);
        }
        if let Some(groups) = &pr.playlist.groups {
            for group in groups {
                for &id in &group.episode_ids {
                    ids.insert(id);
                }
            }
        }
    }
    ids
}

fn serialize_preview_result(
    pr: &PlaylistPreviewResult,
    resolver_type: &str,
    episode_by_id: &HashMap<i64, &SimpleEpisodeData>,
    extracted_names: Option<&HashMap<i64, String>>,
) -> Value {
    let mut base = serialize_playlist(
        &pr.playlist,
        resolver_type,
        episode_by_id,
        extracted_names,
    );

    if !pr.claimed_by_others.is_empty() {
        let claimed: Vec<Value> = pr
            .claimed_by_others
            .iter()
            .map(|(&id, claimer)| {
                let mut obj = serde_json::Map::new();
                if let Some(episode) = episode_by_id.get(&id) {
                    obj.insert("id".to_string(), Value::from(episode.id));
                    obj.insert("title".to_string(), Value::String(episode.title.clone()));
                    if let Some(sn) = episode.season_number {
                        obj.insert("seasonNumber".to_string(), Value::from(sn));
                    }
                    if let Some(en) = episode.episode_number {
                        obj.insert("episodeNumber".to_string(), Value::from(en));
                    }
                }
                obj.insert("claimedBy".to_string(), Value::String(claimer.clone()));
                Value::Object(obj)
            })
            .collect();
        base["claimedByOthers"] = Value::Array(claimed);
    }

    let filter_matched =
        pr.playlist.episode_ids.len() + pr.claimed_by_others.len();
    base["debug"] = serde_json::json!({
        "filterMatched": filter_matched,
        "episodeCount": pr.playlist.episode_ids.len(),
        "claimedByOthersCount": pr.claimed_by_others.len(),
    });

    base
}

fn serialize_playlist(
    playlist: &Playlist,
    resolver_type: &str,
    episode_by_id: &HashMap<i64, &SimpleEpisodeData>,
    extracted_names: Option<&HashMap<i64, String>>,
) -> Value {
    let mut obj = serde_json::json!({
        "id": playlist.id,
        "displayName": playlist.display_name,
        "sortKey": playlist.sort_key,
        "resolverType": resolver_type,
        "episodeCount": playlist.episode_count(),
        "yearBinding": serde_json::to_value(&playlist.year_binding).unwrap_or(Value::Null),
    });

    if let Some(groups) = &playlist.groups {
        let groups_json: Vec<Value> = groups
            .iter()
            .map(|g| serialize_group(g, episode_by_id, extracted_names))
            .collect();
        obj["groups"] = Value::Array(groups_json);
    }

    obj
}

fn serialize_group(
    group: &PlaylistGroup,
    episode_by_id: &HashMap<i64, &SimpleEpisodeData>,
    extracted_names: Option<&HashMap<i64, String>>,
) -> Value {
    let episodes_json: Vec<Value> = group
        .episode_ids
        .iter()
        .filter_map(|id| {
            let ep = episode_by_id.get(id)?;
            let name = extracted_names.and_then(|m| m.get(id)).map(|s| s.as_str());
            Some(serialize_episode(ep, name))
        })
        .collect();

    serde_json::json!({
        "id": group.id,
        "displayName": group.display_name,
        "sortKey": group.sort_key,
        "episodeCount": group.episode_count(),
        "episodes": episodes_json,
    })
}

fn serialize_episode(
    episode: &SimpleEpisodeData,
    extracted_display_name: Option<&str>,
) -> Value {
    let mut obj = serde_json::Map::new();
    obj.insert("id".to_string(), Value::from(episode.id));
    obj.insert("title".to_string(), Value::String(episode.title.clone()));

    if let Some(dt) = episode.published_at {
        obj.insert(
            "publishedAt".to_string(),
            Value::String(dt.to_rfc3339()),
        );
    }
    if let Some(sn) = episode.season_number {
        obj.insert("seasonNumber".to_string(), Value::from(sn));
    }
    if let Some(en) = episode.episode_number {
        obj.insert("episodeNumber".to_string(), Value::from(en));
    }
    if let Some(name) = extracted_display_name {
        obj.insert(
            "extractedDisplayName".to_string(),
            Value::String(name.to_string()),
        );
    }

    Value::Object(obj)
}
