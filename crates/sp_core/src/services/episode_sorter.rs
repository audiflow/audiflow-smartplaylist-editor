use std::collections::HashMap;

use crate::models::EpisodeData;

/// Sorts episode IDs by publishedAt ascending (oldest first).
///
/// Three-tier system:
///   tier 0 = has publishedAt
///   tier 1 = in map but publishedAt is None
///   tier 2 = not found in map (unknown ID)
///
/// Within tier 0, episodes are compared by date.
/// Within tiers 1 and 2, original order is preserved (stable sort).
pub fn sort_episode_ids_by_published_at(
    episode_ids: &[i64],
    episode_by_id: &HashMap<i64, &dyn EpisodeData>,
) -> Vec<i64> {
    if 2 <= episode_ids.len() {
        // need to sort
    } else {
        return episode_ids.to_vec();
    }

    let mut sorted: Vec<i64> = episode_ids.to_vec();
    sorted.sort_by(|&a, &b| {
        let ep_a = episode_by_id.get(&a);
        let ep_b = episode_by_id.get(&b);

        let tier_a = match ep_a {
            None => 2,
            Some(ep) => {
                if ep.published_at().is_some() {
                    0
                } else {
                    1
                }
            }
        };
        let tier_b = match ep_b {
            None => 2,
            Some(ep) => {
                if ep.published_at().is_some() {
                    0
                } else {
                    1
                }
            }
        };

        if tier_a != tier_b {
            return tier_a.cmp(&tier_b);
        }

        if tier_a == 0 {
            let date_a = ep_a.unwrap().published_at().unwrap();
            let date_b = ep_b.unwrap().published_at().unwrap();
            return date_a.cmp(&date_b);
        }

        // Same tier (1 or 2) -- preserve original order (stable sort)
        std::cmp::Ordering::Equal
    });
    sorted
}
