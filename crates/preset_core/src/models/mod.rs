pub mod episode_data;
pub mod group_def;
pub mod numbering_extractor;
pub mod playlist;
pub mod playlist_definition;
pub mod preset_config;
pub mod preset_meta;
pub mod preset_summary;
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
pub use group_def::{
    GroupDef, GroupDefEpisodeItem, GroupDefEpisodeListing, GroupDefGroupItem, GroupDefGroupListing,
    Matcher,
};
pub use numbering_extractor::{
    CompiledNumberingExtractor, NumberingExtractionResult, NumberingExtractor,
};
pub use playlist::{Grouping, Playlist, PlaylistGroup, Presentation, YearBinding};
pub use playlist_definition::{
    EpisodeFilterEntry, EpisodeFilters, EpisodeItemConfig, EpisodeListingConfig, GroupItemConfig,
    GroupListingConfig, GroupingConfig, PlaylistDefinition, SelectorConfig,
};
pub use preset_config::PresetConfig;
pub use preset_meta::PresetMeta;
pub use preset_summary::PresetSummary;
pub use preview_grouping::{PlaylistPreviewResult, PreviewGrouping};
pub use root_meta::RootMeta;
pub use sort::{EpisodeSortField, EpisodeSortRule, SortField, SortOrder, SortRule};
pub use title_extractor::{CompiledTitleExtractor, TitleExtractor};
