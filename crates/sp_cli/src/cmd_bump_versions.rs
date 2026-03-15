use std::collections::HashMap;

/// Extracts unique pattern IDs from a git diff output.
///
/// Parses lines like `patterns/coten_radio/meta.json` and extracts
/// the pattern ID (`coten_radio`). Skips root-level files (e.g.,
/// `patterns/meta.json`) that have no subdirectory.
#[allow(dead_code)]
pub(crate) fn extract_changed_pattern_ids(diff_output: &str, patterns_dir_name: &str) -> Vec<String> {
    let prefix = format!("{patterns_dir_name}/");
    let mut ids: Vec<String> = diff_output
        .lines()
        .filter_map(|line| line.strip_prefix(&prefix))
        .filter_map(|rest| {
            let slash_pos = rest.find('/')?;
            Some(rest[..slash_pos].to_string())
        })
        .collect::<std::collections::BTreeSet<_>>()
        .into_iter()
        .collect();
    ids.sort();
    ids
}

/// Computes new version numbers for changed patterns.
///
/// For each changed pattern ID, looks up the previous version and
/// increments by one. Patterns not found in the previous map start
/// at version 1.
#[allow(dead_code)]
pub(crate) fn compute_version_bumps(
    changed_ids: &[String],
    previous_versions: &HashMap<String, i32>,
) -> HashMap<String, i32> {
    changed_ids
        .iter()
        .map(|id| {
            let new_version = previous_versions.get(id.as_str()).unwrap_or(&0) + 1;
            (id.clone(), new_version)
        })
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn extracts_unique_pattern_ids_from_diff() {
        let diff = "patterns/coten_radio/meta.json\n\
                     patterns/coten_radio/playlists/main.json\n\
                     patterns/rebuild/meta.json\n";
        let result = extract_changed_pattern_ids(diff, "patterns");
        assert_eq!(result, vec!["coten_radio", "rebuild"]);
    }

    #[test]
    fn skips_root_meta_json() {
        let diff = "patterns/meta.json\npatterns/coten_radio/meta.json\n";
        let result = extract_changed_pattern_ids(diff, "patterns");
        assert_eq!(result, vec!["coten_radio"]);
    }

    #[test]
    fn returns_empty_for_no_pattern_changes() {
        let diff = "README.md\nsrc/main.rs\n";
        let result = extract_changed_pattern_ids(diff, "patterns");
        assert!(result.is_empty());
    }

    #[test]
    fn handles_empty_diff() {
        let result = extract_changed_pattern_ids("", "patterns");
        assert!(result.is_empty());
    }

    #[test]
    fn bumps_existing_pattern_version() {
        let mut previous: HashMap<String, i32> = HashMap::new();
        previous.insert("coten_radio".into(), 3);
        let changed = vec!["coten_radio".into()];
        let result = compute_version_bumps(&changed, &previous);
        assert_eq!(result.get("coten_radio"), Some(&4));
    }

    #[test]
    fn new_pattern_starts_at_one() {
        let previous: HashMap<String, i32> = HashMap::new();
        let changed = vec!["new_pattern".into()];
        let result = compute_version_bumps(&changed, &previous);
        assert_eq!(result.get("new_pattern"), Some(&1));
    }
}
