use crate::models::{PlaylistStructure, YearBinding};

/// Parses a playlist structure string into the enum value.
/// Defaults to Split for unrecognized values.
pub fn parse_playlist_structure(value: &str) -> PlaylistStructure {
    match value {
        "grouped" => PlaylistStructure::Grouped,
        _ => PlaylistStructure::Split,
    }
}

/// Parses a year binding string into the enum value.
/// Defaults to None for unrecognized or missing values.
pub fn parse_year_binding(value: Option<&str>) -> YearBinding {
    match value {
        Some("pinToYear") => YearBinding::PinToYear,
        Some("splitByYear") => YearBinding::SplitByYear,
        _ => YearBinding::None,
    }
}
