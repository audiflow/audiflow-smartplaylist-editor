pub mod category_resolver;
pub mod resolver;
pub mod rss_resolver;
pub mod title_appearance_resolver;
pub mod year_resolver;

pub use category_resolver::CategoryResolver;
pub use resolver::Resolver;
pub use rss_resolver::RssResolver;
pub use title_appearance_resolver::TitleAppearanceResolver;
pub use year_resolver::YearResolver;

use crate::models::{EpisodeData, TitleExtractor};

/// Extracts a display name using a title extractor, falling back to the
/// provided default when no extractor is configured or episodes are empty.
pub(crate) fn extract_display_name_with_fallback(
    fallback: String,
    episodes: &[&dyn EpisodeData],
    title_extractor: Option<&TitleExtractor>,
) -> String {
    let extractor = match title_extractor {
        Some(e) => e,
        None => return fallback,
    };
    if episodes.is_empty() {
        return fallback;
    }
    extractor.extract(episodes[0]).unwrap_or(fallback)
}
