pub mod episode_data;
pub mod episode_extractor;
pub mod group_def;
pub mod pattern_config;
pub mod pattern_meta;
pub mod pattern_summary;
pub mod playlist;
pub mod playlist_definition;
pub mod preview_grouping;
pub mod root_meta;
pub mod sort;
pub mod title_extractor;

pub(crate) fn default_data_version() -> i32 {
    1
}

pub(crate) fn is_zero(v: &i32) -> bool {
    *v == 0
}

pub use episode_data::{EpisodeData, SimpleEpisodeData};
pub use episode_extractor::{EpisodeExtractionResult, EpisodeExtractor};
pub use group_def::{GroupDef, GroupDefDisplay, GroupDefEpisodeList};
pub use pattern_config::PatternConfig;
pub use pattern_meta::PatternMeta;
pub use pattern_summary::PatternSummary;
pub use playlist::{Grouping, Playlist, PlaylistGroup, PlaylistStructure, YearBinding};
pub use playlist_definition::{
    EpisodeFilterEntry, EpisodeFilters, EpisodeListSettings, GroupListSettings,
    PlaylistDefinition,
};
pub use preview_grouping::{PlaylistPreviewResult, PreviewGrouping};
pub use root_meta::RootMeta;
pub use sort::{EpisodeSortField, EpisodeSortRule, SortField, SortOrder, SortRule};
pub use title_extractor::{CompiledTitleExtractor, TitleExtractor};
