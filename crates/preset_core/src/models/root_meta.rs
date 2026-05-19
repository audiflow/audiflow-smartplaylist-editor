use serde::{Deserialize, Serialize};

use super::preset_summary::PresetSummary;

/// Root meta.json from the split config repository.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct RootMeta {
    pub data_version: i32,
    pub schema_version: i32,
    pub presets: Vec<PresetSummary>,
}
