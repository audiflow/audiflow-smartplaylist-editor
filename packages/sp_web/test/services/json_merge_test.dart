import 'package:test/test.dart';
import 'package:sp_web/services/json_merge.dart';

void main() {
  group('JsonMerge.merge', () {
    test('returns latest when nothing changed', () {
      final base = {'a': 1, 'b': 2};
      final latest = {'a': 1, 'b': 3};
      final modified = {'a': 1, 'b': 2};

      final result = JsonMerge.merge(
        base: base,
        latest: latest,
        modified: modified,
      );
      expect(result, {'a': 1, 'b': 3});
    });

    test('user change wins over upstream unchanged', () {
      final base = {'a': 1, 'b': 2};
      final latest = {'a': 1, 'b': 2};
      final modified = {'a': 99, 'b': 2};

      final result = JsonMerge.merge(
        base: base,
        latest: latest,
        modified: modified,
      );
      expect(result, {'a': 99, 'b': 2});
    });

    test('user change wins over upstream change (conflict)', () {
      final base = {'a': 1};
      final latest = {'a': 10};
      final modified = {'a': 99};

      final result = JsonMerge.merge(
        base: base,
        latest: latest,
        modified: modified,
      );
      expect(result, {'a': 99});
    });

    test('upstream change preserved when user did not modify', () {
      final base = {'a': 1, 'b': 2};
      final latest = {'a': 1, 'b': 42};
      final modified = {'a': 1, 'b': 2};

      final result = JsonMerge.merge(
        base: base,
        latest: latest,
        modified: modified,
      );
      expect(result, {'a': 1, 'b': 42});
    });

    test('user-added key preserved', () {
      final base = <String, dynamic>{'a': 1};
      final latest = <String, dynamic>{'a': 1};
      final modified = <String, dynamic>{'a': 1, 'newKey': 'hello'};

      final result = JsonMerge.merge(
        base: base,
        latest: latest,
        modified: modified,
      );
      expect(result, {'a': 1, 'newKey': 'hello'});
    });

    test('upstream-added key preserved when user did not touch it', () {
      final base = <String, dynamic>{'a': 1};
      final latest = <String, dynamic>{'a': 1, 'upstream': true};
      final modified = <String, dynamic>{'a': 1};

      final result = JsonMerge.merge(
        base: base,
        latest: latest,
        modified: modified,
      );
      expect(result, {'a': 1, 'upstream': true});
    });

    test('user-removed key stays removed even if upstream kept it', () {
      final base = <String, dynamic>{'a': 1, 'b': 2};
      final latest = <String, dynamic>{'a': 1, 'b': 2};
      final modified = <String, dynamic>{'a': 1};

      final result = JsonMerge.merge(
        base: base,
        latest: latest,
        modified: modified,
      );
      expect(result, {'a': 1});
    });

    test('upstream-removed key stays removed when user did not change it', () {
      final base = <String, dynamic>{'a': 1, 'b': 2};
      final latest = <String, dynamic>{'a': 1};
      final modified = <String, dynamic>{'a': 1, 'b': 2};

      final result = JsonMerge.merge(
        base: base,
        latest: latest,
        modified: modified,
      );
      expect(result, {'a': 1});
    });

    test('nested map recursion', () {
      final base = {
        'nested': {'x': 1, 'y': 2},
      };
      final latest = {
        'nested': {'x': 1, 'y': 5},
      };
      final modified = {
        'nested': {'x': 99, 'y': 2},
      };

      final result = JsonMerge.merge(
        base: base,
        latest: latest,
        modified: modified,
      );
      expect(result, {
        'nested': {'x': 99, 'y': 5},
      });
    });

    test('deeply nested map recursion', () {
      final base = {
        'a': {
          'b': {'c': 1, 'd': 2},
        },
      };
      final latest = {
        'a': {
          'b': {'c': 1, 'd': 10},
        },
      };
      final modified = {
        'a': {
          'b': {'c': 99, 'd': 2},
        },
      };

      final result = JsonMerge.merge(
        base: base,
        latest: latest,
        modified: modified,
      );
      expect(result, {
        'a': {
          'b': {'c': 99, 'd': 10},
        },
      });
    });

    group('arrays with id fields', () {
      test('merges matched items by id', () {
        final base = {
          'items': [
            {'id': 'a', 'name': 'Alpha', 'val': 1},
            {'id': 'b', 'name': 'Beta', 'val': 2},
          ],
        };
        final latest = {
          'items': [
            {'id': 'a', 'name': 'Alpha', 'val': 10},
            {'id': 'b', 'name': 'Beta', 'val': 2},
          ],
        };
        final modified = {
          'items': [
            {'id': 'a', 'name': 'Alpha Modified', 'val': 1},
            {'id': 'b', 'name': 'Beta', 'val': 2},
          ],
        };

        final result = JsonMerge.merge(
          base: base,
          latest: latest,
          modified: modified,
        );
        expect(result, {
          'items': [
            {'id': 'a', 'name': 'Alpha Modified', 'val': 10},
            {'id': 'b', 'name': 'Beta', 'val': 2},
          ],
        });
      });

      test('user-added items appended', () {
        final base = {
          'items': [
            {'id': 'a', 'name': 'Alpha'},
          ],
        };
        final latest = {
          'items': [
            {'id': 'a', 'name': 'Alpha'},
          ],
        };
        final modified = {
          'items': [
            {'id': 'a', 'name': 'Alpha'},
            {'id': 'new', 'name': 'New Item'},
          ],
        };

        final result = JsonMerge.merge(
          base: base,
          latest: latest,
          modified: modified,
        );
        expect(result, {
          'items': [
            {'id': 'a', 'name': 'Alpha'},
            {'id': 'new', 'name': 'New Item'},
          ],
        });
      });

      test('upstream-removed items dropped when user did not modify them', () {
        final base = {
          'items': [
            {'id': 'a', 'name': 'Alpha'},
            {'id': 'b', 'name': 'Beta'},
          ],
        };
        final latest = {
          'items': [
            {'id': 'a', 'name': 'Alpha'},
          ],
        };
        final modified = {
          'items': [
            {'id': 'a', 'name': 'Alpha'},
            {'id': 'b', 'name': 'Beta'},
          ],
        };

        final result = JsonMerge.merge(
          base: base,
          latest: latest,
          modified: modified,
        );
        expect(result, {
          'items': [
            {'id': 'a', 'name': 'Alpha'},
          ],
        });
      });

      test('upstream-removed items kept if user modified them', () {
        final base = {
          'items': [
            {'id': 'a', 'name': 'Alpha'},
            {'id': 'b', 'name': 'Beta'},
          ],
        };
        final latest = {
          'items': [
            {'id': 'a', 'name': 'Alpha'},
          ],
        };
        final modified = {
          'items': [
            {'id': 'a', 'name': 'Alpha'},
            {'id': 'b', 'name': 'Beta Modified'},
          ],
        };

        final result = JsonMerge.merge(
          base: base,
          latest: latest,
          modified: modified,
        );
        expect(result, {
          'items': [
            {'id': 'a', 'name': 'Alpha'},
            {'id': 'b', 'name': 'Beta Modified'},
          ],
        });
      });
    });

    group('arrays without id fields', () {
      test('merges by index', () {
        final base = {
          'tags': ['a', 'b', 'c'],
        };
        final latest = {
          'tags': ['a', 'B', 'c'],
        };
        final modified = {
          'tags': ['A', 'b', 'c'],
        };

        final result = JsonMerge.merge(
          base: base,
          latest: latest,
          modified: modified,
        );
        // User changed index 0 (a->A), upstream changed index 1 (b->B)
        expect(result, {
          'tags': ['A', 'B', 'c'],
        });
      });

      test('user-appended items kept', () {
        final base = {
          'tags': ['a'],
        };
        final latest = {
          'tags': ['a'],
        };
        final modified = {
          'tags': ['a', 'b'],
        };

        final result = JsonMerge.merge(
          base: base,
          latest: latest,
          modified: modified,
        );
        expect(result, {
          'tags': ['a', 'b'],
        });
      });

      test('upstream-appended items kept when user did not add', () {
        final base = {
          'tags': ['a'],
        };
        final latest = {
          'tags': ['a', 'upstream'],
        };
        final modified = {
          'tags': ['a'],
        };

        final result = JsonMerge.merge(
          base: base,
          latest: latest,
          modified: modified,
        );
        expect(result, {
          'tags': ['a', 'upstream'],
        });
      });
    });

    test('type change from map to scalar uses user value', () {
      final base = <String, dynamic>{
        'field': {'nested': 1},
      };
      final latest = <String, dynamic>{
        'field': {'nested': 1},
      };
      final modified = <String, dynamic>{'field': 'replaced'};

      final result = JsonMerge.merge(
        base: base,
        latest: latest,
        modified: modified,
      );
      expect(result, {'field': 'replaced'});
    });

    test('null values handled correctly', () {
      final base = <String, dynamic>{'a': null, 'b': 1};
      final latest = <String, dynamic>{'a': null, 'b': 2};
      final modified = <String, dynamic>{'a': 'set', 'b': 1};

      final result = JsonMerge.merge(
        base: base,
        latest: latest,
        modified: modified,
      );
      expect(result, {'a': 'set', 'b': 2});
    });

    test('all three identical returns same', () {
      final data = {
        'x': 1,
        'y': [1, 2],
      };
      final result = JsonMerge.merge(base: data, latest: data, modified: data);
      expect(result, data);
    });
  });
}
