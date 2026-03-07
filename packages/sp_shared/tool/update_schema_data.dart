import 'dart:convert';
import 'dart:io';

/// Reads the three split schema files and writes embedded schema strings
/// to lib/src/schema/schema_data.dart.
void main() {
  final schemas = {
    'patternIndexSchemaString': 'pattern-index.schema.json',
    'patternMetaSchemaString': 'pattern-meta.schema.json',
    'playlistDefinitionSchemaString': 'playlist-definition.schema.json',
  };

  final buffer = StringBuffer(
    '// Auto-generated from assets/*.schema.json. Do not edit manually.\n'
    "// Run 'dart run packages/sp_shared/tool/update_schema_data.dart'"
    ' to refresh.\n\n',
  );

  for (final entry in schemas.entries) {
    final file = File('packages/sp_shared/assets/${entry.value}');
    final schema = jsonDecode(file.readAsStringSync());
    final minified = jsonEncode(schema);
    final escaped = minified
        .replaceAll(r'\', r'\\')
        .replaceAll("'", r"\'")
        .replaceAll(r'$', r'\$');

    buffer.writeln('/// Embedded JSON Schema for ${entry.value}.');
    buffer.writeln("const ${entry.key} =");
    buffer.writeln("    '$escaped';");
    buffer.writeln();
  }

  final outFile = File('packages/sp_shared/lib/src/schema/schema_data.dart');
  outFile.writeAsStringSync(buffer.toString());
  print('Updated ${outFile.path}');
}
