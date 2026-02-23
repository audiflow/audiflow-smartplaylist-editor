import 'package:sp_mcp_server/src/tools/validate_config_tool.dart';
import 'package:sp_shared/sp_shared.dart';
import 'package:test/test.dart';

void main() {
  group('validateConfigTool definition', () {
    test('has correct name', () {
      expect(validateConfigTool.name, 'validate_config');
    });

    test('config is required', () {
      final required =
          validateConfigTool.inputSchema['required'] as List<dynamic>?;
      expect(required, contains('config'));
    });
  });

  group('executeValidateConfig', () {
    late SmartPlaylistValidator validator;

    setUp(() {
      validator = SmartPlaylistValidator();
    });

    test('throws ArgumentError when config is missing', () async {
      expect(
        () => executeValidateConfig(validator, {}),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws ArgumentError when config is not a Map', () async {
      expect(
        () => executeValidateConfig(validator, {'config': 'string'}),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('returns valid:true for a valid config', () async {
      final config = {
        'version': 1,
        'patterns': [
          {
            'id': 'test',
            'feedUrls': ['https://example.com/feed'],
            'playlists': [
              {'id': 'main', 'displayName': 'Main', 'resolverType': 'rss'},
            ],
          },
        ],
      };
      final result = await executeValidateConfig(validator, {'config': config});

      expect(result['valid'], isTrue);
      expect(result['errors'], isEmpty);
    });

    test('returns valid:false with errors for invalid config', () async {
      // Missing required fields
      final config = <String, dynamic>{};
      final result = await executeValidateConfig(validator, {'config': config});

      expect(result['valid'], isFalse);
      expect(result['errors'], isNotEmpty);
    });
  });
}
