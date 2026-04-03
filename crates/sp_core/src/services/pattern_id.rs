/// Derives a semi-deterministic pattern ID from podcast identity.
///
/// Priority: podcastGuid (if non-empty) > feedUrls[0].
/// Returns the first 12 hex characters of the MD5 digest, or `None`
/// if no usable input is available.
///
/// MD5 is chosen over SHA-256 because this is an opaque identifier,
/// not a security digest. 12 hex chars = 48 bits; birthday collision
/// probability exceeds 1% only at ~16M patterns, far beyond podcast scale.
pub fn derive_pattern_id(podcast_guid: Option<&str>, feed_urls: &[String]) -> Option<String> {
    let input = podcast_guid
        .filter(|g| !g.is_empty())
        .or_else(|| feed_urls.first().map(|s| s.as_str()))?;
    let digest = md5::compute(input.as_bytes());
    Some(format!("{digest:x}")[..12].to_string())
}

/// Returns `true` if `id` looks like a deterministic pattern ID
/// (exactly 12 lowercase hex characters). Non-matching IDs are
/// implicitly grandfathered.
pub fn is_deterministic_id(id: &str) -> bool {
    id.len() == 12 && id.chars().all(|c| c.is_ascii_hexdigit() && !c.is_ascii_uppercase())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn derive_from_guid() {
        let id = derive_pattern_id(Some("abcdef-1234"), &[]).unwrap();
        assert_eq!(id.len(), 12);
        assert!(id.chars().all(|c| c.is_ascii_hexdigit()));
        let id2 = derive_pattern_id(Some("abcdef-1234"), &[]).unwrap();
        assert_eq!(id, id2);
    }

    #[test]
    fn derive_from_feed_url_when_no_guid() {
        let urls = vec!["https://example.com/feed.xml".to_string()];
        let id = derive_pattern_id(None, &urls).unwrap();
        assert_eq!(id.len(), 12);
        assert!(id.chars().all(|c| c.is_ascii_hexdigit()));
    }

    #[test]
    fn guid_takes_priority_over_feed_url() {
        let urls = vec!["https://example.com/feed.xml".to_string()];
        let from_guid = derive_pattern_id(Some("my-guid"), &urls).unwrap();
        let from_url = derive_pattern_id(None, &urls).unwrap();
        assert_ne!(from_guid, from_url);
    }

    #[test]
    fn empty_guid_falls_through_to_feed_url() {
        let urls = vec!["https://example.com/feed.xml".to_string()];
        let from_empty_guid = derive_pattern_id(Some(""), &urls).unwrap();
        let from_none_guid = derive_pattern_id(None, &urls).unwrap();
        assert_eq!(from_empty_guid, from_none_guid);
    }

    #[test]
    fn returns_none_when_no_input() {
        assert!(derive_pattern_id(None, &[]).is_none());
        assert!(derive_pattern_id(Some(""), &[]).is_none());
    }

    #[test]
    fn is_deterministic_id_valid() {
        assert!(is_deterministic_id("a1b2c3d4e5f6"));
        assert!(is_deterministic_id("000000000000"));
        assert!(is_deterministic_id("abcdef123456"));
    }

    #[test]
    fn is_deterministic_id_invalid() {
        assert!(!is_deterministic_id("coten_radio"));
        assert!(!is_deterministic_id("a1b2c3d4e5"));
        assert!(!is_deterministic_id("a1b2c3d4e5f6a7"));
        assert!(!is_deterministic_id("a1b2c3d4e5g6"));
        assert!(!is_deterministic_id("A1B2C3D4E5F6"));
        assert!(!is_deterministic_id(""));
    }

    #[test]
    fn known_md5_vector() {
        // MD5("hello") = 5d41402abc4b2a76b9719d911017c592
        let id = derive_pattern_id(Some("hello"), &[]).unwrap();
        assert_eq!(id, "5d41402abc4b");
    }
}
