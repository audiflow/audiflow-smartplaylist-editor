use std::path::PathBuf;
use std::time::Duration;

use serde_json::Value;
use sha2::{Digest, Sha256};

use super::atomic_write::atomic_write_str;
use super::feed_parser;

/// Disk-based feed cache that can be shared between processes.
///
/// Caches parsed RSS episodes as JSON files on disk, keyed by
/// SHA-256 hash of the feed URL. Two separate processes pointing
/// at the same cache directory will share cached data.
pub struct DiskFeedCacheService {
    cache_dir: PathBuf,
    cache_ttl: Duration,
}

impl DiskFeedCacheService {
    pub fn new(cache_dir: PathBuf, cache_ttl: Duration) -> Self {
        Self {
            cache_dir,
            cache_ttl,
        }
    }

    /// Fetches episodes from the given feed URL.
    ///
    /// Returns cached data from disk if still fresh; otherwise
    /// fetches the RSS feed, parses it, and caches to disk.
    pub async fn fetch_feed(
        &self,
        url: &str,
        client: &reqwest::Client,
    ) -> Result<Vec<Value>, Error> {
        let hash = hash_url(url);
        if let Some(cached) = self.read_cache(&hash) {
            return Ok(cached);
        }

        let response = client
            .get(url)
            .send()
            .await
            .map_err(|e| Error::Http(e.to_string()))?
            .error_for_status()
            .map_err(|e| Error::Http(e.to_string()))?;

        let xml = response
            .text()
            .await
            .map_err(|e| Error::Http(e.to_string()))?;

        let episodes = feed_parser::parse_feed(&xml);
        self.write_cache(&hash, url, &episodes)?;
        Ok(episodes)
    }

    // -- Cache I/O --

    fn meta_path(&self, hash: &str) -> PathBuf {
        self.cache_dir.join(format!("{hash}.meta"))
    }

    fn data_path(&self, hash: &str) -> PathBuf {
        self.cache_dir.join(format!("{hash}.json"))
    }

    /// Reads cached episodes from disk if the cache is fresh.
    fn read_cache(&self, hash: &str) -> Option<Vec<Value>> {
        let meta_path = self.meta_path(hash);
        let meta_content = std::fs::read_to_string(&meta_path).ok()?;
        let meta: serde_json::Map<String, Value> =
            serde_json::from_str(&meta_content).ok()?;

        let fetched_at_str = meta.get("fetchedAt")?.as_str()?;
        let fetched_at = chrono::DateTime::parse_from_rfc3339(fetched_at_str).ok()?;
        let elapsed = chrono::Utc::now().signed_duration_since(fetched_at);
        let ttl_secs = self.cache_ttl.as_secs() as i64;
        if ttl_secs < elapsed.num_seconds() {
            return None;
        }

        let data_path = self.data_path(hash);
        let data_content = std::fs::read_to_string(&data_path).ok()?;
        let episodes: Vec<Value> = serde_json::from_str(&data_content).ok()?;
        Some(episodes)
    }

    /// Writes episodes and metadata to disk atomically.
    /// Data is written before meta so a crash between writes leaves
    /// stale meta (safe cache miss) rather than fresh meta pointing
    /// to stale data.
    fn write_cache(
        &self,
        hash: &str,
        url: &str,
        episodes: &[Value],
    ) -> Result<(), Error> {
        std::fs::create_dir_all(&self.cache_dir).map_err(Error::Io)?;

        let data = serde_json::to_string(episodes)
            .map_err(|e| Error::Io(std::io::Error::other(e)))?;
        let meta = serde_json::to_string(&serde_json::json!({
            "url": url,
            "fetchedAt": chrono::Utc::now().to_rfc3339(),
        }))
        .map_err(|e| Error::Io(std::io::Error::other(e)))?;

        // Write data before meta for crash safety
        atomic_write_str(&self.data_path(hash), &data).map_err(Error::Io)?;
        atomic_write_str(&self.meta_path(hash), &meta).map_err(Error::Io)?;

        Ok(())
    }
}

/// SHA-256 hash of a URL string, returned as lowercase hex.
pub fn hash_url(url: &str) -> String {
    let mut hasher = Sha256::new();
    hasher.update(url.as_bytes());
    format!("{:x}", hasher.finalize())
}

#[derive(Debug)]
pub enum Error {
    Io(std::io::Error),
    Http(String),
}

impl std::fmt::Display for Error {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Error::Io(e) => write!(f, "IO error: {e}"),
            Error::Http(msg) => write!(f, "HTTP error: {msg}"),
        }
    }
}

impl std::error::Error for Error {
    fn source(&self) -> Option<&(dyn std::error::Error + 'static)> {
        match self {
            Error::Io(e) => Some(e),
            _ => None,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::TempDir;

    #[test]
    fn hash_url_produces_consistent_sha256() {
        let hash = hash_url("https://example.com/feed.xml");
        // SHA-256 output is always 64 hex chars
        assert_eq!(hash.len(), 64);
        // Same input produces same hash
        assert_eq!(hash, hash_url("https://example.com/feed.xml"));
        // Different input produces different hash
        assert_ne!(hash, hash_url("https://example.com/other.xml"));
    }

    #[test]
    fn read_cache_returns_none_when_no_cache() {
        let tmp = TempDir::new().unwrap();
        let service = DiskFeedCacheService::new(
            tmp.path().to_path_buf(),
            Duration::from_secs(3600),
        );
        let result = service.read_cache("nonexistent_hash");
        assert!(result.is_none());
    }

    #[test]
    fn write_and_read_cache_round_trip() {
        let tmp = TempDir::new().unwrap();
        let service = DiskFeedCacheService::new(
            tmp.path().to_path_buf(),
            Duration::from_secs(3600),
        );

        let episodes = vec![serde_json::json!({
            "id": 0,
            "title": "Test Episode",
        })];

        let hash = hash_url("https://example.com/feed.xml");
        service
            .write_cache(&hash, "https://example.com/feed.xml", &episodes)
            .unwrap();

        let cached = service.read_cache(&hash);
        assert!(cached.is_some());
        let cached = cached.unwrap();
        assert_eq!(cached.len(), 1);
        assert_eq!(cached[0]["title"], "Test Episode");
    }

    #[test]
    fn read_cache_returns_none_when_stale() {
        let tmp = TempDir::new().unwrap();
        let service = DiskFeedCacheService::new(
            tmp.path().to_path_buf(),
            Duration::from_secs(3600),
        );

        let hash = hash_url("https://example.com/feed.xml");

        // Write data file
        std::fs::write(
            tmp.path().join(format!("{hash}.json")),
            r#"[{"id": 0}]"#,
        )
        .unwrap();

        // Write meta with fetchedAt two hours in the past (stale)
        let past = chrono::Utc::now() - chrono::Duration::hours(2);
        let meta = serde_json::json!({
            "url": "https://example.com/feed.xml",
            "fetchedAt": past.to_rfc3339(),
        });
        std::fs::write(
            tmp.path().join(format!("{hash}.meta")),
            serde_json::to_string(&meta).unwrap(),
        )
        .unwrap();

        let cached = service.read_cache(&hash);
        assert!(cached.is_none());
    }

    #[test]
    fn corrupted_cache_treated_as_miss() {
        let tmp = TempDir::new().unwrap();
        let service = DiskFeedCacheService::new(
            tmp.path().to_path_buf(),
            Duration::from_secs(3600),
        );

        let hash = hash_url("https://example.com/feed.xml");

        // Write corrupted meta
        std::fs::write(
            tmp.path().join(format!("{hash}.meta")),
            "not valid json",
        )
        .unwrap();
        std::fs::write(
            tmp.path().join(format!("{hash}.json")),
            "[{\"id\": 0}]",
        )
        .unwrap();

        let cached = service.read_cache(&hash);
        assert!(cached.is_none());
    }

    #[test]
    fn corrupted_data_file_treated_as_miss() {
        let tmp = TempDir::new().unwrap();
        let service = DiskFeedCacheService::new(
            tmp.path().to_path_buf(),
            Duration::from_secs(3600),
        );

        let hash = hash_url("https://example.com/feed.xml");

        // Write valid meta but corrupted data
        let meta = serde_json::json!({
            "url": "https://example.com/feed.xml",
            "fetchedAt": chrono::Utc::now().to_rfc3339(),
        });
        std::fs::write(
            tmp.path().join(format!("{hash}.meta")),
            serde_json::to_string(&meta).unwrap(),
        )
        .unwrap();
        std::fs::write(
            tmp.path().join(format!("{hash}.json")),
            "not valid json array",
        )
        .unwrap();

        let cached = service.read_cache(&hash);
        assert!(cached.is_none());
    }

    #[test]
    fn write_cache_creates_directory_if_missing() {
        let tmp = TempDir::new().unwrap();
        let cache_dir = tmp.path().join("nested").join("cache");
        let service = DiskFeedCacheService::new(
            cache_dir.clone(),
            Duration::from_secs(3600),
        );

        let episodes = vec![serde_json::json!({"id": 0})];
        let hash = hash_url("https://example.com/feed.xml");
        service
            .write_cache(&hash, "https://example.com/feed.xml", &episodes)
            .unwrap();

        assert!(cache_dir.exists());
    }
}
