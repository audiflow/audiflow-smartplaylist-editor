import 'dart:async';

import 'package:watcher/watcher.dart';

/// Types of file changes detected by [FileWatcherService].
enum FileChangeType { created, modified, deleted }

/// An event describing a single file change.
final class FileChangeEvent {
  const FileChangeEvent({required this.type, required this.path});

  /// The kind of change that occurred.
  final FileChangeType type;

  /// Relative path from the watched directory.
  final String path;

  /// Serializes this event to a JSON-compatible map.
  Map<String, String> toJson() => {'type': type.name, 'path': path};

  @override
  String toString() => 'FileChangeEvent(${type.name}, $path)';
}

/// Watches a directory for file changes and emits debounced,
/// deduplicated [FileChangeEvent]s.
///
/// Uses `package:watcher` which handles recursive subdirectory
/// watching on Linux via manual inotify management, unlike
/// `Directory.watch(recursive: true)` which is unreliable in
/// some environments.
///
/// Events are collected during a debounce window and flushed as a
/// batch. If the same path changes multiple times within one window,
/// only the latest event is kept.
class FileWatcherService {
  FileWatcherService({
    required this.watchDir,
    this.debounceMs = 200,
    this.ignorePatterns = const [],
  });

  /// The directory to watch recursively.
  final String watchDir;

  /// Debounce delay in milliseconds.
  final int debounceMs;

  /// Path prefixes to ignore (e.g. `.cache`).
  final List<String> ignorePatterns;

  DirectoryWatcher? _watcher;
  StreamSubscription<WatchEvent>? _watchSubscription;
  StreamController<FileChangeEvent>? _controller;
  Timer? _debounceTimer;

  /// Pending events keyed by relative path. Within one debounce
  /// window, later events for the same path overwrite earlier ones.
  final Map<String, FileChangeEvent> _pending = {};

  /// A broadcast stream of file change events.
  Stream<FileChangeEvent> get events {
    _controller ??= StreamController<FileChangeEvent>.broadcast();
    return _controller!.stream;
  }

  /// Begins watching [watchDir] recursively for file system changes.
  Future<void> start() async {
    _controller ??= StreamController<FileChangeEvent>.broadcast();

    _watcher = DirectoryWatcher(watchDir);
    _watchSubscription = _watcher!.events.listen(_onWatchEvent);

    // Wait for the watcher to fully enumerate the directory tree
    await _watcher!.ready;
  }

  /// Stops watching and closes the event stream.
  Future<void> stop() async {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _flushPending();

    await _watchSubscription?.cancel();
    _watchSubscription = null;

    await _controller?.close();
    _controller = null;
  }

  /// Maps a [WatchEvent] to our domain model and queues it
  /// for debounced emission.
  void _onWatchEvent(WatchEvent event) {
    final relativePath = _toRelativePath(event.path);
    if (relativePath == null) return;
    if (_shouldIgnore(relativePath)) return;

    final changeType = _mapChangeType(event.type);
    final changeEvent = FileChangeEvent(type: changeType, path: relativePath);

    _pending[relativePath] = changeEvent;
    _resetDebounceTimer();
  }

  /// Converts an absolute filesystem path to a path relative to
  /// [watchDir]. Returns null if the path is not under watchDir.
  String? _toRelativePath(String absolutePath) {
    final prefix = watchDir.endsWith('/') ? watchDir : '$watchDir/';
    if (!absolutePath.startsWith(prefix)) return null;
    return absolutePath.substring(prefix.length);
  }

  /// Returns true if the path should be ignored based on
  /// [ignorePatterns] or .tmp suffix.
  bool _shouldIgnore(String relativePath) {
    // Ignore .tmp files (produced by atomic writes)
    if (relativePath.endsWith('.tmp')) return true;

    // Ignore paths starting with any ignore pattern
    for (final pattern in ignorePatterns) {
      if (relativePath.startsWith(pattern)) return true;
    }

    return false;
  }

  /// Maps a [ChangeType] to our [FileChangeType].
  FileChangeType _mapChangeType(ChangeType type) {
    if (type == ChangeType.ADD) return FileChangeType.created;
    if (type == ChangeType.REMOVE) return FileChangeType.deleted;
    return FileChangeType.modified;
  }

  /// Resets the debounce timer. When it fires, all pending events
  /// are flushed to the stream.
  void _resetDebounceTimer() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(Duration(milliseconds: debounceMs), _flushPending);
  }

  /// Emits all pending events and clears the buffer.
  void _flushPending() {
    if (_pending.isEmpty) return;

    final controller = _controller;
    if (controller == null || controller.isClosed) {
      _pending.clear();
      return;
    }

    for (final event in _pending.values) {
      controller.add(event);
    }
    _pending.clear();
  }
}
