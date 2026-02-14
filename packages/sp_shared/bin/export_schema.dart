import 'dart:io';

import 'package:sp_shared/sp_shared.dart';

/// Exports the SmartPlaylist JSON Schema (draft-07) to a file.
///
/// Usage:
///   dart run bin/export_schema.dart <output_path>
///
/// If no output path is given, writes to stdout.
void main(List<String> args) {
  final schema = SmartPlaylistSchema.generate();

  if (args.isEmpty) {
    stdout.write(schema);
    return;
  }

  final outputFile = File(args[0]);
  outputFile.parent.createSync(recursive: true);
  outputFile.writeAsStringSync(schema);
  stderr.writeln('Wrote JSON Schema to ${outputFile.path}');
}
