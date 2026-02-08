/// Describes an MCP tool with its name, description, and input schema.
///
/// Used to generate the `tools/list` response and validate
/// incoming `tools/call` requests.
final class ToolDefinition {
  const ToolDefinition({
    required this.name,
    required this.description,
    required this.inputSchema,
  });

  final String name;
  final String description;
  final Map<String, dynamic> inputSchema;

  /// Converts to the MCP tool definition format.
  Map<String, dynamic> toJson() => {
    'name': name,
    'description': description,
    'inputSchema': inputSchema,
  };
}
