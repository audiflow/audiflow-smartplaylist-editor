import 'dart:io';

import 'package:sp_mcp_server/src/mcp_server.dart';

/// Entry point for the SmartPlaylist MCP server.
///
/// Auto-detects the data directory by checking for patterns/meta.json
/// in the current working directory.
Future<void> main() async {
  final dataDir = _detectDataDir();
  final server = SpMcpServer(dataDir: dataDir);
  await server.run();
}

String _detectDataDir() {
  final cwd = Directory.current.path;
  final metaFile = File('$cwd/patterns/meta.json');
  if (metaFile.existsSync()) return cwd;

  stderr.writeln('Error: patterns/meta.json not found in current directory.');
  stderr.writeln('Run this command from a SmartPlaylist data repository.');
  exit(1);
}
