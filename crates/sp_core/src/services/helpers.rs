use crate::models::YearBinding;

/// Parses a year binding string into the enum value.
/// Defaults to None for unrecognized or missing values.
pub fn parse_year_binding(value: Option<&str>) -> YearBinding {
    match value {
        Some("pinToYear") => YearBinding::PinToYear,
        Some("splitByYear") => YearBinding::SplitByYear,
        _ => YearBinding::None,
    }
}
