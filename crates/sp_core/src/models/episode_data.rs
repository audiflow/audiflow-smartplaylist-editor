use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};

/// Interface for episode data used by resolvers and extractors.
pub trait EpisodeData {
    fn id(&self) -> i64;
    fn title(&self) -> &str;
    fn description(&self) -> Option<&str>;
    fn season_number(&self) -> Option<i32>;
    fn episode_number(&self) -> Option<i32>;
    fn published_at(&self) -> Option<DateTime<Utc>>;
    fn image_url(&self) -> Option<&str>;
}

/// Simple implementation of [EpisodeData] for testing and web service use.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SimpleEpisodeData {
    pub id: i64,
    pub title: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub description: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub season_number: Option<i32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub episode_number: Option<i32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub published_at: Option<DateTime<Utc>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub image_url: Option<String>,
}

impl EpisodeData for SimpleEpisodeData {
    fn id(&self) -> i64 {
        self.id
    }

    fn title(&self) -> &str {
        &self.title
    }

    fn description(&self) -> Option<&str> {
        self.description.as_deref()
    }

    fn season_number(&self) -> Option<i32> {
        self.season_number
    }

    fn episode_number(&self) -> Option<i32> {
        self.episode_number
    }

    fn published_at(&self) -> Option<DateTime<Utc>> {
        self.published_at
    }

    fn image_url(&self) -> Option<&str> {
        self.image_url.as_deref()
    }
}
