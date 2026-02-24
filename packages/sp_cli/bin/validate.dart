import 'dart:io';

import 'package:sp_cli/sp_cli.dart';

void main(List<String> args) {
  if (args.length != 1) {
    stderr.writeln('Usage: dart run bin/validate.dart <patterns-dir>');
    exit(2);
  }

  final patternsDir = args[0];
  if (!Directory(patternsDir).existsSync()) {
    stderr.writeln('Error: directory not found: $patternsDir');
    exit(2);
  }

  stderr.writeln('Validating patterns in $patternsDir...');

  final errors = validatePatterns(patternsDir);

  if (errors.isEmpty) {
    stderr.writeln('All configs valid.');
    exit(0);
  }

  stderr.writeln('');
  for (final error in errors) {
    stderr.writeln('  [FAIL] ${error.filePath}');
    stderr.writeln('    - ${error.message}');
  }
  stderr.writeln('');
  stderr.writeln('Validation failed: ${errors.length} error(s) found.');
  exit(1);
}
