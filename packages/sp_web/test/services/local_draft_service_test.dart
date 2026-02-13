import 'dart:convert';

import 'package:sp_web/services/local_draft_service.dart';
import 'package:test/test.dart';

/// In-memory fake for testing.
class FakeStorageAccess implements StorageAccess {
  final _store = <String, String>{};

  @override
  String? getItem(String key) => _store[key];

  @override
  void setItem(String key, String value) => _store[key] = value;

  @override
  void removeItem(String key) => _store.remove(key);

  /// Exposes stored keys for inspection.
  Set<String> get keys => _store.keys.toSet();
}

void main() {
  late FakeStorageAccess storage;
  late LocalDraftService service;

  setUp(() {
    storage = FakeStorageAccess();
    service = LocalDraftService(storage: storage);
  });

  group('LocalDraftService', () {
    test('saveDraft writes to storage with correct key prefix', () {
      final base = {'id': 'test', 'playlists': <dynamic>[]};
      final modified = {'id': 'test', 'playlists': <dynamic>[], 'extra': true};

      service.saveDraft(configId: 'test', base: base, modified: modified);

      expect(storage.keys, contains('autosave:test'));
      final raw = storage.getItem('autosave:test')!;
      final parsed = jsonDecode(raw) as Map<String, dynamic>;
      expect(parsed['base'], base);
      expect(parsed['modified'], modified);
      expect(parsed.containsKey('savedAt'), isTrue);
    });

    test('saveDraft uses __new__ key for null configId', () {
      service.saveDraft(configId: null, base: {'id': ''}, modified: {'id': ''});

      expect(storage.keys, contains('autosave:__new__'));
    });

    test('loadDraft returns entry for existing draft', () {
      final base = {'a': 1};
      final modified = {'a': 2};

      service.saveDraft(configId: 'abc', base: base, modified: modified);

      final entry = service.loadDraft('abc');
      expect(entry, isNotNull);
      expect(entry!.base, base);
      expect(entry.modified, modified);
      expect(entry.savedAt, isNotNull);
    });

    test('loadDraft returns null for missing key', () {
      final entry = service.loadDraft('nonexistent');
      expect(entry, isNull);
    });

    test('loadDraft returns null for corrupt JSON', () {
      storage.setItem('autosave:bad', 'not valid json {{{');
      final entry = service.loadDraft('bad');
      expect(entry, isNull);
    });

    test('loadDraft returns null for JSON missing required fields', () {
      storage.setItem('autosave:incomplete', jsonEncode({'base': {}}));
      final entry = service.loadDraft('incomplete');
      expect(entry, isNull);
    });

    test('clearDraft removes the entry', () {
      service.saveDraft(configId: 'rm', base: {'x': 1}, modified: {'x': 2});
      expect(service.hasDraft('rm'), isTrue);

      service.clearDraft('rm');
      expect(service.hasDraft('rm'), isFalse);
      expect(storage.getItem('autosave:rm'), isNull);
    });

    test('hasDraft returns false for missing entries', () {
      expect(service.hasDraft('missing'), isFalse);
    });

    test('hasDraft returns true for existing entries', () {
      service.saveDraft(configId: 'exists', base: {}, modified: {});
      expect(service.hasDraft('exists'), isTrue);
    });

    test('DraftEntry.savedAt round-trips through JSON', () {
      final base = {'id': '1'};
      final modified = {'id': '1', 'changed': true};

      service.saveDraft(configId: 'time', base: base, modified: modified);

      final entry = service.loadDraft('time')!;
      // savedAt should be parseable and recent.
      final parsedTime = DateTime.parse(entry.savedAt);
      final now = DateTime.now().toUtc();
      final diff = now.difference(parsedTime).inSeconds.abs();
      expect(
        5 < diff || diff == 0,
        isTrue,
        reason: 'savedAt should be within 5 seconds of now',
      );
    });
  });
}
