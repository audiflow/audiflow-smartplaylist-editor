import 'dart:io';

import 'package:sp_server/src/services/file_watcher_service.dart';
import 'package:test/test.dart';

void main() {
  group('FileChangeEvent', () {
    test('toJson returns type name and relative path', () {
      const event = FileChangeEvent(
        type: FileChangeType.created,
        path: 'patterns/podcast-a/meta.json',
      );

      expect(
        event.toJson(),
        equals({'type': 'created', 'path': 'patterns/podcast-a/meta.json'}),
      );
    });

    test('toJson works for all change types', () {
      for (final changeType in FileChangeType.values) {
        final event = FileChangeEvent(type: changeType, path: 'test.json');
        expect(event.toJson()['type'], equals(changeType.name));
      }
    });
  });

  group('FileWatcherService', () {
    late Directory tempDir;
    late FileWatcherService watcher;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('file_watcher_test_');
    });

    tearDown(() async {
      await watcher.stop();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });
    test('emits event when file is created', () async {
      watcher = FileWatcherService(watchDir: tempDir.path, debounceMs: 100);
      await watcher.start();

      final events = <FileChangeEvent>[];
      final subscription = watcher.events.listen(events.add);

      // Create a file after the watcher is started
      await File('${tempDir.path}/test.json').writeAsString('{}');

      // Wait for debounce + FS watcher latency
      await Future<void>.delayed(const Duration(milliseconds: 400));
      await subscription.cancel();

      expect(events, isNotEmpty);
      expect(
        events.any((e) => e.path == 'test.json'),
        isTrue,
        reason: 'Expected an event with relative path "test.json"',
      );
    });

    test('emits event when file is modified', () async {
      // Create file before starting watcher
      final file = File('${tempDir.path}/existing.json');
      await file.writeAsString('{"v": 1}');

      watcher = FileWatcherService(watchDir: tempDir.path, debounceMs: 100);
      await watcher.start();

      final events = <FileChangeEvent>[];
      final subscription = watcher.events.listen(events.add);

      // Modify the file
      await file.writeAsString('{"v": 2}');

      await Future<void>.delayed(const Duration(milliseconds: 400));
      await subscription.cancel();

      expect(events, isNotEmpty);
      expect(
        events.any((e) => e.path == 'existing.json'),
        isTrue,
        reason: 'Expected an event for modified file',
      );
    });

    test('emits event when file is deleted', () async {
      // Create file before starting watcher
      final file = File('${tempDir.path}/to-delete.json');
      await file.writeAsString('{}');

      watcher = FileWatcherService(watchDir: tempDir.path, debounceMs: 100);
      await watcher.start();

      final events = <FileChangeEvent>[];
      final subscription = watcher.events.listen(events.add);

      // Delete the file
      await file.delete();

      await Future<void>.delayed(const Duration(milliseconds: 400));
      await subscription.cancel();

      expect(events, isNotEmpty);
      expect(
        events.any(
          (e) => e.path == 'to-delete.json' && e.type == FileChangeType.deleted,
        ),
        isTrue,
        reason: 'Expected a deleted event for "to-delete.json"',
      );
    });

    test('ignores files matching ignorePatterns', () async {
      final cacheDir = Directory('${tempDir.path}/.cache');
      await cacheDir.create();

      watcher = FileWatcherService(
        watchDir: tempDir.path,
        debounceMs: 100,
        ignorePatterns: ['.cache'],
      );
      await watcher.start();

      final events = <FileChangeEvent>[];
      final subscription = watcher.events.listen(events.add);

      // Create file in .cache directory (should be ignored)
      await File('${cacheDir.path}/data.json').writeAsString('{}');

      // Also create a file that should NOT be ignored
      await File('${tempDir.path}/visible.json').writeAsString('{}');

      await Future<void>.delayed(const Duration(milliseconds: 400));
      await subscription.cancel();

      // Should NOT contain .cache files
      expect(
        events.any((e) => e.path.startsWith('.cache')),
        isFalse,
        reason: 'Events from .cache directory should be ignored',
      );

      // Should contain the visible file
      expect(
        events.any((e) => e.path == 'visible.json'),
        isTrue,
        reason: 'Expected event for visible.json',
      );
    });

    test('ignores .tmp files', () async {
      watcher = FileWatcherService(watchDir: tempDir.path, debounceMs: 100);
      await watcher.start();

      final events = <FileChangeEvent>[];
      final subscription = watcher.events.listen(events.add);

      // Create a .tmp file (should be ignored - from atomic writes)
      await File('${tempDir.path}/data.json.tmp').writeAsString('{}');

      // Create a normal file (should be captured)
      await File('${tempDir.path}/data.json').writeAsString('{}');

      await Future<void>.delayed(const Duration(milliseconds: 400));
      await subscription.cancel();

      expect(
        events.any((e) => e.path.endsWith('.tmp')),
        isFalse,
        reason: '.tmp files should be ignored',
      );
      expect(
        events.any((e) => e.path == 'data.json'),
        isTrue,
        reason: 'Expected event for data.json',
      );
    });

    test(
      'deduplicates events for the same path within debounce window',
      () async {
        watcher = FileWatcherService(watchDir: tempDir.path, debounceMs: 200);
        await watcher.start();

        final events = <FileChangeEvent>[];
        final subscription = watcher.events.listen(events.add);

        // Rapidly write to the same file multiple times within debounce window
        final file = File('${tempDir.path}/rapid.json');
        await file.writeAsString('{"v": 1}');
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await file.writeAsString('{"v": 2}');
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await file.writeAsString('{"v": 3}');

        await Future<void>.delayed(const Duration(milliseconds: 500));
        await subscription.cancel();

        // Should have at most one event per debounce window for the same path
        final rapidEvents = events
            .where((e) => e.path == 'rapid.json')
            .toList();
        // Due to deduplication, we expect fewer events than writes
        // The exact count depends on timing, but should be less than 3
        expect(
          3 <= rapidEvents.length,
          isFalse,
          reason: 'Expected deduplication to reduce events for same path',
        );
      },
    );

    test('emits events for files in subdirectories', () async {
      watcher = FileWatcherService(watchDir: tempDir.path, debounceMs: 100);
      await watcher.start();

      final events = <FileChangeEvent>[];
      final subscription = watcher.events.listen(events.add);

      // Create subdirectory and file after watcher is running
      final subDir = Directory('${tempDir.path}/patterns/podcast-a');
      await subDir.create(recursive: true);
      await File('${subDir.path}/meta.json').writeAsString('{}');

      // Poll until event arrives or timeout (handles slow CI)
      for (var i = 0; i < 20; i++) {
        if (events.any((e) => e.path.contains('meta.json'))) break;
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      await subscription.cancel();

      expect(events, isNotEmpty);
      expect(
        events.any((e) => e.path.contains('meta.json')),
        isTrue,
        reason: 'Expected event for file in subdirectory',
      );
    });

    test('events stream is broadcast', () async {
      watcher = FileWatcherService(watchDir: tempDir.path, debounceMs: 100);
      await watcher.start();

      // Multiple listeners should work on a broadcast stream
      final events1 = <FileChangeEvent>[];
      final events2 = <FileChangeEvent>[];
      final sub1 = watcher.events.listen(events1.add);
      final sub2 = watcher.events.listen(events2.add);

      await File('${tempDir.path}/broadcast.json').writeAsString('{}');

      await Future<void>.delayed(const Duration(milliseconds: 400));
      await sub1.cancel();
      await sub2.cancel();

      expect(events1, isNotEmpty);
      expect(events2, isNotEmpty);
    });
  });
}
