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
        schema: {'type': 'object', 'properties': {}},
      );
    });

    tearDown(() => cleanupDataDir(dataDir));

    test('reads schema from disk', () async {
      final result = await executeGetSchema(dataDir, {});

      expect(result, {'type': 'object', 'properties': {}});
    });
  });
}
