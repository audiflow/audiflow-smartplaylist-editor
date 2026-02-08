import 'package:test/test.dart';

import 'package:sp_server/src/services/draft_service.dart';

void main() {
  group('DraftService', () {
    late DraftService service;

    setUp(() {
      service = DraftService();
    });

    group('saveDraft', () {
      test('creates draft with generated id', () {
        final draft = service.saveDraft('user-1', 'My Draft', {'key': 'value'});

        expect(draft.id, startsWith('draft_'));
        expect(draft.userId, equals('user-1'));
        expect(draft.name, equals('My Draft'));
        expect(draft.configJson, equals({'key': 'value'}));
        expect(draft.feedUrl, isNull);
        expect(draft.createdAt, isA<DateTime>());
        expect(draft.updatedAt, isA<DateTime>());
      });

      test('stores optional feedUrl', () {
        final draft = service.saveDraft('user-1', 'With Feed', {
          'key': 'value',
        }, feedUrl: 'https://example.com/feed.xml');

        expect(draft.feedUrl, equals('https://example.com/feed.xml'));
      });

      test('generates unique ids', () {
        final draft1 = service.saveDraft('user-1', 'Draft A', {'a': 1});
        final draft2 = service.saveDraft('user-1', 'Draft B', {'b': 2});

        expect(draft1.id, isNot(equals(draft2.id)));
      });
    });

    group('listDrafts', () {
      test('returns empty list for unknown user', () {
        final drafts = service.listDrafts('nobody');
        expect(drafts, isEmpty);
      });

      test('returns drafts for user', () {
        service.saveDraft('user-1', 'Draft A', {'a': 1});
        service.saveDraft('user-1', 'Draft B', {'b': 2});
        service.saveDraft('user-2', 'Other', {'c': 3});

        final drafts = service.listDrafts('user-1');
        expect(drafts.length, equals(2));
        expect(drafts.map((d) => d.name), containsAll(['Draft A', 'Draft B']));
      });

      test('does not include other users drafts', () {
        service.saveDraft('user-1', 'Mine', {'a': 1});
        service.saveDraft('user-2', 'Theirs', {'b': 2});

        final drafts = service.listDrafts('user-1');
        expect(drafts.length, equals(1));
        expect(drafts.first.name, equals('Mine'));
      });

      test('returns drafts sorted by updatedAt desc', () {
        service.saveDraft('user-1', 'First', {'a': 1});
        service.saveDraft('user-1', 'Second', {'b': 2});
        service.saveDraft('user-1', 'Third', {'c': 3});

        final drafts = service.listDrafts('user-1');
        expect(drafts.length, equals(3));

        // Newest first.
        expect(drafts.first.name, equals('Third'));
        expect(drafts.last.name, equals('First'));
      });
    });

    group('getDraft', () {
      test('returns draft by id', () {
        final saved = service.saveDraft('user-1', 'Target', {'key': 'val'});

        final found = service.getDraft('user-1', saved.id);
        expect(found, isNotNull);
        expect(found!.name, equals('Target'));
      });

      test('returns null for non-existent id', () {
        final found = service.getDraft('user-1', 'fake-id');
        expect(found, isNull);
      });

      test('returns null when userId does not match', () {
        final saved = service.saveDraft('user-1', 'Private', {'key': 'val'});

        final found = service.getDraft('user-2', saved.id);
        expect(found, isNull);
      });
    });

    group('deleteDraft', () {
      test('deletes existing draft', () {
        final saved = service.saveDraft('user-1', 'ToDelete', {'key': 'val'});

        final deleted = service.deleteDraft('user-1', saved.id);
        expect(deleted, isTrue);
        expect(service.listDrafts('user-1'), isEmpty);
      });

      test('returns false for non-existent draft', () {
        final deleted = service.deleteDraft('user-1', 'fake-id');
        expect(deleted, isFalse);
      });

      test('returns false when userId does not match', () {
        final saved = service.saveDraft('user-1', 'Mine', {'key': 'val'});

        final deleted = service.deleteDraft('user-2', saved.id);
        expect(deleted, isFalse);

        // Draft should still exist for user-1.
        expect(service.listDrafts('user-1').length, equals(1));
      });
    });

    group('toJson', () {
      test('serializes all fields', () {
        final draft = service.saveDraft('user-1', 'JSON Test', {
          'config': true,
        }, feedUrl: 'https://example.com/feed');

        final json = draft.toJson();
        expect(json['id'], startsWith('draft_'));
        expect(json['userId'], equals('user-1'));
        expect(json['name'], equals('JSON Test'));
        expect(json['config'], equals({'config': true}));
        expect(json['feedUrl'], equals('https://example.com/feed'));
        expect(json['createdAt'], isA<String>());
        expect(json['updatedAt'], isA<String>());
      });

      test('feedUrl is null when not provided', () {
        final draft = service.saveDraft('user-1', 'No Feed', {'config': true});

        final json = draft.toJson();
        expect(json['feedUrl'], isNull);
      });
    });
  });
}
