use serde_json::json;
use sp_core::schema::{SchemaType, Validator};

fn test_validator() -> Validator {
    let schema_dir = std::path::Path::new(env!("CARGO_MANIFEST_DIR")).join("assets");
    Validator::from_dir(&schema_dir).expect("failed to load schemas")
}

#[test]
fn valid_playlist_definition_passes() {
    let v = test_validator();
    let def = json!({
        "id": "main",
        "displayName": "Main",
        "resolverType": "rss",
        "playlistStructure": "grouped"
    });
    let errors = v.validate(SchemaType::PlaylistDefinition, &def);
    assert!(errors.is_empty(), "Expected no errors but got: {errors:?}");
}

#[test]
fn missing_required_field_fails() {
    let v = test_validator();
    // missing resolverType and playlistStructure
    let def = json!({
        "id": "main",
        "displayName": "Main"
    });
    let errors = v.validate(SchemaType::PlaylistDefinition, &def);
    assert!(!errors.is_empty());
}

#[test]
fn invalid_enum_value_fails() {
    let v = test_validator();
    let def = json!({
        "id": "main",
        "displayName": "Main",
        "resolverType": "invalidType",
        "playlistStructure": "grouped"
    });
    let errors = v.validate(SchemaType::PlaylistDefinition, &def);
    assert!(!errors.is_empty());
}

#[test]
fn valid_pattern_meta_passes() {
    let v = test_validator();
    let meta = json!({
        "dataVersion": 1,
        "id": "test-podcast",
        "feedUrls": ["https://example.com/feed.xml"],
        "playlists": ["main"]
    });
    let errors = v.validate(SchemaType::PatternMeta, &meta);
    assert!(errors.is_empty(), "Expected no errors but got: {errors:?}");
}

#[test]
fn valid_pattern_index_passes() {
    let v = test_validator();
    let index = json!({
        "dataVersion": 1,
        "schemaVersion": 2,
        "patterns": [{
            "id": "test",
            "dataVersion": 1,
            "displayName": "Test Podcast",
            "feedUrlHint": "https://example.com",
            "playlistCount": 1
        }]
    });
    let errors = v.validate(SchemaType::PatternIndex, &index);
    assert!(errors.is_empty(), "Expected no errors but got: {errors:?}");
}

#[test]
fn pattern_meta_missing_feed_urls_fails() {
    let v = test_validator();
    let meta = json!({
        "dataVersion": 1,
        "id": "test-podcast",
        "playlists": ["main"]
    });
    let errors = v.validate(SchemaType::PatternMeta, &meta);
    assert!(!errors.is_empty());
}

#[test]
fn pattern_index_empty_patterns_passes() {
    let v = test_validator();
    let index = json!({
        "dataVersion": 1,
        "schemaVersion": 1,
        "patterns": []
    });
    let errors = v.validate(SchemaType::PatternIndex, &index);
    assert!(errors.is_empty(), "Expected no errors but got: {errors:?}");
}

#[test]
fn playlist_definition_with_additional_properties_fails() {
    let v = test_validator();
    let def = json!({
        "id": "main",
        "displayName": "Main",
        "resolverType": "rss",
        "playlistStructure": "grouped",
        "unknownField": true
    });
    let errors = v.validate(SchemaType::PlaylistDefinition, &def);
    assert!(!errors.is_empty());
}
