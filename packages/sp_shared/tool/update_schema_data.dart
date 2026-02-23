import 'dart:convert';
import 'dart:io';

/// Reads assets/schema.json and writes the embedded schema string
/// to lib/src/schema/schema_data.dart.
void main() {
  final schemaFile = File('packages/sp_shared/assets/schema.json');
  final schema = jsonDecode(schemaFile.readAsStringSync());
  final minified = jsonEncode(schema);

  // Escape for embedding in a Dart single-quoted string:
  // - Replace \ with \\ (must be first)
  // - Replace ' with \'
  // - Replace $ with \$
  final escaped = minified
      .replaceAll(r'\', r'\\')
      .replaceAll("'", r"\'")
      .replaceAll(r'$', r'\$');

  final output =
      '''
// Auto-generated from assets/schema.json. Do not edit manually.
// Run 'dart run packages/sp_shared/tool/update_schema_data.dart' to refresh.

/// Embedded JSON Schema string for SmartPlaylist config validation.
const schemaJsonString =
    '$escaped';
''';

  final outFile = File('packages/sp_shared/lib/src/schema/schema_data.dart');
  outFile.writeAsStringSync(output);
  print('Updated ${outFile.path}');
}
