use std::collections::HashMap;

use chrono::{DateTime, Utc};

use crate::models::{EpisodeData, PlaylistGroup, SortField, SortOrder, SortRule};

/// Sorts groups within a playlist according to a sort rule.
///
/// Returns the groups unchanged when sort_rule is None or the list has
/// fewer than two elements.
pub fn sort_groups(
    groups: &[PlaylistGroup],
    sort_rule: Option<&SortRule>,
    episode_by_id: &HashMap<i64, &dyn EpisodeData>,
) -> Vec<PlaylistGroup> {
    let rule = match sort_rule {
        Some(r) if 2 <= groups.len() => r,
        _ => return groups.to_vec(),
    };

    let mut sorted = groups.to_vec();
    sorted.sort_by(|a, b| compare_by_field(&rule.field, a, b, episode_by_id, &rule.order));
    sorted
}

fn compare_by_field(
    field: &SortField,
    a: &PlaylistGroup,
    b: &PlaylistGroup,
    episode_by_id: &HashMap<i64, &dyn EpisodeData>,
    order: &SortOrder,
) -> std::cmp::Ordering {
    let result = match field {
        SortField::PlaylistNumber => a.sort_key.cmp(&b.sort_key),
        SortField::NewestEpisodeDate => compare_newest_date(a, b, episode_by_id),
        SortField::Alphabetical => a.display_name.cmp(&b.display_name),
    };

    match order {
        SortOrder::Descending => result.reverse(),
        SortOrder::Ascending => result,
    }
}

fn compare_newest_date(
    a: &PlaylistGroup,
    b: &PlaylistGroup,
    episode_by_id: &HashMap<i64, &dyn EpisodeData>,
) -> std::cmp::Ordering {
    let date_a = newest_date(a, episode_by_id);
    let date_b = newest_date(b, episode_by_id);

    match (date_a, date_b) {
        (None, None) => std::cmp::Ordering::Equal,
        (None, Some(_)) => std::cmp::Ordering::Greater,
        (Some(_), None) => std::cmp::Ordering::Less,
        (Some(da), Some(db)) => da.cmp(&db),
    }
}

fn newest_date(
    group: &PlaylistGroup,
    episode_by_id: &HashMap<i64, &dyn EpisodeData>,
) -> Option<DateTime<Utc>> {
    let mut newest: Option<DateTime<Utc>> = None;
    for &id in &group.episode_ids {
        if let Some(ep) = episode_by_id.get(&id)
            && let Some(date) = ep.published_at()
            && newest.is_none_or(|n| n < date)
        {
            newest = Some(date);
        }
    }
    newest
}
