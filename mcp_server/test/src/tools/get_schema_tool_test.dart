import 'package:sp_mcp_server/src/tools/get_schema_tool.dart';
import 'package:test/test.dart';

import '../../helpers/test_data_dir.dart';

void main() {
  group('getSchemaTool definition', () {
    test('has correct name', () {
      expect(getSchemaTool.name, 'get_schema');
    });

    test('has no required parameters', () {
      final required = getSchemaTool.inputSchema['required'] as List<dynamic>?;
      expect(required, isNull);
    });
  });

  group('executeGetSchema', () {
    late String dataDir;

    setUp(() async {
      dataDir = await createTestDataDir(
        schemas: {
          'pattern-index.schema.json': {
            'type': 'object',
            'title': 'Pattern Index',
          },
          'pattern-meta.schema.json': {
            'type': 'object',
            'title': 'Pattern Meta',
          },
          'playlist-definition.schema.json': {
            'type': 'object',
            'title': 'Playlist Definition',
          },
        },
      );
    });

    tearDown(() => cleanupDataDir(dataDir));

    test('reads all three schemas from disk', () async {
      final result = await executeGetSchema(dataDir, {});

      expect(result, contains('pattern-index'));
      expect(result, contains('pattern-meta'));
      expect(result, contains('playlist-definition'));
      expect((result['pattern-index'] as Map)['title'], 'Pattern Index');
    });
  });
}
