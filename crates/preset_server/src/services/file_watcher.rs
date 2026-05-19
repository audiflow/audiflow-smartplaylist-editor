use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex};

use notify::{Event, EventKind, RecursiveMode, Watcher};
use tokio::runtime::Handle;
use tokio::sync::broadcast;

/// Types of file changes detected by the watcher.
#[derive(Debug, Clone, serde::Serialize)]
#[serde(rename_all = "camelCase")]
pub enum FileChangeType {
    Created,
    Modified,
    Deleted,
}

impl std::fmt::Display for FileChangeType {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            FileChangeType::Created => write!(f, "created"),
            FileChangeType::Modified => write!(f, "modified"),
            FileChangeType::Deleted => write!(f, "deleted"),
        }
    }
}

/// An event describing a single file change.
#[derive(Debug, Clone, serde::Serialize)]
pub struct FileChangeEvent {
    #[serde(rename = "type")]
    pub change_type: FileChangeType,
    pub path: String,
}

/// Watches a directory for file changes and broadcasts debounced,
/// deduplicated events.
///
/// Events are collected during a debounce window and flushed as a
/// batch. If the same path changes multiple times within one window,
/// only the latest event is kept.
pub struct FileWatcherService {
    sender: broadcast::Sender<FileChangeEvent>,
    // Keep the watcher alive by storing it in the struct.
    _watcher: notify::RecommendedWatcher,
}

impl FileWatcherService {
    /// Creates a new watcher on the given directory.
    ///
    /// The `ignore_patterns` parameter lists path prefixes to ignore
    /// (e.g., `.cache`). Files ending in `.tmp` are always ignored
    /// (produced by atomic writes).
    pub fn new(watch_dir: PathBuf, ignore_patterns: Vec<String>) -> Result<Self, notify::Error> {
        let (sender, _) = broadcast::channel(100);
        let tx = sender.clone();
        let pending: Arc<Mutex<HashMap<String, FileChangeEvent>>> =
            Arc::new(Mutex::new(HashMap::new()));
        let pending_clone = Arc::clone(&pending);
        let tx_flush = tx.clone();

        // Capture the tokio runtime handle so we can spawn from the
        // notify callback (which runs on an OS thread, not a tokio task).
        let handle = Handle::try_current().map_err(|_| {
            notify::Error::generic("FileWatcherService must be created within a Tokio runtime")
        })?;

        // Debounce timer handle, reset on each event.
        let debounce_handle: Arc<Mutex<Option<tokio::task::JoinHandle<()>>>> =
            Arc::new(Mutex::new(None));
        let debounce_clone = Arc::clone(&debounce_handle);

        let watch_dir_clone = watch_dir.clone();
        let mut watcher = notify::recommended_watcher(move |res: Result<Event, _>| {
            let event = match res {
                Ok(e) => e,
                Err(_) => return,
            };

            let change_type = match event.kind {
                EventKind::Create(_) => FileChangeType::Created,
                EventKind::Modify(_) => FileChangeType::Modified,
                EventKind::Remove(_) => FileChangeType::Deleted,
                _ => return,
            };

            for path in &event.paths {
                let relative = match to_relative(path, &watch_dir_clone) {
                    Some(r) => r,
                    None => continue,
                };

                // Ignore .tmp files (produced by atomic writes)
                if relative.ends_with(".tmp") {
                    continue;
                }

                // Ignore paths matching configured patterns
                let should_ignore = ignore_patterns
                    .iter()
                    .any(|pattern| relative.starts_with(pattern.as_str()));
                if should_ignore {
                    continue;
                }

                let change_event = FileChangeEvent {
                    change_type: change_type.clone(),
                    path: relative.clone(),
                };

                if let Ok(mut map) = pending_clone.lock() {
                    map.insert(relative, change_event);
                }
            }

            // Reset debounce timer
            if let Ok(mut guard) = debounce_clone.lock() {
                if let Some(h) = guard.take() {
                    h.abort();
                }
                let pending_flush = Arc::clone(&pending);
                let tx = tx_flush.clone();
                *guard = Some(handle.spawn(async move {
                    tokio::time::sleep(std::time::Duration::from_millis(200)).await;
                    // Drain under std::sync::Mutex in a blocking task to
                    // avoid holding the lock on a Tokio worker thread.
                    let events = tokio::task::spawn_blocking(move || {
                        pending_flush
                            .lock()
                            .ok()
                            .map(|mut map| map.drain().map(|(_, e)| e).collect::<Vec<_>>())
                            .unwrap_or_default()
                    })
                    .await
                    .unwrap_or_default();
                    for event in events {
                        let _ = tx.send(event);
                    }
                }));
            }
        })?;

        watcher.watch(&watch_dir, RecursiveMode::Recursive)?;

        Ok(Self {
            sender,
            _watcher: watcher,
        })
    }

    /// Returns a new receiver for file change events.
    pub fn subscribe(&self) -> broadcast::Receiver<FileChangeEvent> {
        self.sender.subscribe()
    }
}

/// Converts an absolute path to a relative path under `base`, using
/// `Path::strip_prefix` for portable behavior across platforms.
fn to_relative(path: &Path, base: &Path) -> Option<String> {
    path.strip_prefix(base)
        .ok()
        .map(|p| p.to_string_lossy().replace('\\', "/"))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn to_relative_strips_base_prefix() {
        let base = Path::new("/data/configs");
        let path = Path::new("/data/configs/patterns/meta.json");
        assert_eq!(
            to_relative(path, base),
            Some("patterns/meta.json".to_string())
        );
    }

    #[test]
    fn to_relative_returns_none_for_unrelated_path() {
        let base = Path::new("/data/configs");
        let path = Path::new("/other/dir/file.json");
        assert_eq!(to_relative(path, base), None);
    }

    #[test]
    fn to_relative_handles_nested_paths() {
        let base = Path::new("/data");
        let path = Path::new("/data/a/b/c/d.json");
        assert_eq!(to_relative(path, base), Some("a/b/c/d.json".to_string()));
    }

    #[test]
    fn to_relative_returns_empty_for_exact_match() {
        let base = Path::new("/data/configs");
        let path = Path::new("/data/configs");
        assert_eq!(to_relative(path, base), Some("".to_string()));
    }
}
