use std::collections::HashMap;
use std::path::PathBuf;
use std::sync::{Arc, Mutex};

use notify::{Event, EventKind, RecursiveMode, Watcher};
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
    pub fn new(
        watch_dir: PathBuf,
        ignore_patterns: Vec<String>,
    ) -> Result<Self, notify::Error> {
        let (sender, _) = broadcast::channel(100);
        let tx = sender.clone();
        let watch_dir_str = watch_dir.to_string_lossy().to_string();
        let pending: Arc<Mutex<HashMap<String, FileChangeEvent>>> =
            Arc::new(Mutex::new(HashMap::new()));
        let pending_clone = Arc::clone(&pending);
        let tx_flush = tx.clone();

        // Debounce timer handle, reset on each event.
        let debounce_handle: Arc<Mutex<Option<tokio::task::JoinHandle<()>>>> =
            Arc::new(Mutex::new(None));
        let debounce_clone = Arc::clone(&debounce_handle);

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

            let prefix = if watch_dir_str.ends_with('/') {
                watch_dir_str.clone()
            } else {
                format!("{}/", watch_dir_str)
            };

            for path in &event.paths {
                let path_str = path.to_string_lossy();
                let relative = match path_str.strip_prefix(&prefix) {
                    Some(r) => r.to_string(),
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
            if let Ok(mut handle) = debounce_clone.lock() {
                if let Some(h) = handle.take() {
                    h.abort();
                }
                let pending_flush = Arc::clone(&pending);
                let tx = tx_flush.clone();
                *handle = Some(tokio::spawn(async move {
                    tokio::time::sleep(std::time::Duration::from_millis(200)).await;
                    if let Ok(mut map) = pending_flush.lock() {
                        for (_, event) in map.drain() {
                            // Ignore send errors (no receivers connected)
                            let _ = tx.send(event);
                        }
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
