use crate::models::{Presentation, YearBinding};

/// Parses a presentation string into the enum value.
/// Defaults to Separate for unrecognized values.
pub fn parse_presentation(value: &str) -> Presentation {
    match value {
        "combined" => Presentation::Combined,
        _ => Presentation::Separate,
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
