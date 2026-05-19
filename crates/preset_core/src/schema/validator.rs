use jsonschema::Validator as JsonSchemaValidator;
use serde_json::Value;
use std::path::Path;

const PRESET_INDEX_SCHEMA: &str = include_str!("../../assets/preset-index.schema.json");
const PRESET_META_SCHEMA: &str = include_str!("../../assets/preset-meta.schema.json");
const PLAYLIST_DEFINITION_SCHEMA: &str =
    include_str!("../../assets/playlist-definition.schema.json");

/// Identifies which JSON Schema to validate against.
pub enum SchemaType {
    /// Root `meta.json` containing dataVersion, schemaVersion, and preset summaries.
    PresetIndex,
    /// Per-preset `meta.json` with feedUrls, flags, and playlist IDs.
    PresetMeta,
    /// Individual playlist definition file.
    PlaylistDefinition,
}

/// Holds compiled validators for the three canonical schema files.
pub struct Validator {
    preset_index: JsonSchemaValidator,
    preset_meta: JsonSchemaValidator,
    playlist_definition: JsonSchemaValidator,
}

impl Validator {
    /// Load all three schemas from a directory containing the `.schema.json` files.
    pub fn from_dir(schema_dir: &Path) -> Result<Self, Box<dyn std::error::Error>> {
        let load = |name: &str| -> Result<JsonSchemaValidator, Box<dyn std::error::Error>> {
            let path = schema_dir.join(name);
            let content = std::fs::read_to_string(&path)?;
            let schema: Value = serde_json::from_str(&content)?;
            let validator = JsonSchemaValidator::new(&schema)
                .map_err(|e| format!("failed to compile schema {name}: {e}"))?;
            Ok(validator)
        };

        Ok(Self {
            preset_index: load("preset-index.schema.json")?,
            preset_meta: load("preset-meta.schema.json")?,
            playlist_definition: load("playlist-definition.schema.json")?,
        })
    }

    /// Creates a validator using schemas embedded at compile time.
    /// The binary is self-contained and does not need schema files on disk.
    pub fn from_embedded() -> Result<Self, Box<dyn std::error::Error>> {
        let compile = |content: &str,
                       name: &str|
         -> Result<JsonSchemaValidator, Box<dyn std::error::Error>> {
            let schema: Value = serde_json::from_str(content)?;
            let validator = JsonSchemaValidator::new(&schema)
                .map_err(|e| format!("failed to compile embedded schema {name}: {e}"))?;
            Ok(validator)
        };

        Ok(Self {
            preset_index: compile(PRESET_INDEX_SCHEMA, "preset-index")?,
            preset_meta: compile(PRESET_META_SCHEMA, "preset-meta")?,
            playlist_definition: compile(PLAYLIST_DEFINITION_SCHEMA, "playlist-definition")?,
        })
    }

    /// Returns the raw playlist-definition schema JSON string (embedded).
    pub fn playlist_definition_schema_json() -> &'static str {
        PLAYLIST_DEFINITION_SCHEMA
    }

    /// Validate a JSON value against the specified schema type.
    /// Returns an empty `Vec` when valid, or a list of error messages.
    pub fn validate(&self, schema_type: SchemaType, value: &Value) -> Vec<String> {
        let validator = match schema_type {
            SchemaType::PresetIndex => &self.preset_index,
            SchemaType::PresetMeta => &self.preset_meta,
            SchemaType::PlaylistDefinition => &self.playlist_definition,
        };
        validator
            .iter_errors(value)
            .map(|e| e.to_string())
            .collect()
    }
}
