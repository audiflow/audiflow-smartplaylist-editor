import 'package:flutter/material.dart';
import 'package:sp_shared/sp_shared.dart';

import 'regex_tester.dart';

/// Available resolver types for playlist definitions.
const _resolverTypes = ['rss', 'category', 'year', 'titleAppearanceOrder'];

/// Form for editing a single [SmartPlaylistDefinition].
///
/// Renders as a collapsible [ExpansionTile] with fields
/// grouped by basic settings, filters, and advanced options.
class PlaylistDefinitionForm extends StatefulWidget {
  const PlaylistDefinitionForm({
    super.key,
    required this.index,
    required this.definition,
    required this.onChanged,
    required this.onDelete,
  });

  /// Index of this playlist in the parent config.
  final int index;

  /// Current definition data.
  final SmartPlaylistDefinition definition;

  /// Callback when the definition changes.
  final ValueChanged<SmartPlaylistDefinition> onChanged;

  /// Callback to delete this playlist.
  final VoidCallback onDelete;

  @override
  State<PlaylistDefinitionForm> createState() => _PlaylistDefinitionFormState();
}

class _PlaylistDefinitionFormState extends State<PlaylistDefinitionForm> {
  late final TextEditingController _idController;
  late final TextEditingController _displayNameController;
  late final TextEditingController _priorityController;
  late final TextEditingController _contentTypeController;
  late final TextEditingController _yearHeaderModeController;
  late final TextEditingController _titleFilterController;
  late final TextEditingController _excludeFilterController;
  late final TextEditingController _requireFilterController;
  late final TextEditingController _nullSeasonGroupKeyController;

  @override
  void initState() {
    super.initState();
    final d = widget.definition;
    _idController = TextEditingController(text: d.id);
    _displayNameController = TextEditingController(text: d.displayName);
    _priorityController = TextEditingController(text: d.priority.toString());
    _contentTypeController = TextEditingController(text: d.contentType ?? '');
    _yearHeaderModeController = TextEditingController(
      text: d.yearHeaderMode ?? '',
    );
    _titleFilterController = TextEditingController(text: d.titleFilter ?? '');
    _excludeFilterController = TextEditingController(
      text: d.excludeFilter ?? '',
    );
    _requireFilterController = TextEditingController(
      text: d.requireFilter ?? '',
    );
    _nullSeasonGroupKeyController = TextEditingController(
      text: d.nullSeasonGroupKey?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _idController.dispose();
    _displayNameController.dispose();
    _priorityController.dispose();
    _contentTypeController.dispose();
    _yearHeaderModeController.dispose();
    _titleFilterController.dispose();
    _excludeFilterController.dispose();
    _requireFilterController.dispose();
    _nullSeasonGroupKeyController.dispose();
    super.dispose();
  }

  SmartPlaylistDefinition _buildDefinition({
    String? resolverType,
    bool? episodeYearHeaders,
    bool? showDateRange,
  }) {
    final nullGroupKey = int.tryParse(
      _nullSeasonGroupKeyController.text.trim(),
    );

    return SmartPlaylistDefinition(
      id: _idController.text.trim(),
      displayName: _displayNameController.text.trim(),
      resolverType: resolverType ?? widget.definition.resolverType,
      priority: int.tryParse(_priorityController.text.trim()) ?? 0,
      contentType: _nullIfEmpty(_contentTypeController.text),
      yearHeaderMode: _nullIfEmpty(_yearHeaderModeController.text),
      episodeYearHeaders:
          episodeYearHeaders ?? widget.definition.episodeYearHeaders,
      showDateRange: showDateRange ?? widget.definition.showDateRange,
      titleFilter: _nullIfEmpty(_titleFilterController.text),
      excludeFilter: _nullIfEmpty(_excludeFilterController.text),
      requireFilter: _nullIfEmpty(_requireFilterController.text),
      nullSeasonGroupKey: nullGroupKey,
      groups: widget.definition.groups,
      customSort: widget.definition.customSort,
      titleExtractor: widget.definition.titleExtractor,
      episodeNumberExtractor: widget.definition.episodeNumberExtractor,
      smartPlaylistEpisodeExtractor:
          widget.definition.smartPlaylistEpisodeExtractor,
    );
  }

  void _onFieldChanged() {
    // Rebuild locally so RegexTester widgets pick up updated patterns.
    setState(() {});
    widget.onChanged(_buildDefinition());
  }

  String? _nullIfEmpty(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final d = widget.definition;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        title: Text(
          d.displayName.isEmpty
              ? 'Playlist ${widget.index + 1}'
              : d.displayName,
          style: theme.textTheme.titleMedium,
        ),
        subtitle: Text(
          '${d.resolverType} | id: ${d.id}',
          style: theme.textTheme.bodySmall,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: widget.onDelete,
              tooltip: 'Delete playlist',
            ),
            const Icon(Icons.expand_more),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildBasicFields(d),
                const SizedBox(height: 16),
                _buildFilterFields(),
                const SizedBox(height: 16),
                _buildBooleanFields(d),
                const SizedBox(height: 16),
                _buildAdvancedSection(d),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicFields(SmartPlaylistDefinition d) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Basic Settings', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _idController,
                decoration: const InputDecoration(
                  labelText: 'ID',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (_) => _onFieldChanged(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _displayNameController,
                decoration: const InputDecoration(
                  labelText: 'Display Name',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (_) => _onFieldChanged(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _resolverTypes.contains(d.resolverType)
                    ? d.resolverType
                    : _resolverTypes.first,
                decoration: const InputDecoration(
                  labelText: 'Resolver Type',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: _resolverTypes
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    widget.onChanged(_buildDefinition(resolverType: value));
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 120,
              child: TextField(
                controller: _priorityController,
                decoration: const InputDecoration(
                  labelText: 'Priority',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                keyboardType: TextInputType.number,
                onChanged: (_) => _onFieldChanged(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _contentTypeController,
                decoration: const InputDecoration(
                  labelText: 'Content Type (optional)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (_) => _onFieldChanged(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _yearHeaderModeController,
                decoration: const InputDecoration(
                  labelText: 'Year Header Mode (optional)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (_) => _onFieldChanged(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFilterFields() {
    final excludeHighlight = Colors.red.withValues(alpha: 0.3);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Filters', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        TextField(
          controller: _titleFilterController,
          decoration: const InputDecoration(
            labelText: 'Title Filter (regex)',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (_) => _onFieldChanged(),
        ),
        RegexTester(
          pattern: _titleFilterController.text,
          label: 'Title Filter Test',
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _excludeFilterController,
                    decoration: const InputDecoration(
                      labelText: 'Exclude Filter (regex)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (_) => _onFieldChanged(),
                  ),
                  RegexTester(
                    pattern: _excludeFilterController.text,
                    label: 'Exclude Filter Test',
                    highlightColor: excludeHighlight,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _requireFilterController,
                    decoration: const InputDecoration(
                      labelText: 'Require Filter (regex)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (_) => _onFieldChanged(),
                  ),
                  RegexTester(
                    pattern: _requireFilterController.text,
                    label: 'Require Filter Test',
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: 200,
          child: TextField(
            controller: _nullSeasonGroupKeyController,
            decoration: const InputDecoration(
              labelText: 'Null Season Group Key',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            keyboardType: TextInputType.number,
            onChanged: (_) => _onFieldChanged(),
          ),
        ),
      ],
    );
  }

  Widget _buildBooleanFields(SmartPlaylistDefinition d) {
    return Row(
      children: [
        Expanded(
          child: CheckboxListTile(
            title: const Text('Episode Year Headers'),
            value: d.episodeYearHeaders,
            onChanged: (value) {
              widget.onChanged(
                _buildDefinition(episodeYearHeaders: value ?? false),
              );
            },
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
        ),
        Expanded(
          child: CheckboxListTile(
            title: const Text('Show Date Range'),
            value: d.showDateRange,
            onChanged: (value) {
              widget.onChanged(_buildDefinition(showDateRange: value ?? false));
            },
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
        ),
      ],
    );
  }

  Widget _buildAdvancedSection(SmartPlaylistDefinition d) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Advanced', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        if (d.resolverType == 'category') _buildGroupsSection(d),
        if (d.titleExtractor != null) _buildTitleExtractorInfo(d),
        if (d.episodeNumberExtractor != null)
          _buildEpisodeNumberExtractorInfo(d),
        if (d.smartPlaylistEpisodeExtractor != null)
          _buildEpisodeExtractorInfo(d),
        if (d.customSort != null) _buildCustomSortInfo(d),
        Text(
          'Edit advanced fields (groups, extractors, sort) via JSON mode',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
      ],
    );
  }

  Widget _buildGroupsSection(SmartPlaylistDefinition d) {
    final groups = d.groups ?? [];
    if (groups.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 8),
        child: Text('No groups defined. Add groups via JSON mode.'),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Groups (${groups.length}):'),
          const SizedBox(height: 4),
          ...groups.map(
            (g) => Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 2),
              child: Text(
                '${g.id}: ${g.displayName}'
                '${g.pattern != null ? " (${g.pattern})" : " (catch-all)"}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleExtractorInfo(SmartPlaylistDefinition d) {
    final te = d.titleExtractor!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        'Title Extractor: source=${te.source}'
        '${te.pattern != null ? ", pattern=${te.pattern}" : ""}'
        '${te.template != null ? ", template=${te.template}" : ""}',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }

  Widget _buildEpisodeNumberExtractorInfo(SmartPlaylistDefinition d) {
    final en = d.episodeNumberExtractor!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        'Episode Number Extractor: pattern=${en.pattern}',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }

  Widget _buildEpisodeExtractorInfo(SmartPlaylistDefinition d) {
    final se = d.smartPlaylistEpisodeExtractor!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        'Episode Extractor: source=${se.source}, pattern=${se.pattern}',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }

  Widget _buildCustomSortInfo(SmartPlaylistDefinition d) {
    final sort = d.customSort!;
    final description = switch (sort) {
      SimpleSmartPlaylistSort(:final field, :final order) =>
        'Simple: ${field.name} ${order.name}',
      CompositeSmartPlaylistSort(:final rules) =>
        'Composite: ${rules.length} rules',
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        'Custom Sort: $description',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}
